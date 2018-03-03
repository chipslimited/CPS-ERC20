pragma solidity ^0.4.18;


library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


interface ERC20 {

    function name() public view returns (string);
    function symbol() public view returns (string);
    function decimals() public view returns (uint8);

    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}

interface ERC223 {
    function transfer(address to, uint value, bytes data) payable public;
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}


contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes _data) public;
}


contract ERCAddressFrozenFund is ERC20{

    struct LockedWallet {
        address owner; // the owner of the locked wallet, he/she must secure the private key
        uint256 amount; // 
        uint256 start; // timestamp when "lock" function is executed
        uint256 duration; // duration period in seconds. if we want to lock an amount for 
        uint256 release;  // release = start+duration
        // "start" and "duration" is for bookkeeping purpose only. Only "release" will be actually checked once unlock function is called
    }

    mapping (address => LockedWallet) internal lockedFunds;

    address public owner;
    address public fundsAdmin;// Who can lock and unlock fund?

    uint8 constant FROZEN_INDEX_MAX = 10;
    uint8 constant FROZEN_INDEX_MIN = 1;

    mapping (address => mapping (uint256 => LockedWallet)) internal addressMultiFrozen;//address -> index -> (deadline, amount), if deadline is zero, nothing is frozen
    mapping (address => LockedWallet) addressFrozenFund; //address -> (deadline, amount),freeze fund of an address its so that no token can be transferred out until deadline

    function modifyFundsAdmin(address newAdmin) public;
    function mintToken(address _owner, uint256 amount) internal;
    function burnToken(address _owner, uint256 amount) internal;

    event LockBalance(address indexed addressOwner, uint256 releasetime, uint256 amount);
    event LockSubBalance(address indexed addressOwner, uint256 index, uint256 releasetime, uint256 amount);
    event UnlockBalance(address indexed addressOwner, uint256 releasetime, uint256 amount);
    event UnlockSubBalance(address indexed addressOwner, uint256 index, uint256 releasetime, uint256 amount);

    function releaseTimeOf(address _owner) public view returns (uint256 releaseTime) {
        return addressFrozenFund[_owner].releasetime;
    }

    function lockedBalanceOf(address _owner) public view returns (uint256 lockedBalance) {
        return addressFrozenFund[_owner].balance;
    }

    function  lockBalance(address _owner, uint256 numOfSeconds, uint256 amount) public{
        require(address(0) != _owner && amount > 0 && numOfSeconds > 0 && balanceOf(_owner) > amount);

        addressFrozenFund[_owner].releasetime = now + numOfSeconds;
        addressFrozenFund[_owner].balance += amount;
        burnToken(_owner, amount);

        LockBalance(_owner, addressFrozenFund[_owner].releasetime, amount);
    }

    //_owner must call this function explicitly to release locked balance in a locked wallet
    function releaseLockedBalance(address _owner) public {
        require(address(0) != _owner && lockedBalanceOf(_owner) > 0 && releaseTimeOf(_owner) <= now);
        mintToken(_owner, lockedBalanceOf(_owner));

        UnlockBalance(_owner, addressFrozenFund[_owner].releasetime, lockedBalanceOf(_owner));

        delete addressFrozenFund[_owner];
    }

    function releaseTimeOfSub(address _owner, uint8 index) public view returns (uint256 releaseTimeSub) {
        require(index >= FROZEN_INDEX_MIN && index <= FROZEN_INDEX_MAX);
        return addressMultiFrozen[_owner][index].releasetime;
    }

    function lockedBalanceOfSub(address _owner, uint8 index) public view returns (uint256 lockedBalanceSub) {
        require(index >= FROZEN_INDEX_MIN && index <= FROZEN_INDEX_MAX);
        return addressMultiFrozen[_owner][index].balance;
    }

    function lockedBalanceSub(address _owner, uint8 index, uint256 numOfSeconds, uint256 amount) public{
        require(index >= FROZEN_INDEX_MIN && index <= FROZEN_INDEX_MAX);
        require(address(0) != _owner && amount > 0 && numOfSeconds > 0 && balanceOf(_owner) > amount);

        addressMultiFrozen[_owner][index].releasetime = now + numOfSeconds;
        addressMultiFrozen[_owner][index].balance += amount;
        burnToken(_owner, amount);

        LockSubBalance(_owner, index, addressMultiFrozen[_owner][index].releasetime, amount);
    }

    //_owner must call this function explicitly to release locked balance in a sub wallet
    function releaseLockedBalanceSub(address _owner, uint8 index) public {
        require(index >= FROZEN_INDEX_MIN && index <= FROZEN_INDEX_MAX);
        require(address(0) != _owner && lockedBalanceOfSub(_owner, index) > 0 && releaseTimeOfSub(_owner, index) <= now);
        mintToken(_owner, lockedBalanceOfSub(_owner, index));

        UnlockSubBalance(_owner, index, addressMultiFrozen[_owner][index].releasetime, lockedBalanceOfSub(_owner, index));

        delete addressMultiFrozen[_owner][index];
    }
}

contract CPSTestToken1 is ERC20, ERC223,ERCAddressFrozenFund {

    using SafeMath for uint;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    uint256 public unitsOneEthCanBuy;     // How many units of your coin can be bought by 1 ETH?
    uint256 public totalEthInWei;         // WEI is the smallest unit of ETH (the equivalent of cent in USD or satoshi in BTC). We'll store the total ETH raised via our ICO here.
    address public fundsWallet;           // Where should the raised ETH go?

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;


    function modifyFundsAdmin(address newAdmin) public{
        require (msg.sender == fundsWallet || msg.sender == fundsAdmin);//only owner and admin can change who admin is

        fundsAdmin = newAdmin;
    }

    function CPSTestToken1(string name, string symbol, uint8 decimals, uint256 totalSupply) public {
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
        _totalSupply = totalSupply;
        balances[msg.sender] = totalSupply;
        fundsWallet = msg.sender;
        fundsAdmin = msg.sender;
        unitsOneEthCanBuy = 100;

        owner = msg.sender;
    }

    function name()
    public
    view
    returns (string) {
        return _name;
    }

    function symbol()
    public
    view
    returns (string) {
        return _symbol;
    }

    function decimals()
    public
    view
    returns (uint8) {
        return _decimals;
    }

    function totalSupply()
    public
    view
    returns (uint256) {
        return _totalSupply;
    }

    function mintToken(address _owner, uint256 amount) internal {
        balances[_owner] = SafeMath.add(balances[_owner], amount);
    }

    function burnToken(address _owner, uint256 amount) internal {
        balances[_owner] = SafeMath.sub(balances[_owner], amount);
    }

    function() payable public {

        require(msg.sender == address(0));//disable ICO crowd sale 禁止ICO资金募集，因为本合约已经过了募集阶段

        totalEthInWei = totalEthInWei + msg.value;
        uint256 amount = msg.value/10^decimals() * unitsOneEthCanBuy;
        require (balances[fundsWallet] >= amount);

        balances[fundsWallet] = SafeMath.sub(balances[fundsWallet], amount);
        balances[msg.sender] = SafeMath.add(balances[msg.sender], amount);

        Transfer(fundsWallet, msg.sender, amount); // Broadcast a message to the blockchain

        //Transfer ether to fundsWallet
        fundsWallet.transfer(msg.value);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        if(isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            bytes memory _data = new bytes(1);
            receiver.tokenFallback(msg.sender, _value, _data);
        }

        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        Transfer(msg.sender, _to, _value);

        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        if(_from == fundsWallet){
            require(_value <= balances[_from]);
        }

        if(isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            bytes memory _data = new bytes(1);
            receiver.tokenFallback(msg.sender, _value, _data);
        }

        balances[_from] = SafeMath.sub(balances[_from], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        allowed[_from][msg.sender] = SafeMath.sub(allowed[_from][msg.sender], _value);
        allowed[_from][msg.sender] = SafeMath.sub(allowed[_from][msg.sender], _value);

        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = SafeMath.add(allowed[msg.sender][_spender], _addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = SafeMath.sub(oldValue, _subtractedValue);
        }
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function transfer(address _to, uint _value, bytes _data) public payable {
        require(_value > 0 );
        if(isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        Transfer(msg.sender, _to, _value, _data);
    }

    function isContract(address _addr) private view returns (bool is_contract) {
        uint length;
        assembly {
        //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        return (length>0);
    }

    function transferMultiple(address[] _tos, uint256[] _values, uint count)  payable public returns (bool) {
      uint256 total = 0;
      uint i = 0;

      for(i=0;i<count;i++){
        require(_tos[i] != address(0) && !isContract(_tos[i]));//_tos must no contain any contract address

        if(isContract(_tos[i])) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_tos[i]);
            bytes memory _data = new bytes(1);
            receiver.tokenFallback(msg.sender, _values[i], _data);
        }
        total = SafeMath.add(total, _values[i]);
      }

      require(total <= balances[msg.sender]);

      for(i=0;i<count;i++){
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _values[i]);
        balances[_tos[i]] = SafeMath.add(balances[_tos[i]], _values[i]);
        Transfer(msg.sender, _tos[i], _values[i]);
      }

      return true;
    }
}

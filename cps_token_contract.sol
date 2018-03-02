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
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) payable public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

}

//Lock amount of fund and unlock automatically after deadline
interface ERCFundLock{
    function lockFund (uint cycle, uint numOfSeconds, uint256 amount) public;
    function unlockFund (uint cycle) public;

    event LockFund(address indexed from, uint deadline, uint256 amount);
    event UnlockFund(address indexed from, uint deadline, uint256 amount);
}

//lock amount of fund
//each time unlockFundEx is called
//unlock unlockAmount = (now - time locked)/(deadline - time locked)*amount
//
interface ERCFundLockUnlockEx {
    function lockFundEx (uint cycle, uint numOfSeconds, uint256 amount) public;
    function unlockFundEx (uint cycle) public;

    event LockFundEx(address indexed from, uint deadline, uint256 amount);
    event UnlockFundEx(address indexed from, uint cycle, uint unlockTimestamp, uint deadline, uint256 unlockAmount);
}

interface ERC223 {
    function transfer(address to, uint value, bytes data) payable public;
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}


contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes _data) public;
}

contract CPSTestToken1 is ERC20, ERC223, ERCFundLock, ERCFundLockUnlockEx {

    using SafeMath for uint;

    uint8 constant TOTAL_CYCLES = 5;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    uint256 public unitsOneEthCanBuy;     // How many units of your coin can be bought by 1 ETH?
    uint256 public totalEthInWei;         // WEI is the smallest unit of ETH (the equivalent of cent in USD or satoshi in BTC). We'll store the total ETH raised via our ICO here.
    address public fundsWallet;           // Where should the raised ETH go?
    address public fundsAdmin;            // Who can lock and unlock fund?

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;
    mapping (uint => mapping (string => uint256)) internal fundLocks;



    function lockFund (uint cycle, uint numOfSeconds, uint256 amount) public  {

        require(cycle > 0 && cycle <= TOTAL_CYCLES && amount > 0 && numOfSeconds > 0 && (fundLocks[cycle]["deadline"] == 0||fundLocks[cycle]["deadline"] < now));
        require(balances[fundsWallet] - totalLockAmount() > amount);
        require (msg.sender == fundsWallet || msg.sender == fundsAdmin);

        fundLocks[cycle]["deadline"] = now + numOfSeconds;
        fundLocks[cycle]["amount"] = amount;

        LockFund(msg.sender, fundLocks[cycle]["deadline"], amount);
    }

    function lockedDeadline(uint cycle) public view returns (uint256) {
        return fundLocks[cycle]["deadline"];
    }

    function lockedAmount(uint cycle) public view returns (uint256) {
        return fundLocks[cycle]["amount"];
    }

    function lockedExDeadline(uint cycle) public view returns (uint256) {
        return fundLocks[cycle+5]["deadline"];
    }

    function lockedExAmount(uint cycle) public view returns (uint256) {
        return fundLocks[cycle+5]["amount"]-fundLocks[cycle+5]["unlockedAmount"];
    }

    function unlockFund (uint cycle) public{
        require (cycle > 0 && cycle <= TOTAL_CYCLES &&
        (fundLocks[cycle]["deadline"] < now) &&
        fundLocks[cycle]["amount"] > 0
        );
        require (msg.sender == fundsWallet || msg.sender == fundsAdmin);

        fundLocks[cycle]["deadline"] = 0;

        var amount = fundLocks[cycle]["amount"];
        fundLocks[cycle]["amount"] = 0;

        LockFund(msg.sender, fundLocks[cycle]["deadline"], amount);
    }

    function totalLockAmount() public view returns (uint256) {
        uint256 amount = 0;
        uint i = 0;

        for(i=1;i<=TOTAL_CYCLES;i++){
            if(fundLocks[i]["deadline"] > now){
                amount += fundLocks[i]["amount"];
            }
        }
        for(i=1;i<=TOTAL_CYCLES;i++){
            amount += fundLocks[i+5]["amount"]-fundLocks[i+5]["unlockAmount"];
        }
        return amount;
    }

    function lockFundEx (uint cycle, uint numOfSeconds, uint256 amount) public{
        require (cycle > 0 && cycle <= TOTAL_CYCLES && amount > 0 && numOfSeconds > 0);
        require (balances[fundsWallet] - totalLockAmount() > amount);
        require (msg.sender == fundsWallet || msg.sender == fundsAdmin);

        if(fundLocks[cycle]["deadline"] <= now && fundLocks[cycle]["deadline"] > 0){
            if(fundLocks[cycle+5]["amount"] > fundLocks[cycle+5]["unlockAmount"]){
                unlockFundEx(cycle);
            }
        }

        fundLocks[cycle+5]["lockTime"] = now;
        fundLocks[cycle+5]["deadline"] = now + numOfSeconds;
        fundLocks[cycle+5]["amount"] = amount;
        fundLocks[cycle+5]["unlockAmount"] = 0;

        LockFundEx(msg.sender, fundLocks[cycle+5]["deadline"], amount);
    }


    function unlockFundEx (uint cycle) public{

        require (
            cycle > 0 && cycle <= TOTAL_CYCLES &&
            fundLocks[cycle+5]["amount"] > fundLocks[cycle+5]["unlockAmount"]
        );
        require (msg.sender == fundsWallet || msg.sender == fundsAdmin);

        uint256 now_ts = now;
        uint256 lockedTime = fundLocks[cycle+5]["lockTime"];
        uint256 unlockAmount = 0;
        uint256 amount = fundLocks[cycle+5]["amount"];
        uint256 deadline = fundLocks[cycle+5]["deadline"];
        //TODO: calculate unlockAmount and update fundLocks[cycle+5]["unlockAmount"]
        //unlockAmount = (now - time locked)/(deadline - time locked)*amount
        if(deadline <= now_ts){
            //unlock rest
            unlockAmount = amount - fundLocks[cycle+5]["unlockAmount"];
            fundLocks[cycle+5]["unlockAmount"] += unlockAmount;
        }
        else{
            unlockAmount = (now_ts - lockedTime)*amount/(deadline - lockedTime) - fundLocks[cycle+5]["unlockAmount"];
            fundLocks[cycle+5]["unlockAmount"] += unlockAmount;
        }

        UnlockFundEx(msg.sender, cycle, now_ts, fundLocks[cycle+5]["deadline"], unlockAmount);
    }

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


    function() payable public {

        require(msg.sender == address(0));//disable ICO crowd sale 禁止ICO资金募集，因为本合约已经过了募集阶段

        totalEthInWei = totalEthInWei + msg.value;
        uint256 amount = msg.value/10^decimals() * unitsOneEthCanBuy;
        require (balances[fundsWallet] - totalLockAmount() >= amount);

        balances[fundsWallet] = balances[fundsWallet] - amount;
        balances[msg.sender] = balances[msg.sender] + amount;

        Transfer(fundsWallet, msg.sender, amount); // Broadcast a message to the blockchain

        //Transfer ether to fundsWallet
        fundsWallet.transfer(msg.value);
    }

    function transfer(address _to, uint256 _value) payable public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        if(msg.sender == fundsWallet){
            require(_value <= balances[msg.sender] - totalLockAmount() && balances[msg.sender] > totalLockAmount());
        }

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
            require(_value <= balances[_from] - totalLockAmount() && balances[_from] > totalLockAmount());
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

    //transfer multiple
    function transfer2(address _to, uint256 _value, address _to1, uint256 _value1) payable public returns (bool) {
        require(_to != address(0));

        if(isContract(_to) || isContract(_to1)) {
            require(_to == address(0) || _to1 == address(0));//transfer must fail if to is contract
        }

        require(_value + _value1 <= balances[msg.sender]);
        if(msg.sender == fundsWallet){
            require(_value + _value1 <= balances[msg.sender] - totalLockAmount() && balances[msg.sender] > totalLockAmount());
        }

        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        Transfer(msg.sender, _to, _value);

        if(_value1 > 0 && _to1 != address(0)){
          balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value1);
          balances[_to1] = SafeMath.add(balances[_to1], _value1);
        }
        Transfer(msg.sender, _to1, _value1);

        return true;
    }

    function transfer3(address _to, uint256 _value, address _to1, uint256 _value1, address _to2, uint256 _value2) payable public returns (bool) {
        require(_to != address(0));
        if(isContract(_to) || isContract(_to1) || isContract(_to2)) {
            require(_to == address(0) || _to1 == address(0) || _to2 == address(0));//transfer must fail if to is contract
        }
        require(_value + _value1 + _value2 <= balances[msg.sender]);
        if(msg.sender == fundsWallet){
            require(_value + _value1 + _value2 <= balances[msg.sender] - totalLockAmount() && balances[msg.sender] > totalLockAmount());
        }

        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        Transfer(msg.sender, _to, _value);

        if(_value1 > 0 && _to1 != address(0)){
          balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value1);
          balances[_to1] = SafeMath.add(balances[_to1], _value1);
        }
        Transfer(msg.sender, _to1, _value1);

        if(_value2 > 0 && _to2 != address(0)){
          balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value2);
          balances[_to2] = SafeMath.add(balances[_to2], _value2);
        }
        Transfer(msg.sender, _to2, _value2);

        return true;
    }

    function transfer4(address _to, uint256 _value, address _to1, uint256 _value1, address _to2, uint256 _value2, address _to3, uint256 _value3) payable public returns (bool) {
        require(_to != address(0));
        if(isContract(_to) || isContract(_to1) || isContract(_to2) || isContract(_to3)) {
            require(_to == address(0) || _to1 == address(0) || _to2 == address(0) || _to3 == address(0));//transfer must fail if to is contract
        }
        require(_value + _value1 + _value2 + _value3 <= balances[msg.sender]);
        if(msg.sender == fundsWallet){
            require(_value + _value1 + _value2 + _value3 <= balances[msg.sender] - totalLockAmount() && balances[msg.sender] > totalLockAmount());
        }

        if(isContract(_to) || isContract(_to1) || isContract(_to2) || isContract(_to3)) {
            require(1 == 2);//must fail
        }

        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        Transfer(msg.sender, _to, _value);

        if(_value1 > 0 && _to1 != address(0)){
          balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value1);
          balances[_to1] = SafeMath.add(balances[_to1], _value1);
        }
        Transfer(msg.sender, _to1, _value1);

        if(_value2 > 0 && _to2 != address(0)){
          balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value2);
          balances[_to2] = SafeMath.add(balances[_to2], _value2);
        }
        Transfer(msg.sender, _to2, _value2);

        if(_value3 > 0 && _to3 != address(0)){
          balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value3);
          balances[_to3] = SafeMath.add(balances[_to3], _value3);
        }
        Transfer(msg.sender, _to3, _value3);

        return true;
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
        total += _values[i];
      }

      require(total <= balances[msg.sender]);
      if(msg.sender == fundsWallet){
          require(total <= balances[msg.sender] - totalLockAmount() && balances[msg.sender] > totalLockAmount());
      }

      for(i=0;i<count;i++){
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _values[i]);
        balances[_tos[i]] = SafeMath.add(balances[_tos[i]], _values[i]);
        Transfer(msg.sender, _tos[i], _values[i]);
      }

      return true;
    }
}

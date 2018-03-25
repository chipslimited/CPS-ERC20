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


contract CPST is ERC223, ERC20 {

    using SafeMath for uint;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    address public owner;//only owner can change CEO
    address public CEO;//only CEO can issue or repurchurse CPST
    uint256 internal _owner_changed;//owner can only be changed once

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    event CreateCPST(address indexed issuer, address indexed owner, uint tokens);
    event DestroyCPST(address indexed issuer, address indexed owner, uint tokens);


    function CPST() public {
        _symbol = 'CPST';
        _name = 'CPSTether';
        _decimals = 2;
        _totalSupply = 0;
        owner = msg.sender;
        CEO = address(0);
        _owner_changed = 0;
    }

    function changeOwner(address newOwner) public{
        require(msg.sender == owner && _owner_changed == 0);

        balances[newOwner] = balances[owner];
        balances[owner] = 0;
        owner = newOwner;
        CEO = newOwner;//if a new owner is set, the original CEO should be fired too.
        _owner_changed = 1;
    }

    function changeCEO(address newCEO) public {
        require(msg.sender == owner);

        CEO = newCEO;
    }

    function name() public view returns (string) {
        return _name;
    }

    function symbol() public view returns (string) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function createCPST(address _owner, uint256 amount) public {

        require(msg.sender == CEO || msg.sender == owner);

        _totalSupply = SafeMath.add(_totalSupply, amount);
        balances[_owner] = SafeMath.add(balances[_owner], amount);
        CreateCPST(msg.sender, _owner, amount);
    }

    function destroyCPST(address _owner, uint256 amount) public {

        require( (msg.sender == CEO || msg.sender == owner) && balances[_owner] >= amount);

        _totalSupply = SafeMath.sub(_totalSupply, amount);
        balances[_owner] = SafeMath.sub(balances[_owner], amount);
        DestroyCPST(msg.sender, _owner, amount);
    }

    function() payable public {

        require(msg.sender == address(0));//disable ICO crowd sale
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

}

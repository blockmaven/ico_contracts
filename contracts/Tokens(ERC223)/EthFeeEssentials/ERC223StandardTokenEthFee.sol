pragma solidity 0.4.25;

import "./ERC20InterfaceEthFee.sol";
import "./ERC223InterfaceEthFee.sol";
import "../../Essentials/SafeMath.sol";
import "../ERC223ReceivingContract.sol";


contract StandardToken is ERC20, ERC223EthFee {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 internal _totalSupply;

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    constructor(string _name, string _symbol, uint8 _decimals) public {
        symbol = _symbol;
        name = _name;
        decimals = _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function transfer(address _to, uint256 _value) public payable returns (bool) {
        bytes memory empty;
        require(_transfer(msg.sender, _to, _value, empty));

        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transferFrom(
        address _from, 
        address _to, 
        uint256 _value
    ) 
        public
        payable
        returns (bool) 
    {
        bytes memory empty;

        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        require(_transfer(_from, _to, _value, empty));

        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        
        emit Approval(msg.sender, _spender, _value);
        
        return true;
    }

    function allowance(
        address _owner, 
        address _spender
    ) 
        public 
        view 
        returns (uint256) 
    {
        return allowed[_owner][_spender];
    }

    function increaseApproval(
        address _spender, 
        uint256 _addedValue
    ) 
        public 
        returns (bool) 
    {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        
        return true;
    }

    function decreaseApproval(
        address _spender, 
        uint256 _subtractedValue
    ) 
        public 
        returns (bool) 
    {
        uint256 oldValue = allowed[msg.sender][_spender];
        
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = SafeMath.sub(oldValue, _subtractedValue);
        }
        
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        
        return true;
    }
    
    function transfer(
        address _to, 
        uint256 _value, 
        bytes _data
    ) 
        public
        payable
        returns (bool) 
    {
        require(_transfer(msg.sender, _to, _value, _data));

        return true;
    }

    function _transfer(
        address _from, 
        address _to, 
        uint256 _value, 
        bytes _data
    )
        internal 
        returns (bool) 
    {
        require(_value > 0 );
        require(_to != address(0));
        
        if(isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(_from, _value, _data);
        }
        
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        
        emit Transfer(_from, _to, _value, _data);

        return true;
    }
        
    function isContract(address _addr) internal view returns (bool is_contract) {
        uint length;
        
        assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        
        return (length>0);
    }

}

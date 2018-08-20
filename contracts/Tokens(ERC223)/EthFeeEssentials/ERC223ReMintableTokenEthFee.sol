pragma solidity 0.4.25;

import "./ERC223StandardTokenEthFee.sol";
import "../../Essentials/Ownable.sol";
import "../../Essentials/Validator.sol";


/**
 * @title Mintable token
 * @dev Simple ERC20 Token example, with mintable token creation
 * @dev Issue: * https://github.com/OpenZeppelin/zeppelin-solidity/issues/120
 * Based on code by TokenMarketNet: https://github.com/TokenMarketNet/ico/blob/master/contracts/MintableToken.sol
 */
contract ERC223ReMintableTokenEthFee is Validator, StandardToken, Ownable {
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event MintStarted();

    bool public mintingFinished = false;


    modifier canMint() {
        require(!mintingFinished);
        _;
    }
    
    modifier cannotMint() {
        require(mintingFinished);
        _;
    }
    
    modifier isAuthorized() {
        require(msg.sender == owner || msg.sender == validator);
        _;
    }

    constructor(address _owner, string _name, string _symbol, uint8 _decimals) 
        public 
        Ownable(_owner) 
        StandardToken(_name, _symbol, _decimals)
    {
    }

    /**
    * @dev Function to mint tokens
    * @param _to The address that will receive the minted tokens.
    * @param _amount The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        _totalSupply = _totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
    * @dev Function to stop minting new tokens.
    * @return True if the operation was successful.
    */
    function finishMinting() isAuthorized canMint public returns (bool) {
        mintingFinished = true;
        emit MintFinished();
        return true;
    }
    
    /**
    * @dev Function to start minting new tokens.
    * @return True if the operation was successful.
    */
    function startMinting() onlyValidator cannotMint public returns (bool) {
        mintingFinished = false;
        emit MintStarted();
        return true;
    }
}

pragma solidity 0.4.25;

import "./StandardTokenEthFee.sol";
import "../../Essentials/Ownable.sol";
import "../../Essentials/Validator.sol";


/**
 * @title Mintable token
 * @dev Simple ERC20 Token example, with mintable token creation
 * @dev Issue: * https://github.com/OpenZeppelin/zeppelin-solidity/issues/120
 * Based on code by TokenMarketNet: https://github.com/TokenMarketNet/ico/blob/master/contracts/MintableToken.sol
 */
contract ReMintableTokenEthFee is Validator, StandardTokenEthFee, Ownable {
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

    constructor(address _owner) 
        public 
        Ownable(_owner) 
    {
    }

    /**
    * @dev Function to mint tokens
    * @param _to The address that will receive the minted tokens.
    * @param _amount The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        totalSupply_ = totalSupply_.add(_amount);
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

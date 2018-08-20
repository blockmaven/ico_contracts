pragma solidity 0.4.25;

import "../StandardToken.sol";
import "../../Essentials/Ownable.sol";


/**
 * @title ReMintable token
 */
contract ReMintableToken is StandardToken, Ownable {
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
    function finishMinting() onlyOwner canMint public returns (bool) {
        mintingFinished = true;
        emit MintFinished();
        return true;
    }
    
    /**
    * @dev Function to start minting new tokens.
    * @return True if the operation was successful.
    */
    function startMinting() onlyOwner cannotMint public returns (bool) {
        mintingFinished = false;
        emit MintStarted();
        return true;
    }
}

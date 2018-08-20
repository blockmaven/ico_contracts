pragma solidity 0.4.25;

import "./ReMintableToken.sol";
import "../DetailedERC20.sol";


/** @title Token */
contract ReToken is DetailedERC20, ReMintableToken {

    /** @dev Constructor
      * @param _owner Token contract owner
      * @param _name Token name
      * @param _symbol Token symbol
      * @param _decimals number of decimals in the token(usually 18)
      */
    constructor(
        address _owner,
        string _name, 
        string _symbol, 
        uint8 _decimals
    )
        public
        ReMintableToken(_owner)
        DetailedERC20(_name, _symbol, _decimals)
    {

    }

    /** @dev Updates token name
      * @param _name New token name
      */
    function updateName(string _name) public onlyOwner {
        require(bytes(_name).length != 0);
        name = _name;
    }

    /** @dev Updates token symbol
      * @param _symbol New token name
      */
    function updateSymbol(string _symbol) public onlyOwner {
        require(bytes(_symbol).length != 0);
        symbol = _symbol;
    }
}

pragma solidity 0.4.25;

import "../Essentials/SafeMath.sol";


contract TokenInterface {
    function mint(address _to, uint256 _amount) public returns (bool);
    function finishMinting() public returns (bool);
    function transferOwnership(address newOwner) public;
}


/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive. The contract requires a MintableToken that will be
 * minted as contributions arrive, note that the crowdsale contract
 * must be owner of the token in order to be able to mint it.
 */
contract Crowdsale {
    using SafeMath for uint256;

    enum Cap { UnCapped, HardCapped, TokenCapped }

    // The token being sold
    address public token;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;
    
    // Kind of cap of the crowdsale
    Cap public capped;

    // address where funds are collected
    address public wallet;

    // how many token units a buyer gets per ether
    uint256 public rate;

    // amount of raised money in wei
    uint256 public weiRaised;

    // maximum amount of wei that can be raised
    uint256 public hardCap;

    // amount of tokens sold
    uint256 public totalSupply;

    // maximum amount of tokens that can be sold
    uint256 public tokenCap;

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    constructor(uint256 _startTime, uint256 _endTime, uint256 _hardCap, uint256 _tokenCap, uint256 _rate, address _wallet, address _token) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_rate > 0);
        require(_wallet != address(0));
        require(_token != address(0));
        require( _hardCap == 0 || _tokenCap == 0 );

        if ( _hardCap > 0 ) {
            capped = Cap.HardCapped;
        } else if ( _tokenCap > 0 ) {
            capped = Cap.TokenCapped;
        }

        startTime = _startTime;
        endTime = _endTime;
        hardCap = _hardCap;
        tokenCap = _tokenCap;
        rate = _rate;
        wallet = _wallet;
        token = _token;
    }

    // fallback function can be used to buy tokens
    function () external payable {
        buyTokens(msg.sender);
    }

    // low level token purchase function
    function buyTokens(address beneficiary) public payable {
        require(beneficiary != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // calculate token amount to be created
        uint256 tokens = getTokenAmount(weiAmount);

        // update state
        weiRaised = weiRaised.add(weiAmount);
        totalSupply = totalSupply.add(tokens);

        TokenInterface(token).mint(beneficiary, tokens);
        emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    // @return true if crowdsale event has ended
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    // Override this method to have a way to add business logic to your crowdsale when buying
    function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {
        return weiAmount.mul(rate);
    }

    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    // @return true if the transaction can buy tokens
    function validPurchase() internal view returns (bool) {
        if (capped == Cap.HardCapped) {

            require(weiRaised.add(msg.value) <= hardCap);

        } else if (capped == Cap.TokenCapped) {

            uint256 tokens = msg.value.mul(rate);
            require(totalSupply.add(tokens) <= tokenCap);
        
        }
        
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        return withinPeriod && nonZeroPurchase;
    }

}

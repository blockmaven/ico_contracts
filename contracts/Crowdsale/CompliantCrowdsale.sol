pragma solidity 0.4.25;

import "./FinalizableCrowdsale.sol";
import "../Essentials/Validator.sol";
import "../Whitelist/Whitelist.sol";


/** @title Compliant Crowdsale */
contract CompliantCrowdsale is Validator, FinalizableCrowdsale {
    Whitelist public whiteListingContract;

    struct MintStruct {
        address to;
        uint256 tokens;
        uint256 weiAmount;
    }

    mapping (uint => MintStruct) public pendingMints;
    uint256 public currentMintNonce;
    uint256 public invalidPurchaseReason;    
    address public minter;
    mapping (address => uint) public rejectedMintBalance;

    modifier checkIsInvestorApproved(address _account) {
        require(whiteListingContract.isInvestorApproved(_account));
        _;
    }

    modifier checkIsAddressValid(address _account) {
        require(_account != address(0));
        _;
    }

    modifier isMinter() {
        require(msg.sender == minter);
        _;
    }

    /**
    * event for rejected mint logging
    * @param to address for which buy tokens got rejected
    * @param value number of tokens
    * @param amount number of ethers invested
    * @param nonce request recorded at this particular nonce
    * @param reason reason for rejection
    */
    event MintRejected(
        address indexed to,
        uint256 value,
        uint256 amount,
        uint256 indexed nonce,
        uint256 reason
    );

    /**
    * event for buy tokens request logging
    * @param beneficiary address for which buy tokens is requested
    * @param tokens number of tokens
    * @param weiAmount number of ethers invested
    * @param nonce request recorded at this particular nonce
    */
    event ContributionRegistered(
        address beneficiary,
        uint256 tokens,
        uint256 weiAmount,
        uint256 nonce
    );

    /**
    * event for rate update logging
    * @param rate new rate
    */
    event RateUpdated(uint256 rate);

    /**
    * event for reason for an invalid purchase
    * @param reason new reason for an invalid purchase
    */
    event InvalidPurchaseReasonUpdated(uint256 reason);

    /**
    * event for whitelist contract update logging
    * @param _whiteListingContract address of the new whitelist contract
    */
    event WhiteListingContractSet(address indexed _whiteListingContract);

    /**
    * event for minter address update logging
    * @param minterAddress address of the new minter
    */
    event MinterUpdated(address indexed minterAddress);

    /**
    * event for claimed ether logging
    * @param account user claiming the ether
    * @param amount ether claimed
    */
    event Claimed(address indexed account, uint256 amount);

    /** @dev Constructor
      * @param whitelistAddress Ethereum address of the whitelist contract
      * @param _startTime crowdsale start time
      * @param _endTime crowdsale end time
      * @param _hardCap maximum ether(in weis) this crowdsale can raise
      * @param _tokenCap maximum number of tokens to be sold in the crowdsale
      * @param _rate number of tokens to be sold per ether
      * @param _wallet Ethereum address of the wallet
      * @param _token Ethereum address of the token contract
      * @param _owner Ethereum address of the owner
      */
    constructor(
        address whitelistAddress,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _hardCap,
        uint256 _tokenCap,
        uint256 _rate,
        address _wallet,
        address _token,
        address _owner
    )
        public
        FinalizableCrowdsale(_owner)
        Crowdsale(_startTime, _endTime, _hardCap, _tokenCap, _rate, _wallet, _token)
    {
        setWhitelistContract(whitelistAddress);
    }

    /** @dev Updates whitelist contract address
      * @param whitelistAddress address of the new whitelist contract 
      */
    function setWhitelistContract(address whitelistAddress)
        public 
        onlyValidator 
        checkIsAddressValid(whitelistAddress)
    {
        whiteListingContract = Whitelist(whitelistAddress);
        emit WhiteListingContractSet(whiteListingContract);
    }

    /** @dev Updates minter address
      * @param minterAddress address of the new minter 
      */
    function setMinter(address minterAddress)
        public 
        onlyValidator 
        checkIsAddressValid(minterAddress)
    {
        minter = minterAddress;
        emit MinterUpdated(minterAddress);
    }

    /** @dev buy tokens request
      * @param beneficiary the address to which the tokens have to be minted
      */
    function buyTokens(address beneficiary)
        public 
        payable
        checkIsInvestorApproved(beneficiary)
    {
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // calculate token amount to be created
        uint256 tokens = weiAmount.mul(rate);

        pendingMints[currentMintNonce] = MintStruct(beneficiary, tokens, weiAmount);
        emit ContributionRegistered(beneficiary, tokens, weiAmount, currentMintNonce);

        currentMintNonce++;
    }

    function assignTokens(address beneficiary, uint256 tokens) 
        external
    {
        require(_assignTokens(beneficiary, tokens));
    }

    /** @dev approve buy tokens requests in bulk
      * @param beneficiaries array of beneficiary addresses
      * @param tokens array of tokens to be minted to respective beneficiaries
      */
    function bulkAssignTokens(address[] beneficiaries, uint256[] tokens)
        external
    {
        require(beneficiaries.length == tokens.length);

        for (uint i = 0; i < tokens.length; i++) {
            require(_assignTokens(beneficiaries[i], tokens[i]));
        }        
    }

    function _assignTokens(address beneficiary, uint256 tokens) 
        private
        isMinter
        checkIsInvestorApproved(beneficiary)
        returns (bool)
    {
        require(now >= startTime && now <= endTime);
        require(tokens > 0);

        pendingMints[currentMintNonce] = MintStruct(beneficiary, tokens, 0);
        emit ContributionRegistered(beneficiary, tokens, 0, currentMintNonce);

        require(validMint(currentMintNonce));

        currentMintNonce++;

        return true;
    }

    /** @dev Updates token rate 
    * @param _rate New token rate 
    */ 
    function updateRate(uint256 _rate) public onlyOwner { 
        require(_rate > 0);
        rate = _rate;
        emit RateUpdated(rate);
    }

    /** @dev Updates reason for an invalid purchase 
    * @param _reason New reason for an invalid purchase 
    */ 
    function updateInvalidPurchaseReason(uint256 _reason) public onlyOwner { 
        require(_reason > 0);
        invalidPurchaseReason = _reason;
        emit InvalidPurchaseReasonUpdated(invalidPurchaseReason);
    }

    /** @dev approve buy tokens request
      * @param nonce request recorded at this particular nonce
      */
    function approveMint(uint256 nonce)
        external 
        onlyValidator
    {
        require(_approveMint(nonce));
    }

    /** @dev reject buy tokens request
      * @param nonce request recorded at this particular nonce
      * @param reason reason for rejection
      */
    function rejectMint(uint256 nonce, uint256 reason)
        external 
        onlyValidator
    {
        _rejectMint(nonce, reason);
    }

    /** @dev approve buy tokens requests in bulk
      * @param nonces request recorded at these nonces
      */
    function bulkApproveMints(uint256[] nonces)
        external 
        onlyValidator
    {
        for (uint i = 0; i < nonces.length; i++) {
            require(_approveMint(nonces[i]));
        }        
    }
    
    /** @dev reject buy tokens requests
      * @param nonces request recorded at these nonces
      * @param reasons reasons for rejection
      */
    function bulkRejectMints(uint256[] nonces, uint256[] reasons)
        external 
        onlyValidator
    {
        require(nonces.length == reasons.length);
        for (uint i = 0; i < nonces.length; i++) {
            _rejectMint(nonces[i], reasons[i]);
        }
    }

    /** @dev approve buy tokens request called internally in the approveMint and bulkApproveMints functions
      * @param nonce request recorded at this particular nonce
      */
    function _approveMint(uint256 nonce)
        private
        checkIsInvestorApproved(pendingMints[nonce].to)
        returns (bool)
    {
        bool valid = validMint(nonce);

        if (valid) {
            // update state
            weiRaised = weiRaised.add(pendingMints[nonce].weiAmount);
            totalSupply = totalSupply.add(pendingMints[nonce].tokens);

            //No need to use mint-approval on token side, since the minting is already approved in the crowdsale side
            TokenInterface(token).mint(pendingMints[nonce].to, pendingMints[nonce].tokens);
            
            emit TokenPurchase(
                msg.sender,
                pendingMints[nonce].to,
                pendingMints[nonce].weiAmount,
                pendingMints[nonce].tokens
            );

            forwardFunds(pendingMints[nonce].weiAmount);
            delete pendingMints[nonce];
        } else {
            _rejectMint(nonce, invalidPurchaseReason);
        }

        return true;
    }

    /** @dev reject buy tokens request called internally in the rejectMint and bulkRejectMints functions
      * @param nonce request recorded at this particular nonce
      * @param reason reason for rejection
      */
    function _rejectMint(uint256 nonce, uint256 reason)
        private
        checkIsAddressValid(pendingMints[nonce].to)
    {
        rejectedMintBalance[pendingMints[nonce].to] = rejectedMintBalance[pendingMints[nonce].to].add(pendingMints[nonce].weiAmount);
        
        emit MintRejected(
            pendingMints[nonce].to,
            pendingMints[nonce].tokens,
            pendingMints[nonce].weiAmount,
            nonce,
            reason
        );
        
        delete pendingMints[nonce];
    }

    function validMint(uint256 nonce) internal view returns (bool) {
        if (capped == Cap.HardCapped) {

            require(weiRaised.add(pendingMints[nonce].weiAmount) <= hardCap);

        } else if (capped == Cap.TokenCapped) {

            require(totalSupply.add(pendingMints[nonce].tokens) <= tokenCap);
        
        }

        return true;
    }

    /** @dev claim back ether if buy tokens request is rejected */
    function claim() external {
        require(rejectedMintBalance[msg.sender] > 0);
        uint256 value = rejectedMintBalance[msg.sender];
        rejectedMintBalance[msg.sender] = 0;

        msg.sender.transfer(value);

        emit Claimed(msg.sender, value);
    }

    function finalization() internal {
        TokenInterface(token).finishMinting();
        transferTokenOwnership(owner);
        super.finalization();
    }

    /** @dev Updates token contract address
      * @param newToken New token contract address
      */
    function setTokenContract(address newToken)
        external 
        onlyOwner
        checkIsAddressValid(newToken)
    {
        token = newToken;
    }

    /** @dev transfers ownership of the token contract
      * @param newOwner New owner of the token contract
      */
    function transferTokenOwnership(address newOwner)
        public 
        onlyOwner
        checkIsAddressValid(newOwner)
    {
        TokenInterface(token).transferOwnership(newOwner);
    }

    function forwardFunds(uint256 amount) internal {
        wallet.transfer(amount);
    }
}

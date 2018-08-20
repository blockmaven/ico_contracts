pragma solidity 0.4.25;

import "../EthFeeEssentials/MintableTokenEthFee.sol";
import "../../Essentials/Validator.sol";
import "../../Whitelist/Whitelist.sol";
import "../DetailedERC20.sol";


/** @title Compliant Token */
contract CompliantTokenSwitchEthFee is Validator, DetailedERC20, MintableTokenEthFee {
    Whitelist public whiteListingContract;

    struct TransactionStruct {
        address from;
        address to;
        uint256 value;
        uint256 fee;
        address spender;
    }

    mapping (uint => TransactionStruct) public pendingTransactions;
    mapping (address => mapping (address => uint256)) public pendingApprovalAmount;
    uint256 public currentNonce = 0;
    uint256 public transferFee;
    address public feeRecipient;
    bool public tokenSwitch;

    modifier checkIsInvestorApproved(address _account) {
        if (!tokenSwitch) require(whiteListingContract.isInvestorApproved(_account));
        _;
    }

    modifier checkIsAddressValid(address _account) {
        require(_account != address(0));
        _;
    }

    modifier checkIsValueValid(uint256 _value) {
        require(_value > 0);
        _;
    }

    modifier isFeeNeeded(address _from) {
        if (_from == feeRecipient || tokenSwitch) {
            require(msg.value == 0);
            _;
        } else {
            require(msg.value >= transferFee);
            _;
        }
    }

    /**
    * event for rejected transfer logging
    * @param from address from which tokens have to be transferred
    * @param to address to tokens have to be transferred
    * @param value number of tokens
    * @param nonce request recorded at this particular nonce
    * @param reason reason for rejection
    */
    event TransferRejected(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 indexed nonce,
        uint256 reason
    );

    /**
    * event for transfer tokens logging
    * @param from address from which tokens have to be transferred
    * @param to address to tokens have to be transferred
    * @param value number of tokens
    * @param fee fee in tokens
    */
    event TransferWithEthFee(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 fee
    );

    /**
    * event for transfer/transferFrom request logging
    * @param from address from which tokens have to be transferred
    * @param to address to tokens have to be transferred
    * @param value number of tokens
    * @param fee fee in tokens
    * @param spender The address which will spend the tokens
    * @param nonce request recorded at this particular nonce
    */
    event RecordedPendingTransaction(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 fee,
        address indexed spender,
        uint256 nonce
    );

    /**
    * event for token switch activate logging
    */
    event TokenSwitchActivated();

    /**
    * event for token switch deactivate logging
    */
    event TokenSwitchDeactivated();

    /**
    * event for whitelist contract update logging
    * @param _whiteListingContract address of the new whitelist contract
    */
    event WhiteListingContractSet(address indexed _whiteListingContract);

    /**
    * event for fee update logging
    * @param previousFee previous fee
    * @param newFee new fee
    */
    event FeeSet(uint256 indexed previousFee, uint256 indexed newFee);

    /**
    * event for fee recipient update logging
    * @param previousRecipient address of the old fee recipient
    * @param newRecipient address of the new fee recipient
    */
    event FeeRecipientSet(address indexed previousRecipient, address indexed newRecipient);

    /** @dev Constructor
      * @param _owner Token contract owner
      * @param _name Token name
      * @param _symbol Token symbol
      * @param _decimals number of decimals in the token(usually 18)
      * @param whitelistAddress Ethereum address of the whitelist contract
      * @param recipient Ethereum address of the fee recipient
      * @param fee token fee for approving a transfer
      */
    constructor(
        address _owner,
        string _name, 
        string _symbol, 
        uint8 _decimals,
        address whitelistAddress,
        address recipient,
        uint256 fee
    )
        public
        MintableTokenEthFee(_owner)
        DetailedERC20(_name, _symbol, _decimals)
        Validator()
    {
        setWhitelistContract(whitelistAddress);
        setFeeRecipient(recipient);
        setFee(fee);
    }

    /** @dev Updates whitelist contract address
      * @param whitelistAddress New whitelist contract address
      */
    function setWhitelistContract(address whitelistAddress)
        public
        onlyValidator
        checkIsAddressValid(whitelistAddress)
    {
        whiteListingContract = Whitelist(whitelistAddress);
        emit WhiteListingContractSet(whiteListingContract);
    }

    /** @dev Updates token fee for approving a transfer
      * @param fee New token fee
      */
    function setFee(uint256 fee)
        public
        onlyValidator
    {
        emit FeeSet(transferFee, fee);
        transferFee = fee;
    }

    /** @dev Updates fee recipient address
      * @param recipient New whitelist contract address
      */
    function setFeeRecipient(address recipient)
        public
        onlyValidator
        checkIsAddressValid(recipient)
    {
        emit FeeRecipientSet(feeRecipient, recipient);
        feeRecipient = recipient;
    }

    /** @dev activates token switch after which no validator approval is required for transfer */
    function activateTokenSwitch() public onlyValidator {
        tokenSwitch = true;
        emit TokenSwitchActivated();
    }

    /** @dev deactivates token switch after which validator approval is required for transfer */ 
    function deactivateTokenSwitch() public onlyValidator {
        tokenSwitch = false;
        emit TokenSwitchDeactivated();
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

    /** @dev transfer
      * @param _to address to which the tokens have to be transferred
      * @param _value amount of tokens to be transferred
      */
    function transfer(address _to, uint256 _value)
        public
        payable
        checkIsInvestorApproved(msg.sender)
        checkIsInvestorApproved(_to)
        checkIsValueValid(_value)
        isFeeNeeded(msg.sender)
        returns (bool)
    {
        if (tokenSwitch) {
            super.transfer(_to, _value);
        } else {
            uint256 pendingAmount = pendingApprovalAmount[msg.sender][address(0)];

            require(_value.add(pendingAmount) <= balances[msg.sender]);
            pendingApprovalAmount[msg.sender][address(0)] = pendingAmount.add(_value);

            pendingTransactions[currentNonce] = TransactionStruct(
                msg.sender,
                _to,
                _value,
                msg.value,
                address(0)
            );

            emit RecordedPendingTransaction(msg.sender, _to, _value, msg.value, address(0), currentNonce);
            currentNonce++;
        }

        return true;
    }

    /** @dev transferFrom
      * @param _from address from which the tokens have to be transferred
      * @param _to address to which the tokens have to be transferred
      * @param _value amount of tokens to be transferred
      */
    function transferFrom(address _from, address _to, uint256 _value)
        public
        payable
        checkIsInvestorApproved(_from)
        checkIsInvestorApproved(_to)
        checkIsValueValid(_value)
        isFeeNeeded(_from)
        returns (bool)
    {
        if (tokenSwitch) {
            super.transferFrom(_from, _to, _value);
        } else {
            uint256 allowedTransferAmount = allowed[_from][msg.sender];
            uint256 pendingAmount = pendingApprovalAmount[_from][msg.sender];

            require(_value.add(pendingAmount) <= balances[_from]);
            require(_value.add(pendingAmount) <= allowedTransferAmount);
            pendingApprovalAmount[_from][msg.sender] = pendingAmount.add(_value);

            pendingTransactions[currentNonce] = TransactionStruct(
                _from,
                _to,
                _value,
                msg.value,
                msg.sender
            );

            emit RecordedPendingTransaction(_from, _to, _value, msg.value, msg.sender, currentNonce);
            currentNonce++;
        }

        return true;
    }

    /** @dev approve transfer/transferFrom request
      * @param nonce request recorded at this particular nonce
      */
    function approveTransfer(uint256 nonce)
        external 
        onlyValidator
    {   
        require(_approveTransfer(nonce));
    }    

    /** @dev reject transfer/transferFrom request
      * @param nonce request recorded at this particular nonce
      * @param reason reason for rejection
      */
    function rejectTransfer(uint256 nonce, uint256 reason)
        external 
        onlyValidator
    {        
        _rejectTransfer(nonce, reason);
    }

    /** @dev approve transfer/transferFrom requests
      * @param nonces request recorded at these nonces
      */
    function bulkApproveTransfers(uint256[] nonces)
        external 
        onlyValidator
        returns (bool)
    {
        for (uint i = 0; i < nonces.length; i++) {
            require(_approveTransfer(nonces[i]));
        }
    }

    /** @dev reject transfer/transferFrom request
      * @param nonces requests recorded at these nonces
      * @param reasons reasons for rejection
      */
    function bulkRejectTransfers(uint256[] nonces, uint256[] reasons)
        external 
        onlyValidator
    {
        require(nonces.length == reasons.length);
        for (uint i = 0; i < nonces.length; i++) {
            _rejectTransfer(nonces[i], reasons[i]);
        }
    }

    /** @dev approve transfer/transferFrom request called internally in the approveTransfer and bulkApproveTransfers functions
      * @param nonce request recorded at this particular nonce
      */
    function _approveTransfer(uint256 nonce)
        private
        checkIsInvestorApproved(pendingTransactions[nonce].from)
        checkIsInvestorApproved(pendingTransactions[nonce].to)
        returns (bool)
    {   
        address from = pendingTransactions[nonce].from;
        address to = pendingTransactions[nonce].to;
        address spender = pendingTransactions[nonce].spender;
        uint256 value = pendingTransactions[nonce].value;
        uint256 fee = pendingTransactions[nonce].fee;

        delete pendingTransactions[nonce];

        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);

        if (spender != address(0)) {
            allowed[from][spender] = allowed[from][spender].sub(value);
        }

        pendingApprovalAmount[from][spender] = pendingApprovalAmount[from][spender].sub(value);

        emit Transfer(
            from,
            to,
            value
        );

        if (fee != 0) {
            
            emit TransferWithEthFee(
                from,
                to,
                value,
                fee
            );

            feeRecipient.transfer(fee);

        }

        return true;
    }    

    /** @dev reject transfer/transferFrom request called internally in the rejectTransfer and bulkRejectTransfers functions
      * @param nonce request recorded at this particular nonce
      * @param reason reason for rejection
      */
    function _rejectTransfer(uint256 nonce, uint256 reason)
        private
        checkIsAddressValid(pendingTransactions[nonce].from)
    {
        address from = pendingTransactions[nonce].from;
        address spender = pendingTransactions[nonce].spender;
        uint256 value = pendingTransactions[nonce].value;
        uint256 fee = pendingTransactions[nonce].fee;

        pendingApprovalAmount[from][spender] = pendingApprovalAmount[from][spender].sub(value);
        
        emit TransferRejected(
            from,
            pendingTransactions[nonce].to,
            value,
            nonce,
            reason
        );
        
        delete pendingTransactions[nonce];

        feeRecipient.transfer(fee);
    }
}

pragma solidity >=0.5.0<0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./RunningPetCoin.sol";
import "./RunningPetCoinSafeMath.sol";

/**
 * @title RunningPetCoin Multi Signature contract
 */
contract RunningPetCoinMultiSigWallet {
    /*  Enums  */

    enum TxType {
        TRANSFER,
        SIGNER_ADD, SIGNER_REMOVE,
        ADMIN_CHANGE, VAULT_CHANGE, OWNER_CHANGE
    }

    enum TxStatus { NOT_FULLY_SIGNED, FULLY_SIGNED, EXECUTED }

    /*  Events  */

    /* Contract Created */
    event MultiSigCreated(address indexed creator, address indexed RunningPetCoin);

    event EthReceived(address indexed sender, uint value);

    /* Tx related events */
    event TransferRequested(uint16 id, address indexed requester, address indexed to,
        uint256 amountUnitPart, uint256 amountMinunitPart, string desc);
    event SignerAddRequested(uint16 id, address indexed requester, address indexed who, string desc);
    event SignerRemoveRequested(uint16 id, address indexed requester, address indexed who, string desc);
    event OwnerChangeRequested(uint16 id, address indexed requester, address indexed who, string desc);
    event AdminChangeRequested(uint16 id, address indexed requester, address indexed who, string desc);
    event VaultChangeRequested(uint16 id, address indexed requester, address indexed who, string desc);

    event TXExecuted(uint16 id);
    event TXExecutionFailed(uint16 id);
    event TXSigned(uint16 id, address indexed who, int nth);
    event TXFullySigned(uint16 id, address indexed who, int nth);

    /* Signer change related events */
    event SignerAdded(address indexed who);
    event SignerRemoved(address indexed who);
    event SignerCannotAdded(address indexed who, string reason);
    event SignerCannotRemoved(address indexed who, string reason);

    /* for debugging */
    event DebugMsg1(string msg, uint256 value1);
    event DebugMsg1A(string msg, address value1);

    /*  Constants  */
    uint constant MAX_OWNER_COUNT = 50;
    uint256 constant MINUNIT_PER_UNIT = 1000000000; // 1e9 Minunit per Unit
    uint256 MAX_TX = 10000;

    /*  Storage  */
    struct TXRequest {
      string description;
      TxType txType;
      TxStatus status;
      address who;
      uint256 amount;
    }

    using RunningPetCoinSafeMath for uint8;
    using SafeMath for uint256;

    mapping(address => bool) internal signerMap; // instead of iterating array, we will use this to check signer
    mapping(uint16 => TXRequest) internal requestMap; // map of requested Tx
    mapping(uint16 => address[]) internal requestSignMap; // map which contains signers who signed each Tx

    address owner;
    address[] signers;

    string public description;
    RunningPetCoin public RunningPetCoin;

    uint8 public requiredNoOfSign;
    uint16 internal nextTx;

    /*  Modifiers  */
    // With this modifier, the function should run using this contract's request TX functionality.
    modifier viaTXOnly() {
        require(msg.sender == address(this));
        _;
    }

    // Various owner/signer checking modifiers
    modifier senderIsOwner() {
        require(owner == msg.sender);
        _;
    }

    modifier senderIsOwnerOrSigner() {
        require(signerMap[msg.sender] || owner == msg.sender);
        _;
    }

    modifier senderIsSigner() {
        require(signerMap[msg.sender]);
        _;
    }

    modifier senderIsSignerOrSelf() {
        require(signerMap[msg.sender] || msg.sender == address(this));
        _;
    }

    modifier senderIsNotSigner() {
        require(!signerMap[msg.sender]);
        _;
    }

    modifier isSigner(address addr) {
        require(signerMap[addr]);
        _;
    }

    modifier isNotSigner(address addr) {
        require(!signerMap[addr]);
        _;
    }

    /* check the txid is valid (using the nextTx counter) */
    modifier validTxID(uint16 txid) {
        require(txid < nextTx);
        _;
    }

    modifier addressIsNotThis(address addr) {
        require(addr != address(this));
        _;
    }

    /*  Public Functions  */

    /**
     * @dev multi sign constructor
     *
     * @param _signers All signers who can sign each TX(TX means transaction stored in this wallet).
     * @param  _requiredSign Minimum number of signs for TX to be run.
     * @param _RunningPetCoinAddress RunningPetCoin address
     *
     */
    constructor (address[] memory _signers, uint8 _requiredSign, address _RunningPetCoinAddress, string memory _description) public {
        require(_signers.length >= 3 && _signers.length <= MAX_OWNER_COUNT);
        require(_requiredSign >= 2);

        uint i;
        for (i = 0; i < _signers.length; ++i) {
            // check signer repetition and validity
            require(_signers[i] != address(0) && !signerMap[_signers[i]]);

            // add to map to make signership(?) check fast
            signerMap[_signers[i]] = true;
        }
        signers = _signers;

        requiredNoOfSign = _requiredSign;
        nextTx = 0;
        RunningPetCoin = RunningPetCoin(_RunningPetCoinAddress);
        owner = msg.sender;
        description = _description;
        emit MultiSigCreated(owner, _RunningPetCoinAddress);
    }

    /**
      * @dev function to request a transfer TX
      *
      * @param _to address who will get the ether
      * @param _amountUnit amount of RunningPetCoin(Play part) to be transferred
      * @param _amountMinunit amount of RunningPetCoin(Minunit part) to be transferred
      */
    function requestTransferInPlay(address _to, uint256 _amountUnit, uint256 _amountMinunit, string memory _description)
    public
    senderIsSigner
    returns (uint16) {
        uint256 dennis = _amountUnit.mul(MINUNIT_PER_UNIT).add(_amountMinunit);
        return requestTransferInMinunit(_to, dennis, _description);
    }

    function setRequestMapEntry(string memory _description, uint256 _amount,
        TxType _txType, TxStatus _txStatus, address _who)
    internal
    returns(uint16)
    {
        require(nextTx < MAX_TX);

        uint16 txid = nextTx++;

        requestMap[txid].description = _description;
        requestMap[txid].amount = _amount;
        requestMap[txid].txType = _txType;
        requestMap[txid].status = _txStatus;
        requestMap[txid].who = _who;

        // Add sender to list of signed person
        // Requesting a TX will also sign that TX
        requestSignMap[txid].push(msg.sender);

        return txid;
    }

    function requestTransferInMinunit(address _to, uint256 _amount, string memory _description)
    public
    senderIsSigner
    returns (uint16)
    {
        uint16 txid = setRequestMapEntry(_description, _amount,
            TxType.TRANSFER, TxStatus.NOT_FULLY_SIGNED, _to);

        uint256 amountUnit = _amount.div(MINUNIT_PER_UNIT);
        uint256 amountMinunit = _amount % MINUNIT_PER_UNIT;

        emit TransferRequested(txid, msg.sender, _to, amountUnit, amountMinunit, _description);
        emit TXSigned(txid, msg.sender, 1);

        // 1 sign confirmation does not make transaction run, so we don't check anything in this function

        return txid;
    }

    function requestSignerAdd(address _newSigner, string memory _description)
    public
    senderIsSigner
    isNotSigner(_newSigner)
    returns (uint16)
    {
        // set tx entries
        uint16 txid = setRequestMapEntry(_description, 0,
            TxType.SIGNER_ADD, TxStatus.NOT_FULLY_SIGNED, _newSigner);

        emit SignerAddRequested(txid, msg.sender, _newSigner, _description);
        emit TXSigned(txid, msg.sender, 1);

        // 1 sign confirmation does not make transaction run, so we don't check anything in this function

        return txid;
    }

    function requestSignerRemove(address _signerToRemove, string memory _description)
    public
    senderIsSigner
    isSigner(_signerToRemove)
    returns (uint16)
    {
        uint8 l = uint8(signers.length);

        // The number of signer cannot be less than the required number of signs
        if (l == requiredNoOfSign) {
            emit SignerCannotRemoved(_signerToRemove, "cannot meet no of min signs.");
            revert();
        }

        // set tx entries
        uint16 txid = setRequestMapEntry(_description, 0,
            TxType.SIGNER_REMOVE, TxStatus.NOT_FULLY_SIGNED, _signerToRemove);

        emit SignerRemoveRequested(txid, msg.sender, _signerToRemove, _description);
        emit TXSigned(txid, msg.sender, 1);

        // 1 sign confirmation does not make transaction run, so we don't check anything in this function

        return txid;
    }

    function requestOwnerChange(address _newOwner, string memory _description)
    public
    senderIsSigner
    returns (uint16)
    {
        // set tx entries
        uint16 txid = setRequestMapEntry(_description, 0,
            TxType.OWNER_CHANGE, TxStatus.NOT_FULLY_SIGNED, _newOwner);

        emit OwnerChangeRequested(txid, msg.sender, _newOwner, _description);
        emit TXSigned(txid, msg.sender, 1);

        // 1 sign confirmation does not make transaction run, so we don't check anything in this function

        return txid;
    }

    function requestVaultChange(address _newVault, string memory _description)
    public
    senderIsSigner
    returns (uint16)
    {
        // set tx entries
        uint16 txid = setRequestMapEntry(_description, 0,
            TxType.VAULT_CHANGE, TxStatus.NOT_FULLY_SIGNED, _newVault);

        emit VaultChangeRequested(txid, msg.sender, _newVault, _description);
        emit TXSigned(txid, msg.sender, 1);

        // 1 sign confirmation does not make transaction run, so we don't check anything in this function

        return txid;
    }

    function requestAdminChange(address _newAdmin, string memory _description)
    public
    senderIsSigner
    returns (uint16)
    {
        // set tx entries
        uint16 txid = setRequestMapEntry(_description, 0,
            TxType.ADMIN_CHANGE, TxStatus.NOT_FULLY_SIGNED, _newAdmin);

        emit AdminChangeRequested(txid, msg.sender, _newAdmin, _description);
        emit TXSigned(txid, msg.sender, 1);

        // 1 sign confirmation does not make transaction run, so we don't check anything in this function

        return txid;
    }

    // Any signer can run this to execute the (confirmed but not executed) TX.
    // For example, if this multi sign wallet contract does not have enough qtum for gas,
    // RunningPetCoin.transfer will be fail with reason out of gas. Then the TX will remain
    // confirmed but not executed. Any signer can try to re-run the TX using this function
    // after send some gas fee to this contract.
    function runConfirmedTX(uint16 txid) public validTxID(txid) senderIsSigner returns(bool)
    {
        TXRequest storage request = requestMap[txid];
        require(request.status == TxStatus.FULLY_SIGNED);

        request.status = TxStatus.EXECUTED;
        if(runTX(txid)) {
            emit TXExecuted(txid);
            return true;
        } else {
            // if execution fails, rollback the status change
            request.status = TxStatus.FULLY_SIGNED;
            emit TXExecutionFailed(txid);
            return false;
        }
    }

    function runTX(uint16 txid) internal senderIsSigner returns(bool) {
        TXRequest storage request = requestMap[txid];
        if(request.txType == TxType.TRANSFER) {
            // transfer money
            RunningPetCoin.transfer(request.who, request.amount);
        } else if(request.txType == TxType.SIGNER_ADD) {
            // NOTE: this.function() call the function externally
            //       (the sender will be this contract not the original sender)
            this.addSigner(request.who);
        } else if(request.txType == TxType.SIGNER_REMOVE) {
            this.removeSigner(request.who);
        } else if(request.txType == TxType.ADMIN_CHANGE) {
            RunningPetCoin.setAdmin(request.who);
        } else if(request.txType == TxType.OWNER_CHANGE) {
            RunningPetCoin.setOwner(request.who);
        } else if(request.txType == TxType.VAULT_CHANGE) {
            RunningPetCoin.setVault(request.who);
        } else {
            return false;
        }
        return true;
    }

    /**
     * @dev sign the txid-th TX
     *
     * If the TX becomes "confirmed" status, that will be executed also.
     */
    function signTX(uint16 txid) public validTxID(txid) senderIsSigner returns (uint8) {
        TXRequest storage request = requestMap[txid];
        address[] storage requestSign = requestSignMap[txid];

        require(request.status == TxStatus.NOT_FULLY_SIGNED);

        // number of signed person
        uint8 nSigned = 0;

        uint i;
        // check if sender already signed and count all signed person
        for (i = 0; i < requestSign.length; ++i) {
            if (requestSign[i] == msg.sender) {
                // fail if already signed by the sender
                require(false);
            }
            ++nSigned;
        }

        // push the sender to the signed array and increase nSigned counter
        requestSign.push(msg.sender);
        ++nSigned;

        emit TXSigned(txid, msg.sender, nSigned);

        // if signed enough, run the transfer
        if (nSigned >= requiredNoOfSign) {
            // to prevent recursive TX call set the status EXECUTED
            request.status = TxStatus.EXECUTED;
            // execute TX
            if(runTX(txid)) {
                emit TXExecuted(txid);
            } else {
                emit TXExecutionFailed(txid);
                // set status to FULL_SIGNED to give this TX another chance to be executed manually
                request.status = TxStatus.FULLY_SIGNED;
            }
        }
        return nSigned;
    }

    function addSigner(address _newSigner)
    public
    viaTXOnly
    isNotSigner(_newSigner)
    {
        if (signers.length < MAX_OWNER_COUNT) {
            signers.push(_newSigner);
            signerMap[_newSigner] = true;
            emit SignerAdded(_newSigner);
        } else {
            emit SignerCannotAdded(_newSigner, "Cannot add a signer because of the max limit");
        }
    }

    /**
     * @dev remove a signer
     */
    function removeSigner(address _signer)
    public
    viaTXOnly
    isSigner(_signer)
    returns (bool)
    {
        uint8 l = uint8(signers.length);

        // The number of signer cannot be less than the required number of signs
        if (l == requiredNoOfSign) {
            emit SignerCannotRemoved(_signer, "cannot meet no of min signs.");
            return false;
        }

        uint16 i;

        // find the signer
        for (i = 0; i < l; ++i) {
            if (signers[i] == _signer) {
                break;
            }
        }
        //emit DebugMsg1("found ", i);

        // We should be able to find the signer in the loop above.
        // So if i==l-1, _signer is the last element, so we do not need to do anything.
        // And if not move remaining elements a slot forward
        if (i < l.sub(1)) {
            for (++i; i < l; i++) {
                signers[i - 1] = signers[i];
                //emit DebugMsg1A("moved", signers[i - 1]);
            }
        }
        // decrease array length
        signers.length--;
        signerMap[_signer] = false;
        emit SignerRemoved(_signer);
        return true;
    }

    /**
     * @dev return the transaction status in txid-th TX
     *
     * Some client cannot parse structure stored. So, instead of returning whole structure at once,
     * this function returns n-tuple.
     */
    function viewTX(uint16 txid)
    public
    view
    validTxID(txid)
    senderIsSigner
    returns(string memory, TxType, TxStatus, address, uint256, uint256)
    {
        TXRequest memory request = requestMap[txid];
        uint256 amount = request.amount;
        uint256 amountUnit = amount.div(MINUNIT_PER_UNIT);
        uint256 amountMinunit = amount % MINUNIT_PER_UNIT;
        return (
        request.description,
        request.txType,
        request.status,
        request.who,
        amountUnit,
        amountMinunit
        );
    }

    /**
     * @dev returns list of addresses who sign the TX
     */
    function viewWhoSignTX(uint16 txid) public view validTxID(txid) senderIsSigner returns (address[] memory) {
        return requestSignMap[txid];
    }

    /**
     * @dev returns how many TX stored in this contract
     */
    function getTxCount() public view returns (uint16) {
        return nextTx;
    }

    /**
     * @dev get the list of signers
     *
     * Only owner or signer can call this function
     */
    function getSigners() public view senderIsOwnerOrSigner returns (address[] memory) { return signers; }
}

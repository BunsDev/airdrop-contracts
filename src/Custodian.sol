// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IXReceiver} from "@connext/interfaces/core/IXReceiver.sol";
import {IConnext} from "@connext/interfaces/core/IConnext.sol";

import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";
import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title Custodian
 * @author Connext Labs
 * @notice This contract acts as the central point for verifying proofs, tracking spent
 * leaves, and disbursing funds.
 */
contract Custodian is Ownable2Step, IXReceiver {
    // ========== Libraries ===========

    using SafeERC20 for IERC20;

    // ========== Events ===========
    /**
     * @notice Emitted when owner withdraws unclaimed funds
     * @param to Who the funds were sent to
     * @param amount How much of the funds were clawedback
     */
    event Clawedback(address to, uint256 amount);

    /**
     * @notice Emitted when a claim is forwarded to a specified recipient + domain
     * @param disburseId The transfer identifier for the xcall out of the contract (null if same chain)
     * @param initiateId The transfer identifier for the xcall into the contract
     * @param recipient The address receiving claimed funds
     * @param recipientDomain The domain the disbursal is going to
     * @param amount The amount to disburse with claim
     */
    event ClaimDisbursed(bytes32 indexed disburseId, bytes32 indexed initiateId, address indexed recipient, uint32 recipientDomain, uint256 amount);

    event ClaimValidated(address indexed claimant, uint32 indexed claimantDomain, uint256 amount);

    // ========== Errors ===========

    error Custodian__onlyConnext_notConnext(address sender);
    error Custodian__onlyClaimer_notClamer(address claimer);
    error Custodian__clawback_delayNotElapsed();
    error Custodian__claimBySignature_invalidSigner(address recovered, address expected);
    error Custodian__xReceive_alreadyClaimed(address claimaint);
    error Custodian__validateClaim_invalidProof();

    // ========== Storage ===========

    /**
     * @notice Timestamp when admin can start clawing back funds.
     */
    uint256 public immutable CLAWBACK_START;

    /**
     * @notice The merkle root to prove individual claims against.
     */
    bytes32 public immutable CLAIM_ROOT;

    /**
     * @notice The address of the asset of claims an ddisbursals.
     */
    address public immutable CLAIM_ASSET;

    /**
     * @notice The address of the connext contract on this chain.
     */
    address public immutable CONNEXT;

    /**
     * @notice The address of the claimer contract on this chain.
     */
    address public immutable CLAIMER;

    /**
     * @notice The local domain.
     */
    uint32 public immutable DOMAIN;

    /**
     * @notice A mapping indicating which addresses have already issued claims
     * @dev Prevents double-spend of claims across chains
     */
    mapping(address => bool) public spentAddresses;

    // ========== Modifiers ===========
    /**
     * @notice Throws if the msg.sender is not CONNEXT
     */
    modifier onlyConnext() {
        if (msg.sender != CONNEXT) {
            revert Custodian__onlyConnext_notConnext(msg.sender);
        }
        _;
    }

    /**
     * @notice Throws if the msg.sender is not the CLAIMER
     */
    modifier onlyClaimer() {
        if (msg.sender != CLAIMER) {
            revert Custodian__onlyClaimer_notClamer(msg.sender);
        }
        _;
    }

    // ========== Constructor ===========
    constructor(
        address _owner,
        address _claimAsset,
        address _connext,
        address _claimer,
        bytes32 _claimRoot,
        uint256 _clawbackDelay
    ) Ownable2Step() {
        _transferOwnership(_owner);
        CLAIM_ASSET = _claimAsset;
        CONNEXT = _connext;
        DOMAIN = uint32(IConnext(_connext).domain());
        CLAIMER = _claimer;
        CLAIM_ROOT = _claimRoot;
        CLAWBACK_START = block.timestamp + _clawbackDelay;
    }

    // ========== Admin Methods ===========

    /**
     * @notice Pulls out any funds from the contract that remain.
     * @dev Cannot start until at least 30 days after deployment (as defined by
     * the CLAWBACK_START instantiation)
     * @param _amount The amount to clawback
     * @param _to The address to send the funds to
     */
    function clawback(uint256 _amount, address _to) public onlyOwner {
        if (block.timestamp < CLAWBACK_START) {
            revert Custodian__clawback_delayNotElapsed();
        }
        IERC20(CLAIM_ASSET).transfer(_to, _amount);
        emit Clawedback(_to, _amount);
    }

    // ========== Public Methods ===========

    /**
     * @notice Called by a relayer to submit the validate a claim made by the signer. Will validate
     * the proof on behalf of the signer, mark the claim as spent, and forward the funds to the designated 
     * recipient on the designated chain.
     * @param _recipient Who the disbursement should go to
     * @param _recipientDomain Which chain funds should be disbursed on
     * @param _claimant Who is claiming the funds (signer)
     * @param _claimantDomain Which chain is in the leaf the claimaint is proving. Could be any chain they
     * have been active on
     * @param _amount The amount of the claim
     * @param _signature The signature of the claimant on the leaf
     * @param _proof The proof of the leaf in the root
     */
    function claimBySignature(
        address _recipient,
        uint32 _recipientDomain,
        address _claimant,
        uint32 _claimantDomain,
        uint256 _amount,
        bytes calldata _signature,
        bytes32[] memory _proof
    ) public {
        // Recover the signature by claimaint
        // NOTE: _claimant + _claimantDomain will be unique per valid claim
        // FIXME: we need a domain for all past supported chains
        address recovered = _recoverSignature(keccak256(abi.encodePacked(_recipient, _recipientDomain, _claimant, _claimantDomain, _amount)), _signature);
        if (recovered != _claimant) {
            revert Custodian__claimBySignature_invalidSigner(recovered, _claimant);
        }

        // Validate the claim
        _validateClaim(_claimant, _claimantDomain, _amount, _proof);
        _disburseClaim(_claimant, _recipient, _recipientDomain, _amount, bytes32(0));
    }

    /**
     * @notice This allows the Claimer contract (designed for contract wallet claims) to call
     * directly if the claimant is on the same domain as the custodian.
     * @param _claimant The address of the claimant
     * @param _amount The amount to claim
     * @param _proof The merkle proof
     */
    function claimBySender(
        address _claimant,
        uint256 _amount,
        bytes32[] memory _proof
    ) public onlyClaimer {
        _validateClaim(_claimant, DOMAIN, _amount, _proof);
        _disburseClaim(_claimant, _claimant, DOMAIN, _amount, bytes32(0));
    }

    /**
     * @notice Called by Connext via `Claimer.sol` to pass on a claim made from a spoke
     * domain. Will validate the proof, mark the claim as spent, and forward the funds back to the
     * claimant address on the claimant domain.
     * @dev This *DOES NOT* require authorization, meaning the claim can be spoofed. However, the worst
     * case there is the claimant has a claim initiated on their behalf, as the funds always go back to
     * the address / chain information included in the proven leaf.
     * @param _transferId Unique identifier for xcall from Claimer -> Custodian
     * @param _callData Calldata from Claimer. Should include proof, leaf information, and recipient
     * information
     */
    function xReceive(
        bytes32 _transferId,
        uint256, // _amount,
        address, // _asset,
        address, // _originSender,
        uint32, // _origin,
        bytes memory _callData
    ) external onlyConnext returns (bytes memory) {
        // Decode the data
        (
            address claimant,
            uint32 claimantDomain,
            uint256 amount,
            bytes32[] memory proof
        ) = abi.decode(_callData, (address, uint32, uint256, bytes32[]));

        _validateClaim(claimant, claimantDomain, amount, proof);
        _disburseClaim(claimant, claimant, claimantDomain, amount, _transferId);
        return bytes("");
    }

    // ========== Private Methods ===========

    /**
     * @notice Holds the logic to recover the signer from an encoded payload.
     * @dev Will hash and convert to an eth signed message.
     * @param _signed The hash that was signed.
     * @param _sig The signature from which we will recover the signer.
     */
    function _recoverSignature(bytes32 _signed, bytes calldata _sig) internal pure returns (address) {
        // Recover
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(_signed), _sig);
    }

    /**
     * @notice Validates a proof for a claim and marks the claimant as spent.
     * @dev The leaf is constructed as hash(claimant, claimantDomain, amount) where the {claimant,domain}
     * combination is unique per-leaf in the tree. Each claimant could have multiple leaves, but can only
     * claim once.
     * @param _claimant The address of the claimant
     * @param _claimantDomain The domain the claim comes from
     * @param _amount The amount of the claim
     * @param _proof The merkle proof
     */
    function _validateClaim(address _claimant, uint32 _claimantDomain, uint256 _amount, bytes32[] memory _proof) internal {
        // Create the leaf
        bytes32 leaf = keccak256(abi.encodePacked(_claimant, _claimantDomain, _amount));

        // Sanity check: not spent
        if (spentAddresses[_claimant]) {
            revert Custodian__xReceive_alreadyClaimed(_claimant);
        }

        // Verify the claim
        if (!MerkleProof.verify(_proof, CLAIM_ROOT, leaf)) {
            revert Custodian__validateClaim_invalidProof();
        }

        // Emit event
        emit ClaimValidated(_claimant, _claimantDomain, _amount);
    }

    /**
     * @notice Disburses the claim to the recipient on the recipient domain.
     * @param _recipient Address to receive funds
     * @param _recipientDomain Domain to receive funds
     * @param _amount Amount to send
     * @param _initiateId XCall ID that initiated disbursal. If bytes32(0), wasn't initiated via xcall
     */
    function _disburseClaim(address _claimant, address _recipient, uint32 _recipientDomain, uint256 _amount, bytes32 _initiateId) internal {
        // Mark claim as spent
        spentAddresses[_claimant] = true;

        // Disburse claim
        bytes32 disburseId;

        if (_recipientDomain == DOMAIN) {
            // Forward directly on this chain
            IERC20(CLAIM_ASSET).transfer(_recipient, _amount);
        } else {
            // Forward via crosschain transfer
            IConnext(CONNEXT).xcall(
                _recipientDomain, // destination domain
                _recipient, // to
                CLAIM_ASSET, // asset
                _recipient, // delegate, only required for self-execution + slippage
                _amount, // amount
                0, // slippage
                bytes("") // calldata
            );
        }

        // Emit event
        emit ClaimDisbursed(disburseId, _initiateId, _recipient, _recipientDomain, _amount);
    }
}
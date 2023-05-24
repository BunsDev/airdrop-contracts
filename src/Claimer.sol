// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IConnext} from "@connext/interfaces/core/IConnext.sol";

import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";

import {Custodian} from "./Custodian.sol";

/**
 * @title Claimer
 * @author Connext Labs
 * @notice This contract allows users to initiate a claim from any chain, indicating any chain
 * as the recipient.
 * 
 * The funds exist in a `Custodian` contract on mainnet, that validates the merkle proofs, and
 * sends the claim to the desired contracts
 * 
 * TODO: custodian on mainnet or somewhere cheaper?
 */
contract Claimer {
    // ========== Events ===========

    /**
     * @notice Emitted when a claim is initiated
     * @param id The transfer id for sending claim to custodian
     * @param claimant The user claiming
     * @param amount The amount to claim
     */
    event ClaimInitiated(bytes32 indexed id, address indexed claimant, uint256 amount);

    // ========== Errors ===========

    error Claimer__initiateClaim_invalidProof();

    // ========== Storage ===========

    /**
     * @notice The address of the custodian on CUSTODIAN_DOMAIN
     */
    address immutable public CUSTODIAN;
    
    /**
     * @notice The domain the custodian is deployed to
     */
    uint32 immutable public CUSTODIAN_DOMAIN;

    /**
     * @notice The current domain
     */
    uint32 immutable public DOMAIN;

    /**
     * @notice Address of Connext on this domain
     */
    address immutable public CONNEXT;

    /**
     * @notice The root to prove claims against
     */
    bytes32 immutable public CLAIM_ROOT;

    // ========== Constructor ===========

    constructor(
        address _custodian,
        uint32 _custodianDomain,
        address _connext,
        bytes32 _claimRoot
    ) {
        CUSTODIAN = _custodian;
        CUSTODIAN_DOMAIN = _custodianDomain;
        CONNEXT = _connext;
        DOMAIN = uint32(IConnext(_connext).domain());
        CLAIM_ROOT = _claimRoot;
    }

    // ========== Public Methods ===========

    /**
     * @notice Initiates crosschain claim by msg.sender, relayer fees paid by native asset only.
     * @dev Verifies proof of hash(amount, sender, salt), and xcalls to Custodian
     * @param _amount The amount of the claim (in leaf)
     * @param _proof The merkle proof of the leaf in the root
     */
    function initiateClaim(
        uint256 _amount,
        bytes32[] memory _proof
    ) public {
        // Verify the proof before sending onchain as a cost + time saving step
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, DOMAIN, _amount))));
        if (!MerkleProof.verify(_proof, CLAIM_ROOT, leaf)) {
            revert Claimer__initiateClaim_invalidProof();
        }

        bytes32 transferId;
        if (DOMAIN == CUSTODIAN_DOMAIN) {
            // Directly forward proof to custodian
            Custodian(CUSTODIAN).claimBySender(msg.sender, _amount, _proof);
        } else {
            transferId = IConnext(CONNEXT).xcall(
                CUSTODIAN_DOMAIN, // destination domain
                CUSTODIAN, // to
                address(0), // asset
                address(0), // delegate, only required for self-execution + slippage
                0, // amount
                0, // slippage
                abi.encodePacked(msg.sender, DOMAIN, _amount, _proof) // data
            );
        }

        // Emit event
        emit ClaimInitiated(transferId, msg.sender, _amount);
    }
}
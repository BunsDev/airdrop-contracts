// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/utils/cryptography/ECDSA.sol";
import "../src/Custodian.sol";
import "./Helper.sol";

// Helper contract to expose private functions
contract CustodianHelper is Custodian {
    constructor(
        address _owner,
        address _claimAsset,
        address _connext,
        address _claimer,
        bytes32 _claimRoot,
        uint256 _clawbackDelay
    ) Custodian(_owner, _claimAsset, _connext, _claimer, _claimRoot, _clawbackDelay) {}

    function recoverSignature(bytes32 _signed, bytes calldata _sig) public pure returns (address) {
        return _recoverSignature(_signed, _sig);
    }

    function validateClaim(address _claimant, uint32 _claimantDomain, uint256 _amount, bytes32[] memory _proof) public {
        return _validateClaim(_claimant, _claimantDomain, _amount, _proof);
    }

    function disburseClaim(address _claimant, address _recipient, uint32 _recipientDomain, uint256 _amount, bytes32 _initiateId) public {
        return _disburseClaim(_claimant, _recipient, _recipientDomain, _amount, _initiateId);
    }

    function markSpent(address _claimant) public {
        spentAddresses[_claimant] = true;
    }
}

contract CustodianTest is Helper {
    using ECDSA for bytes32;

    // ========== Events ===========

    event Clawedback(address to, uint256 amount);
    event ClaimDisbursed(bytes32 indexed disburseId, bytes32 indexed initiateId, address indexed recipient, uint32 recipientDomain, uint256 amount);
    event ClaimValidated(address indexed claimant, uint32 indexed claimantDomain, uint256 amount);

    // ========== Storage ===========
    CustodianHelper custodian;
    uint32 custodianDomain;
    address owner = address(123);
    address claimAsset = address(456);
    address claimer = address(2345);
    uint256 clawbackDelay = 100;
    bytes32 initiateId = bytes32(bytes("initiateId"));
    bytes callData;

    // ========== Setup ===========
    function setUp() public {
        // set the root
        _loadRoot();

        // get the leaf info
        _loadLeaf();

        // get the proof
        _loadProof();

        // set connext
        _loadConnext(_domain + 1);

        // load claimant mapping
        _loadClaimants();

        // deploy custodian
        custodian = new CustodianHelper(owner, claimAsset, _connext, claimer, _root, clawbackDelay);

        // generate calldata from initiated transfer leaf
        callData = abi.encode(_claimant, _domain, _amount, _proof);
    }

    // ========== Utils ===========
    function _getSignature(uint256 pk, bytes32 payload) public pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, payload.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(r, s, v);
        return signature;
    }

    function _setValidDisbursementEventAssertions(
        address recipient,
        uint32 recipientDomain,
        bytes32 initiateXcall
    ) public {
        // expect validate event
        vm.expectEmit(address(custodian));
        emit ClaimValidated(_claimant, _domain, _amount);

        // handle xcall event in case recipient domain != custodian domain
        bytes32 disburseId;
        if (recipientDomain != custodian.DOMAIN()) {
            disburseId = keccak256(abi.encode(recipientDomain, recipient, claimAsset, recipient, _amount, 0, bytes("")));

            // expect xcall
            vm.expectCall(_connext, 0, abi.encodeWithSelector(MockConnext.xcall.selector, recipientDomain, recipient, claimAsset, recipient, _amount, 0, bytes("")));

            // expect xcall event
            vm.expectEmit(_connext);
            emit XCalled(recipientDomain, recipient, claimAsset, recipient, _amount, 0, bytes(""));
        } else {
            // expect transfer call
            vm.expectCall(claimAsset, 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, _amount), 1);
        }

        // expect disburse event
        vm.expectEmit(address(custodian));
        emit ClaimDisbursed(disburseId, initiateXcall, recipient, recipientDomain, _amount);
    }

    // ========== clawback ===========
    function test_clawback__shouldWork() public {
        // test constants
        address to = address(this);
        uint256 amount = 100;

        // setup mock call
        vm.mockCall(claimAsset, abi.encodeWithSelector(IERC20.transfer.selector, to, amount), abi.encode(true));

        // warp
        vm.warp(custodian.CLAWBACK_START() + 10);

        // expect transfer call
        vm.expectCall(claimAsset, 0, abi.encodeWithSelector(IERC20.transfer.selector, to, amount));

        // expect event
        vm.expectEmit(address(custodian));
        emit Clawedback(to, amount);

        // make call
        vm.prank(owner);
        custodian.clawback(amount, to);
    }

    function test_clawback__failsIfNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        custodian.clawback(100, address(this));
    }

    function test_clawback__failsIfDelayNotElapsed() public {
        vm.expectRevert(Custodian.Custodian__clawback_delayNotElapsed.selector);

        vm.prank(owner);
        custodian.clawback(100, address(this));
    }

    // ========== claimBySignature ===========
    function test_claimBySignature__shouldWork() public {
        // test constants
        address recipient = address(654321);
        uint32 recipientDomain = _domain - 13;

        // generate signature
        bytes32 payload = keccak256(abi.encodePacked(recipient, recipientDomain, _claimant, _domain, _amount));
        bytes memory signature = _getSignature(_claimantKeys[_claimant], payload);

        _setValidDisbursementEventAssertions(recipient, recipientDomain, bytes32(0));

        // submit call
        custodian.claimBySignature(recipient, recipientDomain, _claimant, _domain, _amount, signature, _proof);

        // assert spent
        assertTrue(custodian.spentAddresses(_claimant));
    }

    function test_claimBySignature__failsIfRecoverFails() public {
        // generate signature
        bytes32 payload = keccak256(abi.encodePacked(_claimant, _domain, _claimant, _domain, _amount));
        bytes memory signature = _getSignature(123, payload);

        // expect failure
        vm.expectRevert(abi.encodeWithSelector(Custodian.Custodian__claimBySignature_invalidSigner.selector, vm.addr(123), _claimant));
        custodian.claimBySignature(
            _claimant,
            _domain,
            _claimant,
            _domain,
            _amount,
            signature,
            _proof
        );
    }

    // ========== claimBySender ===========
    function test_claimBySender__shouldWork() public {
        // redeploy custodian with domain from leaf
        MockConnext(_connext).setDomain(_domain);
        custodian = new CustodianHelper(owner, claimAsset, _connext, claimer, _root, clawbackDelay);
        assertEq(custodian.DOMAIN(), _domain);

        // set mock transfer call
        vm.mockCall(claimAsset, abi.encodeWithSelector(IERC20.transfer.selector, _claimant, _amount), abi.encode(true));

        _setValidDisbursementEventAssertions(_claimant, _domain, bytes32(0));

        vm.prank(claimer);
        custodian.claimBySender(_claimant, _amount, _proof);

        // check claimaint is spent
        assertTrue(custodian.spentAddresses(_claimant));
    }

    function test_claimBySender__failsIfNotClaimer() public {
        vm.expectRevert(abi.encodeWithSelector(Custodian.Custodian__onlyClaimer_notClamer.selector, address(this)));
        custodian.claimBySender(_claimant, _amount, _proof);
    }

    // ========== xReceive ===========
    function test_xReceive__shouldWork() public {
        _setValidDisbursementEventAssertions(_claimant, _domain, initiateId);
        // make call
        vm.prank(_connext);
        custodian.xReceive(initiateId, 0, address(0), address(0), uint32(0), callData);

        // ensure claimant spent
        assertTrue(custodian.spentAddresses(_claimant));
    }

    function test_xReceive__failsIfNotConnext() public {
        vm.expectRevert(abi.encodeWithSelector(Custodian.Custodian__onlyConnext_notConnext.selector, address(this)));
        custodian.xReceive(initiateId, 0, address(0), address(0), uint32(0), callData);
    }

    // ========== _recoverSignature ===========
    function test_recoverSignature__shouldWork() public {
        // get the payload
        bytes32 payload = keccak256(bytes("recover"));

        // sign payload
        address signer = vm.addr(123);
        bytes memory signature = _getSignature(123, payload);

        // recover
        address recovered = custodian.recoverSignature(payload, signature);
        assertEq(recovered, signer);
    }

    // ========== _validateClaim ===========
    // passing cases asserted at top level function success tests

    function test_validateClaim__failsIfSpent() public {
        custodian.markSpent(_claimant);

        vm.expectRevert(abi.encodeWithSelector(Custodian.Custodian__validateClaim_alreadyClaimed.selector, _claimant));
        custodian.validateClaim(_claimant, _domain, _amount, _proof);
    }

    function test_validateClaim__failsIfProofInvalid() public {
        vm.expectRevert(Custodian.Custodian__validateClaim_invalidProof.selector);
        custodian.validateClaim(address(this), _domain, _amount, _proof);
    }

    // ========== _disburseClaim ===========
    // passing cases asserted at top level function success tests
}
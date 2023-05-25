// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../src/Claimer.sol";
import "./Helper.sol";

contract ClaimerTest is Helper {
    // ========== Events ===========
    event ClaimInitiated(bytes32 indexed id, address indexed claimant, uint256 amount);

    // ========== Storage ===========
    Claimer claimer;

    address custodian = address(456456456);
    uint32 custodianDomain = uint32(12123321);

    // ========== Setup ===========
    function setUp() public {
        // set the root
        _loadRoot();

        // get the leaf info
        _loadLeaf();

        // get the proof
        _loadProof();

        // set connext
        _loadConnext(_domain);

        // deploy claimer
        claimer = new Claimer(custodian, custodianDomain, _connext, _root);
    }

    // ========== initiateClaim ===========
    function test_initiateClaim__shouldRevertIfInvalidProof() public {
        // initiate claim
        vm.expectRevert(Claimer.Claimer__initiateClaim_invalidProof.selector);
        claimer.initiateClaim(_amount, _proof);
    }

    function test_initiateClaim__shouldWork() public {
        bytes memory xcallData = abi.encodePacked(_claimant, claimer.DOMAIN(), _amount, _proof);
        // assert the emission
        vm.expectEmit(_connext);
        emit XCalled(
            custodianDomain,
            custodian,
            address(0),
            address(0),
            0,
            0,
            xcallData
        );

        // expect event
        vm.expectEmit(address(claimer));
        emit ClaimInitiated(
            keccak256(abi.encode(custodianDomain, custodian, address(0), address(0), 0, 0, xcallData)),
            _claimant,
            _amount
        );

        // initiate claim
        vm.prank(_claimant);
        claimer.initiateClaim(_amount, _proof);
    }

    function test_initiateClaim__shouldWorkWithoutCrosschain() public {
        // deploy claimer with same domain as leaf
        claimer = new Claimer(custodian, _domain, _connext, _root);

        // set custodian mock
        bytes memory expectedCall = abi.encodeWithSelector(Custodian.claimBySender.selector, _claimant, _amount, _proof);
        vm.mockCall(custodian, expectedCall, abi.encode(true));

        // assert the call to the custodian directly
        vm.expectCall(custodian, 0, expectedCall, 1);

        // expect event
        vm.expectEmit(address(claimer));
        emit ClaimInitiated(bytes32(0), _claimant, _amount);

        // initiate claim
        vm.prank(_claimant);
        claimer.initiateClaim(_amount, _proof);
    }
}
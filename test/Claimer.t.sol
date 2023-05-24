// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../src/Claimer.sol";
import "./Helper.sol";

contract ClaimerTest is Helper {
    address claimant;
    uint32 domain;
    uint256 amount;
    bytes32[] proof;

    Claimer claimer;

    address custodian = address(456456456);
    uint32 custodianDomain = uint32(12123321);

    function setUp() public {
        // set the root
        _loadRoot();

        // get the leaf info
        (claimant, domain, amount) = _getLeaf(1);

        // get the proof
        proof = _getProof(1);

        // set connext
        _loadConnext(domain);

        // deploy claimer
        claimer = new Claimer(custodian, custodianDomain, _connext, _root);
    }

    function test_initiateClaim__shouldWork() public {
        // assert the emission
        vm.expectEmit(_connext);
        emit XCalled(
            custodianDomain,
            custodian,
            address(0),
            address(0),
            0,
            0,
            abi.encodePacked(claimant, claimer.DOMAIN(), amount, proof)
        );

        // initiate claim
        vm.prank(claimant);
        claimer.initiateClaim(amount, proof);
    }
}
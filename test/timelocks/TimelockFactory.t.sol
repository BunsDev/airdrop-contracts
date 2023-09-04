// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TimelockFactory} from "../../src/timelocks/TimelockFactory.sol";
import {TimelockedDelegator} from "../../src/timelocks/TimelockedDelegator.sol";

import {CREATE3} from "solmate/utils/CREATE3.sol";

import "../utils/Helper.sol";

contract TimelockFactoryTest is TimelockHelper {

    // ============ Storage ============
    TimelockFactory public factory;

    // ============ Setup ============
    function setUp() public {
        _resetToken();
        
        factory = TimelockFactory(CREATE3.deploy(bytes32("test"), type(TimelockFactory).creationCode, 0));
    }

    // ============ Utils ============

    // ============ deploy ============
    function test_shouldDeploy(
        address _deployer,
        address _beneficiary,
        uint256 _startTime,
        uint256 _cliff
    ) public {
        // constants
        uint256 _duration = 2 * 365 days;
        address _admin = address(this);
        uint256 _amount = 1000 ether;

        // assumptions
        vm.assume(_deployer != address(0));
        vm.assume(_beneficiary != address(0));
        vm.assume(_startTime < block.timestamp);
        vm.assume(_cliff < _duration);

        // mint the deployer _amount tokens
        _token.mint(_deployer, _amount);

        vm.prank(_deployer);
        _token.approve(address(factory), _amount);

        // compute address
        address expected = factory.computeTimelockAddress(_deployer, address(_token), _beneficiary, _startTime, _amount);

        // deploy with funding
        vm.prank(_deployer);
        address deployed = factory.deployTimelock(address(_token), _beneficiary, _admin, _cliff, _startTime, _duration, _amount, _amount);

        // assert addresses okay
        assertEq(deployed, expected);

        // assert deployed properly
        assertEq(address(TimelockedDelegator(deployed).token()), address(_token), "!token");
        assertEq(TimelockedDelegator(deployed).totalToken(), _amount, "!totalToken");
        assertEq(address(TimelockedDelegator(deployed).lockedToken()), address(_token), "!lockedToken");
        assertEq(TimelockedDelegator(deployed).beneficiary(), _beneficiary, "!beneficiary");
        assertEq(TimelockedDelegator(deployed).pendingBeneficiary(), address(0), "!pendingBeneficiary");
        assertEq(_token.balanceOf(deployed), _amount, "!balance");
        assertEq(TimelockedDelegator(deployed).cliffSeconds(), _cliff, "!cliffSeconds");
        assertEq(TimelockedDelegator(deployed).clawbackAdmin(), _admin, "!clawbackAdmin");
        
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TimelockedDelegator, Delegatee} from "../../src/timelocks/TimelockedDelegator.sol";

import "../utils/Helper.sol";

contract TimelockedDelegatorTest is TimelockHelper {

    // ============ Storage ============
    TimelockedDelegator public timelockedDelegator;

    // ============ Setup ============
    function setUp() public {
        _resetToken();
        _resetDelegator();
    }

    // ============ Utils ============

    function _resetDelegator() internal {
        // deploy delegator
        timelockedDelegator = new TimelockedDelegator(
            address(_token),
            _beneficiary,
            _clawbackAdmin,
            _cliffDuration,
            _startTime,
            _duration
        );

        // fund delegator
        _token.mint(address(timelockedDelegator), _allocation);

        // assertions
        assertEq(address(timelockedDelegator.lockedToken()), address(_token), "!lockedToken");
        assertEq(timelockedDelegator.beneficiary(), _beneficiary, "!beneficiary");
        assertEq(timelockedDelegator.pendingBeneficiary(), address(0), "!pendingBeneficiary");
        assertEq(timelockedDelegator.initialBalance(), 0, "!initialBalance");
        assertEq(timelockedDelegator.cliffSeconds(), _cliffDuration, "!cliffDuration");
        assertEq(timelockedDelegator.startTime(), _startTime, "!startTime");
        assertEq(timelockedDelegator.duration(), _duration, "!duration");
        assertEq(timelockedDelegator.clawbackAdmin(), _clawbackAdmin, "!clawbackAdmin");

        assertEq(timelockedDelegator.totalToken(), _allocation, "!totalToken");
        assertEq(_token.getVotes(_beneficiary), _allocation, "!delegate power");
    }

    function _delegate(address _delegatee, uint256 _amount) internal {
        // Get initial balances
        uint256 delegatorBalance = _token.balanceOf(address(timelockedDelegator));
        uint256 managerBalance = _token.balanceOf(timelockedDelegator.delegateContract(_delegatee));
        uint256 initialVotes = _token.getVotes(_delegatee);
        uint256 totalDelegated = timelockedDelegator.totalDelegated();
        uint256 initialDelegated = timelockedDelegator.delegateAmount(_delegatee);

        // Delegate amount to delegatee + undelegate
        vm.expectEmit();
        emit Delegate(_delegatee, _amount);

        vm.prank(_beneficiary);
        timelockedDelegator.delegate(_delegatee, _amount);

        // assertions
        Delegatee manager = Delegatee(timelockedDelegator.delegateContract(_delegatee));
        assertTrue(address(manager) != address(0), "!delegatee");
        assertEq(timelockedDelegator.delegateContract(_delegatee), address(manager), "!manager");
        assertEq(timelockedDelegator.delegateAmount(_delegatee), initialDelegated + _amount, "!delegatee amount");
        assertEq(timelockedDelegator.totalDelegated(), totalDelegated + _amount, "!totalDelegated");

        assertEq(_token.balanceOf(address(timelockedDelegator)), delegatorBalance - _amount, "!delegator amount");
        assertEq(_token.balanceOf(address(manager)), managerBalance + _amount, "!manager amount");
        assertEq(_token.getVotes(_delegatee), _amount + initialVotes, "!delegate power");
    }

    function _undelegate(address _delegatee) internal {
        // Get manager + initial balance
        Delegatee manager = Delegatee(timelockedDelegator.delegateContract(_delegatee));
        uint256 managerBalance = _token.balanceOf(address(manager));
        uint256 timelockBalance = _token.balanceOf(address(timelockedDelegator));
        uint256 totalDelegated = timelockedDelegator.totalDelegated();

        // Delegate amount to delegatee + undelegate
        vm.expectEmit(address(_token));
        emit Transfer(address(manager), address(timelockedDelegator), _token.balanceOf(address(manager)));

        vm.expectEmit();
        emit Undelegate(_delegatee, timelockedDelegator.delegateAmount(_delegatee));

        vm.prank(_beneficiary);
        timelockedDelegator.undelegate(_delegatee);

        // assertions
        assertEq(timelockedDelegator.delegateContract(_delegatee), address(0), "manager");
        assertEq(timelockedDelegator.delegateAmount(_delegatee), 0, "delegatee amount");
        assertEq(timelockedDelegator.totalDelegated(), totalDelegated - managerBalance, "delegatee amount");

        assertEq(_token.balanceOf(address(manager)), 0, "manager amount");
        assertEq(_token.getVotes(_delegatee), 0, "delegate power");
        assertEq(_token.balanceOf(address(timelockedDelegator)), timelockBalance + managerBalance, "timelock amount");
    }

    // ============ delegate / undelegate ============
    function test_delegation_shouldDelegateAndUndelegate(address _delegatee, uint256 _amount) public {
        // Sanity check: less then allocation
        vm.assume(_amount < _allocation);

        // Delegate amount to delegatee + undelegate
        _delegate(_delegatee, _amount);

        // Undelegate amount
        _undelegate(_delegatee);
    }

    // ============ release ============
    function test_release_honorsCliff(uint256 _elapsed, address _to) public {
        vm.assume(_elapsed < _cliffDuration);

        // fast forward
        vm.warp(_startTime + _elapsed);
        assertEq(timelockedDelegator.timeSinceStart(), _elapsed, "!timeSinceStart");

        // expect nothing can be released before cliff
        assertEq(timelockedDelegator.availableForRelease(), 0, "availableForRelease");
        assertEq(timelockedDelegator.alreadyReleasedAmount(), 0, "released");
        assertEq(timelockedDelegator.totalToken(), _allocation, "!full balance");
        assertEq(timelockedDelegator.passedCliff(), false, "passed cliff");
        assertEq(_token.balanceOf(_to), 0, "!to");

        // fast forward to cliff + elapsed
        vm.warp(_startTime + _cliffDuration + _elapsed);
        assertEq(timelockedDelegator.timeSinceStart(), _cliffDuration + _elapsed, "!time");
        assertEq(timelockedDelegator.passedCliff(), true, "!passed cliff");

        // expect the proportional amount to be available
        uint256 expected = (_allocation * (_cliffDuration + _elapsed)) / _duration;

        // release 1 to set initial balance
        vm.expectEmit(address(timelockedDelegator));
        emit Release(_beneficiary, _to, 1);
        vm.prank(_beneficiary);
        timelockedDelegator.release(_to, 1);
        assertEq(timelockedDelegator.availableForRelease(), expected - 1, "!availableForRelease");

        // claim full amount
        vm.expectEmit(address(_token));
        emit Transfer(address(timelockedDelegator), _to, expected - 1);

        vm.expectEmit(address(timelockedDelegator));
        emit Release(_beneficiary, _to, expected - 1);
        vm.prank(_beneficiary);
        timelockedDelegator.releaseMax(_to);

        assertEq(timelockedDelegator.alreadyReleasedAmount(), expected, "!released");
        assertEq(timelockedDelegator.totalToken(), _allocation - expected, "full balance");
        assertEq(_token.balanceOf(_to), expected, "to");
    }
}
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./TokenTimelock.sol";

/// Modified from: https://github.com/fei-protocol/fei-protocol-core/blob/develop/contracts/timelocks/LinearTokenTimelock.sol
/// @author Fei Protocol
contract LinearTokenTimelock is TokenTimelock {
    constructor(
        address _beneficiary,
        uint256 _duration,
        address _lockedToken,
        uint256 _cliffDuration,
        address _clawbackAdmin,
        uint256 _startTime
    ) TokenTimelock(_beneficiary, _duration, _cliffDuration, _lockedToken, _clawbackAdmin) {
        if (_startTime != 0) {
            startTime = _startTime;
        }
    }

    function _proportionAvailable(
        uint256 initialBalance,
        uint256 elapsed,
        uint256 duration
    ) internal pure override returns (uint256) {
        return (initialBalance * elapsed) / duration;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

import {TimelockedDelegator} from "./TimelockedDelegator.sol";

contract TimelockFactory {
    // ============ events ============
    event TimelockDeployed(
        address indexed timelock,
        address indexed token,
        address indexed beneficiary,
        address admin,
        uint256 cliffDuration,
        uint256 startTime,
        uint256 duration
    );

    // ============ public functions ============

    function deployTimelock(
        address _token,
        address _beneficiary,
        address _admin,
        uint256 _cliffDuration,
        uint256 _startTime,
        uint256 _duration,
        uint256 _funding
    ) public {
        address deployed = _deployTimelock(_token, _beneficiary, _admin, _cliffDuration, _startTime, _duration);

        if (_funding > 0) {
            // fund timelock
            IERC20(_token).transferFrom(msg.sender, deployed, _funding);
        }
    }

    // ============ internal functions ============
    function _deployTimelock(
        address _token,
        address _beneficiary,
        address _admin,
        uint256 _cliffDuration,
        uint256 _startTime,
        uint256 _duration
    ) internal returns (address _deployed) {
        // Get salt
        bytes32 salt = _getSalt(_token, _beneficiary, _admin, msg.sender);

        // Get bytecode
        bytes memory bytecode = _getBytecode(_token, _beneficiary, _admin, _cliffDuration, _startTime, _duration);

        // Deploy timelock
        _deployed = CREATE3.deploy(salt, bytecode, 0);
        emit TimelockDeployed(_deployed, _token, _beneficiary, _admin, _cliffDuration, _startTime, _duration);
    }

    function _getSalt(
        address _token,
        address _beneficiary,
        address _admin,
        address _deployer
    ) internal pure returns (bytes32 _salt) {
        _salt = keccak256(abi.encodePacked(_token, _beneficiary, _admin, _deployer));
    }

    function _getBytecode(
        address _token,
        address _beneficiary,
        address _admin,
        uint256 _cliffDuration,
        uint256 _startTime,
        uint256 _duration
    ) internal pure returns (bytes memory _bytecode) {
        _bytecode = abi.encodePacked(
            type(TimelockedDelegator).creationCode,
            abi.encode(_token, _beneficiary, _admin, _cliffDuration, _startTime, _duration)
        );
    }
}

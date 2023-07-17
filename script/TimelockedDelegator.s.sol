// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Create2} from "@openzeppelin/utils/Create2.sol";
import {Address} from "@openzeppelin/utils/Address.sol";

import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {TimelockedDelegator} from "src/timelocks/TimelockedDelegator.sol";

import {RpcLookup} from "./utils/RpcLookup.sol";

import "forge-std/Script.sol";
import "forge-std/Script.sol";

contract TimelockedDelegatorDeploy is Script {
    // ============ Libraries ============
    using stdJson for string;
    using Strings for string;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    // ============ Structs ============

    /**
     * @notice This struct defines all of the information required to deploy a timelock delegator
     * on behalf of a given beneficiary.
     * @dev This information should be passed in via a csv file. Deployment records will hold all of
     * this information, as a json keyed on provided beneficiary.
     * @param beneficiary The address of the beneficiary
     * @param amount The amount of tokens to be locked
     * @param startTime The start time of the timelock in seconds
     * @param cliffDuration The cliff duration of the timelock in seconds
     * @param duration The duration of the timelock in seconds
     */
    struct ConfiguredBeneficiary {
        uint256 amount;
        address beneficiary;
        uint256 cliffDuration;
        uint256 duration;
        uint256 startTime;
    }

    struct TimelockDeployment {
        address beneficiary;
        uint256 chain;
        address clawbackAdmin;
        uint256 duration;
        uint256 startTime;
        address timelock;
    }

    // ============ Storage ============
    string public constant BENEFICIARY_FILENAME = "beneficiaries.json";
    string public constant DEPLOYMENT_FILENAME = "timelocks.json";

    address public deployer;

    // ============ Script ============

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        bool fundFromDeployer = vm.envOr("FUND_FROM_DEPLOYER", false);
        console.log("Deployer:", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Load the beneficiaries
        ConfiguredBeneficiary[] memory beneficiaries = _loadBeneficiaries();
        require(beneficiaries.length > 0, "!beneficiaries");

        console.log("Loaded %s beneficiaries", beneficiaries.length);
        // _logBeneficiary(beneficiaries[0]);

        // Deploy timelocks for each beneficiary if needed
        address[] memory timelocks = new address[](beneficiaries.length);
        for (uint256 i; i < beneficiaries.length; i++) {
            address expected = _calculateTimelockAddress(beneficiaries[i]);
            if (Address.isContract(expected)) {
                timelocks[i] = expected;
                console.log("Deployed at:", expected);
                continue;
            }

            // Deploy the timelock + enforce the expected address
            console.log("Deploying timelock for:", beneficiaries[i].beneficiary);
            timelocks[i] = _deployTimelock(beneficiaries[i], expected);

            // NOTE: we can fund from deployer, but we can also fund from an external source
            // post deployment. This is useful for testing and security in production.
            if (fundFromDeployer) {
                // Fund the timelock
                console.log("Funding the timelock...");
                address token = RpcLookup.getVestingTokenAddress(block.chainid);
                IERC20(token).safeTransfer(expected, beneficiaries[i].amount);
            }

            // Store the timelock address
            _logTimelock(timelocks[i]);
            console.log("Deployment completed:", expected);
            console.log("");
        }

        vm.stopBroadcast();

        // TODO: Record deployments
        // Write to the deployment file
        _writeDeploymentRecords(beneficiaries, timelocks);
    }

    // ============ Utilities ============
    // ============ Deployments 
    /**
     * @notice Deployes a timelock
     */
    function _deployTimelock(ConfiguredBeneficiary memory _beneficiary, address _expected) internal returns (address _deployed) {
        bytes32 salt = _calculateTimelockSalt(_beneficiary);
        _deployed = Create2.deploy(0, salt, _getCreationBytecode(_beneficiary));
        require(_deployed == _expected, "deployed != expected");
    }

    /**
     * @notice Calculates the create2 deployment address
     */
    function _hasDeployedTimelock(ConfiguredBeneficiary memory _beneficiary) internal returns (bool _hasDeployed) {
        address expected = _calculateTimelockAddress(_beneficiary);
        _hasDeployed = Address.isContract(expected);
    }

    /**
     * @notice Calculates the create2 creation code including constructor params
     */
    function _getCreationBytecode(ConfiguredBeneficiary memory _beneficiary) internal returns (bytes memory) {
        return bytes.concat(
            type(TimelockedDelegator).creationCode, 
            abi.encode(
                RpcLookup.getVestingTokenAddress(block.chainid),
                _beneficiary.beneficiary,
                vm.envOr(RpcLookup.getClawbackAdminEnvName(block.chainid), address(0)),
                _beneficiary.cliffDuration,
                _beneficiary.startTime,
                _beneficiary.duration
            )
        );
    }

    /**
     * @notice Calculates the create2 deployment address
     */
    function _calculateTimelockAddress(ConfiguredBeneficiary memory _beneficiary) internal returns (address _timelock) {
        _timelock = _calculateTimelockWithSalt(_calculateTimelockSalt(_beneficiary), _beneficiary);
    }

    /**
     * @notice Calculates the create2 deployment address with a given salt
     */
    function _calculateTimelockWithSalt(bytes32 _salt, ConfiguredBeneficiary memory _beneficiary) internal returns (address _expected) {
        _expected = Create2.computeAddress(_salt, keccak256(_getCreationBytecode(_beneficiary)), CREATE2_FACTORY);
    }

    /**
     * @notice Calculates the create2 salt for a given beneficiary
     * @param _beneficiary The beneficiary to calculate the salt for
     */
    function _calculateTimelockSalt(ConfiguredBeneficiary memory _beneficiary) internal pure returns (bytes32 _salt) {
        _salt = keccak256(abi.encode(_beneficiary.beneficiary, _beneficiary.startTime, _beneficiary.duration));
    }

    // ============ Files
    /**
     * @notice Loads the beneficiaries from the json file
     */
    function _loadBeneficiaries() internal view returns (ConfiguredBeneficiary[] memory _beneficiaries) {
        _beneficiaries = abi.decode(vm.parseJson(_loadJson()), (ConfiguredBeneficiary[]));
    }

    function _loadJson() internal view returns (string memory _json) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/", BENEFICIARY_FILENAME);
        _json = vm.readFile(path);
    }

    function _writeDeploymentRecords(ConfiguredBeneficiary[] memory _beneficiaries, address[] memory _timelocks) internal {
        require(_beneficiaries.length == _timelocks.length, "!length");
        string[] memory serializedBeneficiaries = new string[](_beneficiaries.length);
        for (uint256 i; i < _beneficiaries.length; i++) {
            // Serialize each value of the Record
            TimelockedDelegator timelock = TimelockedDelegator(_timelocks[i]);
            string memory key = string.concat("object", i.toString());
            vm.serializeAddress(key, "beneficiary", timelock.beneficiary());
            vm.serializeUint(key, "chain", block.chainid);
            vm.serializeAddress(key, "clawbackAdmin", timelock.clawbackAdmin());
            vm.serializeUint(key, "duration", timelock.duration());
            vm.serializeUint(key, "startTime", timelock.startTime());
            serializedBeneficiaries[i] = vm.serializeAddress(key, "timelock", _timelocks[i]);
        }

        string memory body = "[";
        uint256 last = _beneficiaries.length - 1;
        for (uint256 i; i < _beneficiaries.length; i++) {
            body = string.concat(body, serializedBeneficiaries[i], i == last ? "" : ",");
        }

        // Append opening and closing brackets
        vm.writeJson(string.concat(body, "]"), DEPLOYMENT_FILENAME);
    }

    // ============ Logging
    function _logBeneficiary(ConfiguredBeneficiary memory _beneficiary) internal view {
        console.log("- beneficiary  ", _beneficiary.beneficiary);
        console.log("- amount       ", _beneficiary.amount);
        console.log("- startTime    ", _beneficiary.startTime);
        console.log("- cliffDuration", _beneficiary.cliffDuration);
        console.log("- duration     ", _beneficiary.duration);
    }

    function _logTimelock(address _timelock) internal view {
        TimelockedDelegator timelock = TimelockedDelegator(_timelock);
        console.log("- timelock     ", address(timelock));
        console.log("- clawbackAdmin", timelock.clawbackAdmin());
        console.log("- token        ", address(timelock.token()));
        console.log("- totalToken   ", timelock.totalToken());
        console.log("- beneficiary  ", timelock.beneficiary());
        console.log("- startTime    ", timelock.startTime());
        console.log("- cliffSeconds ", timelock.cliffSeconds());
    }
}
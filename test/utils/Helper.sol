// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ERC20Votes, ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract MintableERC20 is ERC20, ERC20Votes {
    // ============ Constructor ============
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) ERC20Permit(name_) {
    }
    
    // ============ Public ============

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // ============ Private ============

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}

abstract contract TimelockHelper is Test {
    // ============ Libraries ============
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    // ============ Events ============
    event Release(address indexed _beneficiary, address indexed _recipient, uint256 _amount);
    event BeneficiaryUpdate(address indexed _beneficiary);
    event PendingBeneficiaryUpdate(address indexed _pendingBeneficiary);
    event Delegate(address indexed _delegatee, uint256 _amount);
    event Undelegate(address indexed _delegatee, uint256 _amount);
    
    event Transfer(address indexed from, address indexed to, uint256 value);

    // ============ Storage ============
    MintableERC20 public _token;

    // Default timelock parameters
    address public _beneficiary = address(0xbbbb);
    address public _clawbackAdmin = address(0xcccc);
    uint256 public _cliffDuration = 365 days;
    uint256 public _startTime = block.timestamp;
    uint256 public _duration = 4 * _cliffDuration;
    
    uint256 public _allocation = 11235 ether;

    // ============ Constructor ============
    constructor() {}

    // ============ Private ============

    function _setToken(address token_) internal {
        _token = MintableERC20(token_);
    }

    function _resetToken() internal {
        _token = new MintableERC20("Mintable ERC20", "MINT");
    }
}

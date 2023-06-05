// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "@openzeppelin/utils/Strings.sol";

/**
 * @notice This contract contains helpers for the custodian / claim. Specifically, it contains:
 * - connext address
 * - tree
 * - leaves
 * 
 * @dev Tree and leaves were generated using a modification of: 
 *    https://github.com/OpenZeppelin/merkle-tree
 */

contract MockConnext {
    event XCalled(
        uint32 destination,
        address to,
        address asset,
        address delegate,
        uint256 amount,
        uint256 slippage,
        bytes callData
    );
    uint32 private _domain;
    constructor(uint32 domain_) {
        setDomain(domain_);
    }

    function domain() public view returns (uint32) {
        return _domain;
    }

    function setDomain(uint32 domain_) public {
        _domain = domain_;
    }

    function xcall(
        uint32 _destination,
        address _to,
        address _asset,
        address _delegate,
        uint256 _amount,
        uint256 _slippage,
        bytes calldata _callData
    ) public returns (bytes32) {
        emit XCalled(_destination, _to, _asset, _delegate, _amount, _slippage, _callData);
        return keccak256(abi.encode(_destination, _to, _asset, _delegate, _amount, _slippage, _callData));
    }
}

contract Helper is Test {
    // ========== Libraries ===========

    using stdJson for string;
    using Strings for uint256;

    // ========== Events ===========
    // emitted by MockConnext
    event XCalled(
        uint32 destination,
        address to,
        address asset,
        address delegate,
        uint256 amount,
        uint256 slippage,
        bytes callData
    );

    // ========== Storage ===========
    address _connext;
    
    bytes32 _root;

    address _claimant;
    uint32 _domain;
    uint256 _amount;
    bytes32[] _proof;

    mapping(address => uint256) _claimantKeys;

    // ========== Utilities ===========
    function _loadConnext(uint32 domain_) internal {
        // Make sure that connext returns domain
        _connext = address(new MockConnext(domain_ == 0 ? 9991 : domain_));
    }
    function _loadConnext() internal {
        _loadConnext(0);
    }

    function _loadJson() internal view returns (string memory) {
        // get file path
        string memory root = vm.projectRoot();

        string memory path = string.concat(root, "/test/tree.json");

        // read the json
        string memory json = vm.readFile(path);
        return json;
    }


    function _loadRoot() internal {
        string memory json = _loadJson();

        // set the root
        _root = json.readBytes32(".root");
    }

    function _loadLeaf() internal {
        _loadLeaf(1);
    }
    function _loadLeaf(uint256 index) internal {
        (_claimant, _domain, _amount) = _getLeaf(index);
    }
    function _getLeaf(uint256 index) internal returns (address, uint32, uint256) {
        // load json
        string memory json = _loadJson();

        // check the index is reasonable
        uint256 size = json.readUint(".size");
        require(index < size, "index out of bounds");

        // capture the leaf
        address claimant = json.readAddress(string.concat(".leaves[", index.toString(), "].value[0]"));
        uint32 domain = uint32(json.readUint(string.concat(".leaves[", index.toString(), "].value[1]")));
        uint256 amount = json.readUint(string.concat(".leaves[", index.toString(), "].value[2]"));

        // decode
        return (claimant, domain, amount);
    }

    function _loadClaimants() internal {
        // load json
        string memory json = _loadJson();

        address[] memory claimants = json.readAddressArray(".claimants");
        uint256[] memory keys = json.readUintArray(".keys");

        for (uint256 i; i < claimants.length; i++) {
            _claimantKeys[claimants[i]] = keys[i];
        }
    }

    function _loadProof() internal {
        _loadProof(1);
    }
    function _loadProof(uint256 index) internal {
        _proof = _getProof(index);
    }
    function _getProof(uint256 index) internal returns (bytes32[] memory) {
        // load json
        string memory json = _loadJson();

        // check the index is reasonable
        uint256 size = json.readUint(".size");
        require(index < size, "index out of bounds");

        // capture the proof
        bytes32[] memory proof = json.readBytes32Array(string.concat(".proofs[", index.toString(), "]"));

        // return decoded value
        return proof;
    }
}


// Script used to generate tree:

// import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
// import { Wallet } from "ethers";
// import { parseEther } from "ethers/lib/utils";

// import { writeFileSync } from "fs";

// // (1) address-domain-amount
// const allocations = 50;
// const wallets = Array(allocations).fill(0).map(_ => Wallet.createRandom());
// const amounts = Array(allocations).fill(0).map(_ => parseEther(Math.floor(Math.random() * 10).toString()).toString());
// // [mumbai, goerli, opt-goerli, arb-goerli, zksync, linea, polygon zkevm]
// const domains = [9991, 1735353714, 1735356532, 1734439522, 2053862260, 1668247156, 1887071092];

// // leaves should include some duplicates with different chains
// const leaves: [string, number, string][] = wallets.map((wallet, index) => {
//     const domain = domains[Math.floor(Math.random() * domains.length)];
//     return [wallet.address, domain, amounts[index]];
// });

// // Add in some duplicate addresses with different domains
// const getDifferentDomain = (leaf: [string, number, string]): number => {
//     const domain = domains[Math.floor(Math.random() * domains.length)];
//     return domain === leaf[1] ? getDifferentDomain(leaf) : domain;
// };
// Array(10).fill(0).forEach((_, idx) => {
//     leaves.push([leaves[idx][0], getDifferentDomain(leaves[idx]), leaves[idx][2]]);
// });

// // (2)
// const tree = StandardMerkleTree.of(leaves, ["address", "uint32", "uint256"]);

// // (3)
// console.log('Merkle Root:', tree.root);

// // (4)
// const { tree: recorded, values } = tree.dump();
// const output = {
//     root: tree.root,
//     size: values.length,
//     leaves: values,
//     proofs: values.map((leaf) => tree.getProof(leaf.value)),
//     tree: recorded,
//     claimants: wallets.map(w => w.address),
//     keys: wallets.map(w => w.privateKey),
// };

// // test -- can verify leaves with proof
// const provable = output.leaves.every((leaf, index) => {
//     return tree.verify(leaf.value, output.proofs[index]);
// });
// if (!provable) {
//     throw new Error(`Invalid proof for leaf ${JSON.stringify(output.leaves)}`);
// }

// writeFileSync("tree.json", JSON.stringify(output));
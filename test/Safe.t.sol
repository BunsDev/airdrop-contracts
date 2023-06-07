// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./Helper.sol";

abstract contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

interface ISafe {
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external returns (bool);

    function checkSignatures(bytes32 dataHash, bytes memory data, bytes memory signatures) external view;

    function getOwners() external view returns (address[] memory);
}

contract ClaimerTest is Helper {

    ISafe safe = ISafe(0x6eCeD04DdC5A7709d5877c963cED0288Fb1c7348);

    function setUp() public {}

    function test_test() public {
        // Log owners
        {
            address[] memory owners = safe.getOwners();
            console.log("owners:");
            for (uint256 i = 0; i < owners.length; i++) {
                console.log(i, ": ",owners[i]);
            }
        }

        bool success;
        // {
        //     // Tx data from: https://optimistic.etherscan.io/tx/0x4c6916b901b534ead0df3d6baeeb354c074ebf48c94c8caeccc747f76e45b551
        //     bytes memory signatures = bytes("0xf8177ae5265247fe9c0a1dc6faa4e19359e7c4316d10cd6d85708431ddf78d4b4d301775d4323ff059ab19f38033c0029707775af0c95e09dcd2c1086c235e021c6a11592fab05244527a42ea63daf72c8fd5889d70fd825b6664a6cc82eaebffd7ed56c0ef2c480e3963258a486969e698aa0aed6ffac36e178e13faeb45961e01c9acfb5c75a827301e086f3c334a243329b0914a1460ce03b58dc5fd2cf50cdf437dbb246778eefd7459d6bed3c94847b5d93641bf7e7ab012afe257a615adc151b");
        //     // address payable refundReceiver;
        //     // address gasToken;
        //     // uint256 gasPrice;
        //     // uint256 baseGas;
        //     // uint256 safeTxGas;
        //     Enum.Operation operation;
        //     bytes memory data;
        //     address to = address(0x6eCeD04DdC5A7709d5877c963cED0288Fb1c7348);
        //     success = safe.execTransaction(to, 0, data, operation, 0, 0, 0, address(0), payable(address(0)), signatures);
        // }

        // // Tx data from: https://dashboard.tenderly.co/lhaber/project/simulator/be514fb6-0269-40b5-a8e6-bb352a5f5f57/debugger?trace=0
        // bytes memory data = bytes("0x6a7612020000000000000000000000006eced04ddc5a7709d5877c963ced0288fb1c7348000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3f8177ae5265247fe9c0a1dc6faa4e19359e7c4316d10cd6d85708431ddf78d4b4d301775d4323ff059ab19f38033c0029707775af0c95e09dcd2c1086c235e021c6a11592fab05244527a42ea63daf72c8fd5889d70fd825b6664a6cc82eaebffd7ed56c0ef2c480e3963258a486969e698aa0aed6ffac36e178e13faeb45961e01c9acfb5c75a827301e086f3c334a243329b0914a1460ce03b58dc5fd2cf50cdf437dbb246778eefd7459d6bed3c94847b5d93641bf7e7ab012afe257a615adc151b0000000000000000000000000000000000000000000000000000000000");
        // (success,) = address(safe).call(data);

        bytes32 dataHash = bytes32(0x398318753774292071343f056a6abf867e25083ff7557112bd65986181aa2cac);
        bytes memory data = bytes("1901fff8122097261d8e52f4b768c4b764a3673e5779682c9d374dae4f64dec5a460e6a2fdca2a047c24769692c85664c4e68ebe68c90d7f053bdfa049c7971486a7");
        bytes memory signatures = bytes("f8177ae5265247fe9c0a1dc6faa4e19359e7c4316d10cd6d85708431ddf78d4b4d301775d4323ff059ab19f38033c0029707775af0c95e09dcd2c1086c235e021c6a11592fab05244527a42ea63daf72c8fd5889d70fd825b6664a6cc82eaebffd7ed56c0ef2c480e3963258a486969e698aa0aed6ffac36e178e13faeb45961e01c9acfb5c75a827301e086f3c334a243329b0914a1460ce03b58dc5fd2cf50cdf437dbb246778eefd7459d6bed3c94847b5d93641bf7e7ab012afe257a615adc151b");
        safe.checkSignatures(dataHash, data, signatures);



        console.log("success: ", success);
        require(success, "failed");
    }
}
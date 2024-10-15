// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/src/Test.sol";
import "forge-std/src/Script.sol";

import "src/ccip/Adapter.sol";

import {LaPoste} from "src/LaPoste.sol";
import {Token} from "src/Token.sol";
import {TokenFactory} from "src/TokenFactory.sol";

interface IImmutableFactory {
    function deployCreate3(bytes32 salt, bytes memory initializationCode) external payable returns (address);
}

contract Deploy is Script {
    address public deployer = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;

    address public constant FACTORY = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    address public laPoste;
    address public adapter;
    address public tokenFactory;

    string[] public chains = ["base", "optimism", "arbitrum"];
    address[] public ccipRouters = [
        0x881e3A65B4d4a04dD529061dd0071cf975F58bCD,
        0x3206695CaE29952f4b0c22a169725a865bc8Ce0f,
        0x141fa059441E0ca23ce184B6A78bafD2A517DdE8
    ];

    function run() public {
        uint256 _random = 9876;

        for (uint256 i = 0; i < chains.length; i++) {
            string memory chain = chains[i];
            address ccipRouter = ccipRouters[i];
            vm.createSelectFork(chain);
            vm.startBroadcast(deployer);

            bytes32 salt = keccak256(abi.encode(deployer, _random));

            /// 1. Deploy the GaugeManager.
            tokenFactory = IImmutableFactory(FACTORY).deployCreate3(
                salt, abi.encodePacked(type(TokenFactory).creationCode, abi.encode(deployer))
            );

            salt = keccak256(abi.encode(deployer, _random + 1));

            /// 2. Deploy the LaPoste.
            laPoste = IImmutableFactory(FACTORY).deployCreate3(
                salt, abi.encodePacked(type(LaPoste).creationCode, abi.encode(tokenFactory, deployer))
            );

            /// 3. Set the minter.
            TokenFactory(tokenFactory).setMinter(laPoste);

            salt = keccak256(abi.encode(deployer, _random + 2));

            /// 4. Deploy the Adapter.
            adapter = IImmutableFactory(FACTORY).deployCreate3(
                salt, abi.encodePacked(type(Adapter).creationCode, abi.encode(laPoste, ccipRouter, 500_000))
            );

            /// 5. Set the adapter.
            LaPoste(laPoste).setAdapter(address(adapter));

            vm.stopBroadcast();
        }
    }
}

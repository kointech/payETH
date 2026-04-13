// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Krypto Capital LLC (Koinon). All rights reserved.
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {PAYEToken} from "../src/PAYEToken.sol";

/**
 * @title  DeployRemote
 * @notice Deploys PAYEToken on a REMOTE chain (e.g. Linea Mainnet).
 *         No tokens are minted here; supply arrives exclusively via the LayerZero bridge.
 *
 * @dev    Required environment variables:
 *           DEPLOYER_PRIVATE_KEY   — private key of the deployer account
 *           TREASURY_ADDRESS       — Koinon-controlled wallet (becomes owner/delegate)
 *           LZ_ENDPOINT_ADDRESS    — LayerZero EndpointV2 address on this chain
 *                                    Linea Mainnet:  0x1a44076050125825900e736c501f859c50fE728c
 *                                    Linea Sepolia:  0x6EDCE65403992e310A62460808c4b910D972f10f
 *
 * @dev    After deployment, run WirePeers.s.sol on BOTH chains to link this contract
 *         with the home-chain deployment before any bridging can occur.
 *
 * Usage:
 *   forge script script/DeployRemote.s.sol \
 *     --rpc-url $LINEA_RPC_URL \
 *     --broadcast \
 *     --verify \
 *     --verifier blockscout \
 *     --verifier-url https://api.lineascan.build/api
 */
contract DeployRemote is Script {
    function run() external {
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_ADDRESS");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        require(treasury != address(0), "DeployRemote: zero treasury");
        require(lzEndpoint != address(0), "DeployRemote: zero endpoint");

        vm.startBroadcast(deployerKey);

        // initialSupply = 0 on remote chains — supply is bridged in, never freshly minted
        PAYEToken paye = new PAYEToken(lzEndpoint, treasury, 0);

        vm.stopBroadcast();

        console2.log("=== PAYE Remote Deployment ===");
        console2.log("Contract   :", address(paye));
        console2.log("Treasury   :", treasury);
        console2.log("isHomeChain:", paye.IS_HOME_CHAIN());
        console2.log("Decimals   :", paye.decimals());
        console2.log(
            "NOTE: Run WirePeers.s.sol to link with home-chain deployment."
        );
    }
}

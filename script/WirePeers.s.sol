// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Krypto Capital LLC (Koinon). All rights reserved.
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {PAYEToken} from "../src/PAYEToken.sol";

/**
 * @title  WirePeers
 * @notice Calls setPeer() on a deployed PAYEToken to register the matching OFT
 *         contract on a peer chain.  Must be run by the contract owner (treasury).
 *
 * @dev    This script runs on a SINGLE chain at a time.  Run it once for each
 *         direction of the bridge (e.g. Ethereum → Linea, then Linea → Ethereum).
 *
 *         Required environment variables:
 *           OWNER_PRIVATE_KEY    — private key of the contract owner (treasury)
 *           LOCAL_PAYE_ADDRESS   — address of PAYEToken on THIS chain
 *           REMOTE_EID           — LayerZero endpoint ID of the PEER chain
 *           REMOTE_PAYE_ADDRESS  — address of PAYEToken on the PEER chain
 *
 *         LayerZero Endpoint IDs (EIDs):
 *           Ethereum Mainnet : 30101
 *           Linea Mainnet    : 30183
 *           Ethereum Sepolia : 40161
 *           Linea Sepolia    : 40287
 *
 * Usage (Ethereum side):
 *   forge script script/WirePeers.s.sol \
 *     --rpc-url $ETH_RPC_URL \
 *     --broadcast
 *
 * Usage (Linea side):
 *   forge script script/WirePeers.s.sol \
 *     --rpc-url $LINEA_RPC_URL \
 *     --broadcast
 */
contract WirePeers is Script {
    function run() external {
        address localPaye = vm.envAddress("LOCAL_PAYE_ADDRESS");
        uint32 remoteEid = uint32(vm.envUint("REMOTE_EID"));
        address remotePaye = vm.envAddress("REMOTE_PAYE_ADDRESS");
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");

        require(localPaye != address(0), "WirePeers: zero local");
        require(remotePaye != address(0), "WirePeers: zero remote");
        require(remoteEid != 0, "WirePeers: zero eid");

        // LayerZero peers are stored as bytes32 (accommodates non-EVM addresses like Solana)
        bytes32 peerBytes32 = bytes32(uint256(uint160(remotePaye)));

        vm.startBroadcast(ownerKey);

        PAYEToken(localPaye).setPeer(remoteEid, peerBytes32);

        vm.stopBroadcast();

        console2.log("=== WirePeers ===");
        console2.log("Local PAYE  :", localPaye);
        console2.log("Remote EID  :", remoteEid);
        console2.log("Remote PAYE :", remotePaye);
        console2.log("Peer bytes32:", vm.toString(peerBytes32));
        console2.log("Peer set successfully.");
    }
}

// SPDX-License-Identifier: UNLICENSED
//
// PAYE / PayETH — Omnichain Fungible Token (LayerZero OFT v2)
// Issued by a United States Entity (US Virgin Islands)
// ─────────────────────────────────────────────────────────────────────────────
// Beneficially owned 100% by Matthew Mecke and/or assigns.
// Held and issued through Krypto Capital LLC, a US Virgin Islands registered
// company (interim holding entity), pending establishment of a successor USVI
// holding company.  All rights, title, and interest in this code, the PAYE
// token, and all related intellectual property vest solely in Matthew Mecke
// and/or his designated assigns or successor entities.
//
// IP © 2025–2026 Matthew Mecke / Krypto Capital LLC (Koinon). All rights reserved.
//
// This code was developed under instruction from Matthew Mecke commencing
// December 1, 2025.  At that time the beneficial owner advised that the final
// corporate ownership structure was yet to be established; Krypto Capital LLC
// is therefore named as the interim issuing entity.  Any successor USVI entity
// established by Matthew Mecke shall automatically succeed to all rights herein
// by corporate IP assignment without affecting the validity of this notice.
//
// No licence to reproduce, distribute, or create derivative works is granted
// without prior written consent of the beneficial owner.
// Security researchers may read and test this code for bug-finding purposes only.
// ─────────────────────────────────────────────────────────────────────────────
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PAYEToken} from "../src/PAYEToken.sol";

/**
 * @title  WirePeers
 * @notice Calls setPeer() on a deployed PAYEToken to register the matching OFT
 *         contract on a peer chain.  Must be run by the contract owner (treasury).
 *
 * @dev    This script runs on a SINGLE chain at a time.  Run it once for each
 *         direction of the bridge (e.g. Linea → Base, then Base → Linea).
 *
 *         Required environment variables:
 *           LOCAL_PAYE_ADDRESS   — address of PAYEToken on THIS chain
 *           REMOTE_EID           — LayerZero endpoint ID of the PEER chain
 *           REMOTE_PAYE_ADDRESS  — address of PAYEToken on the PEER chain (EVM chains only)
 *           REMOTE_PEER_BYTES32  — raw bytes32 peer (non-EVM chains, e.g. Solana).
 *                                  When set, takes precedence over REMOTE_PAYE_ADDRESS.
 *
 *         LayerZero Endpoint IDs (EIDs):
 *           Ethereum Mainnet : 30101
 *           Linea Mainnet    : 30183
 *           Solana Mainnet   : 30168
 *           Ethereum Sepolia : 40161
 *           Base Sepolia     : 40287
 *           Solana Devnet    : 40168
 *
 * Usage (Linea side — home chain):
 *   forge script script/WirePeers.s.sol \
 *     --rpc-url $LINEA_RPC_URL \
 *     --account deployer \
 *     --broadcast
 *
 * Usage (remote chain side):
 *   forge script script/WirePeers.s.sol \
 *     --rpc-url $LINEA_RPC_URL \
 *     --account deployer \
 *     --broadcast
 */
contract WirePeers is Script {
    function run() external {
        address localPaye = vm.envAddress("LOCAL_PAYE_ADDRESS");
        uint32 remoteEid = uint32(vm.envUint("REMOTE_EID"));

        require(localPaye != address(0), "WirePeers: zero local");
        require(remoteEid != 0, "WirePeers: zero eid");

        // Prefer REMOTE_PEER_BYTES32 for non-EVM chains (e.g. Solana).
        // Fall back to REMOTE_PAYE_ADDRESS (EVM address → bytes32) otherwise.
        bytes32 peerBytes32;
        bytes memory rawBytes32 = vm.envOr("REMOTE_PEER_BYTES32", bytes(""));
        if (rawBytes32.length > 0) {
            peerBytes32 = vm.envBytes32("REMOTE_PEER_BYTES32");
        } else {
            address remotePaye = vm.envAddress("REMOTE_PAYE_ADDRESS");
            require(remotePaye != address(0), "WirePeers: zero remote");
            peerBytes32 = bytes32(uint256(uint160(remotePaye)));
        }

        vm.startBroadcast();

        PAYEToken(payable(localPaye)).setPeer(remoteEid, peerBytes32);

        vm.stopBroadcast();

        console2.log("=== WirePeers ===");
        console2.log("Local PAYE  :", localPaye);
        console2.log("Remote EID  :", remoteEid);
        console2.log("Peer bytes32:", vm.toString(peerBytes32));
        console2.log("Peer set successfully.");
    }
}

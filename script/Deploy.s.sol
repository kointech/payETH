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
 * @title  Deploy
 * @notice Unified deployment script for PAYEToken on any chain.
 *
 * @dev    Required environment variables (set in .env):
 *           TREASURY_ADDRESS    — Koinon-controlled wallet (receives supply on home, owner everywhere)
 *           LZ_ENDPOINT_ADDRESS — LayerZero EndpointV2 address on the target chain
 *           IS_HOME             — "true" for the home chain (mints full supply), "false" for remote chains
 *
 * Usage:
 *   # Home chain — Linea (mints 125 M PAYE to treasury):
 *   IS_HOME=true  forge script script/Deploy.s.sol --rpc-url $RPC_URL --account deployer --broadcast --verify --etherscan-api-key $VERIFY_KEY
 *
 *   # Remote chain — Base, Solana, etc. (no mint; supply arrives via bridge):
 *   IS_HOME=false forge script script/Deploy.s.sol --rpc-url $RPC_URL --account deployer --broadcast --verify --etherscan-api-key $VERIFY_KEY
 */
contract Deploy is Script {
    /// 125,000,000 tokens with 18 decimal places
    uint256 public constant TOTAL_SUPPLY = 125_000_000 * 10 ** 18;

    function run() external {
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_ADDRESS");
        bool isHome = vm.envBool("IS_HOME");

        require(treasury != address(0), "Deploy: zero treasury");
        require(lzEndpoint != address(0), "Deploy: zero endpoint");

        uint256 initialSupply = isHome ? TOTAL_SUPPLY : 0;

        vm.startBroadcast();

        PAYEToken paye = new PAYEToken(
            lzEndpoint,
            treasury,
            initialSupply,
            isHome
        );

        vm.stopBroadcast();

        console2.log("=== PAYE Deployment ===");
        console2.log("Contract   :", address(paye));
        console2.log("Treasury   :", treasury);
        console2.log("Developer  :", msg.sender);
        console2.log("isHomeChain:", paye.isHomeChain());
        if (isHome) console2.log("Supply     :", TOTAL_SUPPLY);
        console2.log("Owner      :", paye.owner());
        console2.log("Decimals   :", paye.decimals());
        console2.log(
            "NOTE: Run WirePeers.s.sol on both chains to link peers before bridging."
        );
    }
}

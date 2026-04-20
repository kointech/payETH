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
// ─────────────────────────────────────────────────────────────────────────────
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PAYEToken} from "../src/PAYEToken.sol";

/**
 * @title  DeployHome
 * @notice Deploys PAYEToken on the HOME chain (Ethereum Mainnet).
 *         Mints the full 125,000,000 PAYE supply to the Koinon treasury wallet.
 *
 * @dev    Required environment variables (set in .env or via --env-file):
 *           TREASURY_ADDRESS       — Koinon-controlled wallet to receive all minted PAYE
 *           LZ_ENDPOINT_ADDRESS    — LayerZero EndpointV2 address on Ethereum
 *                                    Mainnet:  0x1a44076050125825900e736c501f859c50fE728c
 *                                    Sepolia:  0x6EDCE65403992e310A62460808c4b910D972f10f
 *
 * Usage:
 *   forge script script/DeployHome.s.sol \
 *     --rpc-url $ETH_RPC_URL \
 *     --account deployer \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployHome is Script {
    /// 125,000,000 tokens with 4 decimal places = 1,250,000,000,000 base units
    uint256 public constant TOTAL_SUPPLY = 125_000_000 * 10 ** 4;

    function run() external {
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_ADDRESS");

        require(treasury != address(0), "DeployHome: zero treasury");
        require(lzEndpoint != address(0), "DeployHome: zero endpoint");

        vm.startBroadcast();

        PAYEToken paye = new PAYEToken(lzEndpoint, treasury, TOTAL_SUPPLY);

        vm.stopBroadcast();

        console2.log("=== PAYE Home Deployment ===");
        console2.log("Contract  :", address(paye));
        console2.log("Treasury  :", treasury);
        console2.log("Supply    :", TOTAL_SUPPLY);
        console2.log("Owner     :", paye.owner());
        console2.log("isHomeChain:", paye.isHomeChain());
        console2.log("Decimals  :", paye.decimals());
    }
}

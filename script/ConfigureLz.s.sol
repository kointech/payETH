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
// ─────────────────────────────────────────────────────────────────────────────
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PAYEToken} from "../src/PAYEToken.sol";
import {
    SetConfigParam
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

// ─── LZ config type constants ─────────────────────────────────────────────────
// CONFIG_TYPE_EXECUTOR (1): abi.encode(ExecutorConfig) — send-lib only.
// CONFIG_TYPE_ULN      (2): abi.encode(UlnConfig)      — send-lib AND receive-lib.
uint32 constant CONFIG_TYPE_EXECUTOR = 1;
uint32 constant CONFIG_TYPE_ULN = 2;

// ─── LZ messagelib structs (mirrors SendLibBase.sol / UlnBase.sol) ────────────
// These must match the ABI layout used inside the message library contracts.
// The encoded bytes are passed verbatim to the endpoint's setConfig call.

struct ExecutorConfig {
    uint32 maxMessageSize;
    address executor;
}

struct UlnConfig {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

/**
 * @title  ConfigureLz
 * @notice Sets peer address + full LayerZero library configuration (executor, send ULN,
 *         receive ULN) on a deployed PAYEToken for a single remote endpoint.
 *
 * @dev    Run *after* DeployHome / DeployRemote.  Must be called by the developer
 *         wallet (msg.sender from the `--account` flag) because PAYEToken.setLzConfig()
 *         is gated by `onlyOwnerOrDeveloper`.
 *
 *         Run once per EVM chain.  The script auto-detects the current chain via
 *         `block.chainid` and loads the corresponding hardcoded LZ infrastructure
 *         addresses (SendUln302, ReceiveUln302, LZ Executor, LZ Labs DVN).
 *
 *         Infrastructure addresses were sourced from the LayerZero metadata API:
 *           https://metadata.layerzero-api.com/v1/metadata
 *           https://metadata.layerzero-api.com/v1/metadata/dvns
 *         and cross-referenced against https://docs.layerzero.network/v2/deployments/deployed-contracts
 *
 * ─── Required environment variables ──────────────────────────────────────────
 *   LOCAL_PAYE_ADDRESS   — address of PAYEToken on THIS chain
 *   SOLANA_PAYE_PEER     — bytes32 peer address of the Solana PAYE OFT program
 *                          (the OFT store PDA, left-padded to 32 bytes)
 *
 * ─── LayerZero EIDs ──────────────────────────────────────────────────────────
 *   Mainnet chains (30xxx):
 *     Ethereum  : 30101   (chain ID 1)
 *     Linea     : 30183   (chain ID 59144)
 *     Base      : 30184   (chain ID 8453)
 *     Solana    : 30168
 *
 *   Testnet chains (40xxx):
 *     Eth Sepolia  : 40161   (chain ID 11155111)
 *     Base Sepolia : 40245   (chain ID 84532)
 *     Linea Sepolia: 40287   (chain ID 59141)
 *     Solana Devnet: 40168
 *
 * ─── Usage ────────────────────────────────────────────────────────────────────
 *   # Ethereum mainnet — developer wallet signs
 *   forge script script/ConfigureLz.s.sol \
 *     --rpc-url $ETH_RPC_URL \
 *     --account developer \
 *     --broadcast
 *
 *   # Base Sepolia testnet
 *   forge script script/ConfigureLz.s.sol \
 *     --rpc-url $BASE_SEPOLIA_RPC_URL \
 *     --account developer \
 *     --broadcast
 */
contract ConfigureLz is Script {
    // ─── Chain configuration ──────────────────────────────────────────────────

    struct ChainConfig {
        address sendUln302;
        address receiveUln302;
        address executor; // LZ Executor contract on this chain
        address dvn; // LZ Labs DVN on this chain
        uint32 remoteEid; // Solana EID for this environment
        uint64 confirmations; // Block confirmations required on both sides
    }

    // ─── Run ─────────────────────────────────────────────────────────────────

    function run() external {
        address localPaye = vm.envAddress("LOCAL_PAYE_ADDRESS");
        bytes32 solanaPeer = vm.envBytes32("SOLANA_PAYE_PEER");

        require(localPaye != address(0), "ConfigureLz: zero local paye");
        require(solanaPeer != bytes32(0), "ConfigureLz: zero solana peer");

        ChainConfig memory cfg = _getChainConfig();

        // ── Build config param arrays ────────────────────────────────────────

        // Executor config (send lib only — instructs executor on outbound messages)
        SetConfigParam[] memory execParams = new SetConfigParam[](1);
        execParams[0] = SetConfigParam({
            eid: cfg.remoteEid,
            configType: CONFIG_TYPE_EXECUTOR,
            config: abi.encode(
                ExecutorConfig({maxMessageSize: 10_000, executor: cfg.executor})
            )
        });

        // ULN config — same struct for both send and receive libs
        address[] memory dvns = new address[](1);
        dvns[0] = cfg.dvn;
        bytes memory ulnBytes = abi.encode(
            UlnConfig({
                confirmations: cfg.confirmations,
                requiredDVNCount: 1,
                optionalDVNCount: 0,
                optionalDVNThreshold: 0,
                requiredDVNs: dvns,
                optionalDVNs: new address[](0)
            })
        );

        SetConfigParam[] memory sendUlnParams = new SetConfigParam[](1);
        sendUlnParams[0] = SetConfigParam({
            eid: cfg.remoteEid,
            configType: CONFIG_TYPE_ULN,
            config: ulnBytes
        });

        SetConfigParam[] memory recvUlnParams = new SetConfigParam[](1);
        recvUlnParams[0] = SetConfigParam({
            eid: cfg.remoteEid,
            configType: CONFIG_TYPE_ULN,
            config: ulnBytes
        });

        // ── Broadcast ────────────────────────────────────────────────────────

        vm.startBroadcast();

        PAYEToken paye = PAYEToken(payable(localPaye));

        // 1. Register Solana peer
        paye.setPeer(cfg.remoteEid, solanaPeer);

        // 2. Executor config (applies to outbound messages only — send lib)
        paye.setLzConfig(cfg.sendUln302, execParams);

        // 3. Send ULN config (DVN + confirmations for outbound messages)
        paye.setLzConfig(cfg.sendUln302, sendUlnParams);

        // 4. Receive ULN config (DVN + confirmations for inbound messages from Solana)
        paye.setLzConfig(cfg.receiveUln302, recvUlnParams);

        vm.stopBroadcast();

        // ── Log ───────────────────────────────────────────────────────────────

        console2.log("=== ConfigureLz ===");
        console2.log("Chain ID        :", block.chainid);
        console2.log("Local PAYE      :", localPaye);
        console2.log("Remote EID      :", cfg.remoteEid);
        console2.log("Solana peer     :", vm.toString(solanaPeer));
        console2.log("Confirmations   :", cfg.confirmations);
        console2.log("LZ DVN          :", cfg.dvn);
        console2.log("LZ Executor     :", cfg.executor);
        console2.log("SendUln302      :", cfg.sendUln302);
        console2.log("ReceiveUln302   :", cfg.receiveUln302);
        console2.log(
            "Done: setPeer + executor + send ULN + receive ULN configured."
        );
    }

    // ─── Chain config lookup ──────────────────────────────────────────────────

    function _getChainConfig() internal view returns (ChainConfig memory cfg) {
        uint256 id = block.chainid;

        // ── Mainnet ──────────────────────────────────────────────────────────
        if (id == 1) {
            // Ethereum mainnet  (EID 30101)
            cfg.sendUln302 = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
            cfg.receiveUln302 = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
            cfg.executor = 0x173272739Bd7Aa6e4e214714048a9fE699453059;
            cfg.dvn = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
            cfg.remoteEid = 30168; // Solana mainnet
            cfg.confirmations = 15;
        } else if (id == 59144) {
            // Linea mainnet  (EID 30183)
            cfg.sendUln302 = 0x32042142DD551b4EbE17B6FEd53131dd4b4eEa06;
            cfg.receiveUln302 = 0xE22ED54177CE1148C557de74E4873619e6c6b205;
            cfg.executor = 0x0408804C5dcD9796F22558464E6fE5bDdF16A7c7;
            cfg.dvn = 0x129Ee430Cb2Ff2708CCADDBDb408a88Fe4FFd480;
            cfg.remoteEid = 30168; // Solana mainnet
            cfg.confirmations = 15;
        } else if (id == 8453) {
            // Base mainnet  (EID 30184)
            cfg.sendUln302 = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
            cfg.receiveUln302 = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
            cfg.executor = 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
            cfg.dvn = 0x9e059a54699a285714207b43B055483E78FAac25;
            cfg.remoteEid = 30168; // Solana mainnet
            cfg.confirmations = 15;

            // ── Testnet ───────────────────────────────────────────────────────────
        } else if (id == 11155111) {
            // Ethereum Sepolia  (EID 40161)
            cfg.sendUln302 = 0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE;
            cfg.receiveUln302 = 0xdAf00F5eE2158dD58E0d3857851c432E34A3A851;
            cfg.executor = 0x718B92b5CB0a5552039B593faF724D182A881eDA;
            cfg.dvn = 0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193;
            cfg.remoteEid = 40168; // Solana Devnet
            cfg.confirmations = 1;
        } else if (id == 84532) {
            // Base Sepolia  (EID 40245)
            cfg.sendUln302 = 0xC1868e054425D378095A003EcbA3823a5D0135C9;
            cfg.receiveUln302 = 0x12523de19dc41c91F7d2093E0CFbB76b17012C8d;
            cfg.executor = 0x8A3D588D9f6AC041476b094f97FF94ec30169d3D;
            cfg.dvn = 0xBf6FF58f60606EdF2F190769B951d825Bcb214e2;
            cfg.remoteEid = 40168; // Solana Devnet
            cfg.confirmations = 1;
        } else if (id == 59141) {
            // Linea Sepolia  (EID 40287)
            cfg.sendUln302 = 0x53fd4C4fBBd53F6bC58CaE6704b92dB1f360A648;
            cfg.receiveUln302 = 0x9eCf72299027e8AeFee5DC5351D6d92294F46d2b;
            cfg.executor = 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6;
            cfg.dvn = 0x701f3927871EfcEa1235dB722f9E608aE120d243;
            cfg.remoteEid = 40168; // Solana Devnet
            cfg.confirmations = 1;
        } else {
            revert("ConfigureLz: unsupported chain");
        }
    }
}

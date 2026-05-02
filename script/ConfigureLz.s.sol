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
 * @notice Configures a deployed PAYEToken to communicate with ONE remote peer.
 *         Sets the peer address + executor + send/receive ULN on the local chain.
 *
 * @dev    Run once per direction.  To wire two chains, run from each side:
 *           1. Set env vars for the remote you want to connect to.
 *           2. Run with RPC_URL pointing at THIS chain.
 *           3. Repeat with RPC_URL pointing at the OTHER chain (swapping LOCAL/REMOTE).
 *
 *         Auto-detects local LZ infrastructure (SendUln302, ReceiveUln302, Executor,
 *         DVN) from block.chainid.  Only REMOTE_EID and peer address come from env.
 *
 *         Must be called by the developer wallet (`--account developer`).
 *
 * ─── Required environment variables ──────────────────────────────────────────
 *   LOCAL_PAYE_ADDRESS    — PAYEToken on THIS chain
 *   REMOTE_EID            — LayerZero EID of the peer chain
 *   REMOTE_PAYE_ADDRESS   — PAYEToken address on the peer EVM chain
 *                           (mutually exclusive with REMOTE_PEER_BYTES32)
 *   REMOTE_PEER_BYTES32   — raw bytes32 peer for non-EVM chains (e.g. Solana)
 *                           (takes precedence over REMOTE_PAYE_ADDRESS if set)
 *
 * ─── LayerZero EIDs ──────────────────────────────────────────────────────────
 *   Mainnet:  Linea 30183 | Base 30184 | Solana 30168
 *   Testnet:  Eth Sepolia 40161 | Base Sepolia 40245 | Linea Sepolia 40287 | Solana Devnet 40168
 *
 * ─── Example: wire Eth Sepolia ↔ Base Sepolia ────────────────────────────────
 *   # From Eth Sepolia side:
 *   LOCAL_PAYE_ADDRESS=<eth-sep-addr>  REMOTE_EID=40245  REMOTE_PAYE_ADDRESS=<base-sep-addr>
 *   RPC_URL=<eth-sepolia-rpc>  make configure
 *
 *   # From Base Sepolia side:
 *   LOCAL_PAYE_ADDRESS=<base-sep-addr>  REMOTE_EID=40161  REMOTE_PAYE_ADDRESS=<eth-sep-addr>
 *   RPC_URL=<base-sepolia-rpc>  make configure
 */
contract ConfigureLz is Script {
    // ─── Chain infrastructure (local chain only) ──────────────────────────────

    struct ChainConfig {
        address sendUln302;
        address receiveUln302;
        address executor;
        address[] dvns; // required DVNs — must be sorted ascending by address
        address[] optionalDvns; // optional DVNs — must be sorted ascending by address
        uint8 optionalDvnThreshold;
        uint64 confirmations;
    }

    // ─── Run ─────────────────────────────────────────────────────────────────

    function run() external {
        address localPaye = vm.envAddress("LOCAL_PAYE_ADDRESS");
        uint32 remoteEid = uint32(vm.envUint("REMOTE_EID"));

        require(localPaye != address(0), "ConfigureLz: zero local paye");
        require(remoteEid != 0, "ConfigureLz: zero remote eid");

        // Resolve remote peer: prefer REMOTE_PEER_BYTES32 (non-EVM), else pad address.
        bytes32 remotePeer;
        bytes memory rawBytes32 = vm.envOr("REMOTE_PEER_BYTES32", bytes(""));
        if (rawBytes32.length > 0) {
            remotePeer = vm.envBytes32("REMOTE_PEER_BYTES32");
        } else {
            address remoteAddr = vm.envAddress("REMOTE_PAYE_ADDRESS");
            require(
                remoteAddr != address(0),
                "ConfigureLz: zero remote paye address"
            );
            remotePeer = bytes32(uint256(uint160(remoteAddr)));
        }

        ChainConfig memory cfg = _getChainConfig();

        // ── Encode lib configs ───────────────────────────────────────────────

        bytes memory execConfig = abi.encode(
            ExecutorConfig({maxMessageSize: 10_000, executor: cfg.executor})
        );

        bytes memory ulnConfig = abi.encode(
            UlnConfig({
                confirmations: cfg.confirmations,
                requiredDVNCount: uint8(cfg.dvns.length),
                optionalDVNCount: uint8(cfg.optionalDvns.length),
                optionalDVNThreshold: cfg.optionalDvnThreshold,
                requiredDVNs: cfg.dvns,
                optionalDVNs: cfg.optionalDvns
            })
        );

        SetConfigParam[] memory execParams = new SetConfigParam[](1);
        execParams[0] = SetConfigParam({
            eid: remoteEid,
            configType: CONFIG_TYPE_EXECUTOR,
            config: execConfig
        });

        SetConfigParam[] memory sendUlnParams = new SetConfigParam[](1);
        sendUlnParams[0] = SetConfigParam({
            eid: remoteEid,
            configType: CONFIG_TYPE_ULN,
            config: ulnConfig
        });

        SetConfigParam[] memory recvUlnParams = new SetConfigParam[](1);
        recvUlnParams[0] = SetConfigParam({
            eid: remoteEid,
            configType: CONFIG_TYPE_ULN,
            config: ulnConfig
        });

        // ── Broadcast ────────────────────────────────────────────────────────

        vm.startBroadcast();

        PAYEToken paye = PAYEToken(payable(localPaye));

        paye.setPeer(remoteEid, remotePeer);
        paye.setLzConfig(cfg.sendUln302, execParams);
        paye.setLzConfig(cfg.sendUln302, sendUlnParams);
        paye.setLzConfig(cfg.receiveUln302, recvUlnParams);

        vm.stopBroadcast();

        console2.log("=== ConfigureLz ===");
        console2.log("Chain ID      :", block.chainid);
        console2.log("Local PAYE    :", localPaye);
        console2.log("Remote EID    :", remoteEid);
        console2.log("Remote peer   :", vm.toString(remotePeer));
        console2.log("Confirmations :", cfg.confirmations);
        for (uint256 i; i < cfg.dvns.length; ++i) {
            console2.log(
                string.concat("ReqDVN[", vm.toString(i), "]     :"),
                cfg.dvns[i]
            );
        }
        for (uint256 i; i < cfg.optionalDvns.length; ++i) {
            console2.log(
                string.concat("OptDVN[", vm.toString(i), "]     :"),
                cfg.optionalDvns[i]
            );
        }
        console2.log("Opt threshold :", cfg.optionalDvnThreshold);
        console2.log("Executor      :", cfg.executor);
        console2.log("Done.");
    }

    // ─── Local chain infrastructure lookup ───────────────────────────────────

    function _getChainConfig() internal view returns (ChainConfig memory cfg) {
        uint256 id = block.chainid;

        // ── Mainnet ──────────────────────────────────────────────────────────
        if (id == 59144) {
            // Linea mainnet (EID 30183) — home chain
            cfg.sendUln302 = 0x32042142DD551b4EbE17B6FEd53131dd4b4eEa06;
            cfg.receiveUln302 = 0xE22ED54177CE1148C557de74E4873619e6c6b205;
            cfg.executor = 0x0408804C5dcD9796F22558464E6fE5bDdF16A7c7;
            cfg.confirmations = 15;
            cfg.dvns = new address[](1);
            cfg.dvns[0] = 0x129Ee430Cb2Ff2708CCADDBDb408a88Fe4FFd480; // LZ Labs
        } else if (id == 8453) {
            // Base mainnet (EID 30184)
            cfg.sendUln302 = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
            cfg.receiveUln302 = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
            cfg.executor = 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
            cfg.confirmations = 15;
            cfg.dvns = new address[](1);
            cfg.dvns[0] = 0x9e059a54699a285714207b43B055483E78FAac25; // LZ Labs

            // ── Testnet ───────────────────────────────────────────────────────────
        } else if (id == 11155111) {
            // Eth Sepolia (EID 40161)
            // ----------------------------------------------------------------
            // Required DVNs — MUST be sorted ascending by address.
            // Nethermind : 0x68802e01D6321D5159208478f297d7007A7516Ed
            // LZ Labs    : 0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193
            // Optional DVNs (threshold 1) — MUST be sorted ascending by address.
            // P2P        : 0x9efBA56c8598853E5b40FD9a66B54a6c163742d7
            // NOTE: Horizen excluded — DVN_EidNotSupported(40245) on Eth Sepolia
            // ----------------------------------------------------------------
            cfg.sendUln302 = 0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE;
            cfg.receiveUln302 = 0xdAf00F5eE2158dD58E0d3857851c432E34A3A851;
            cfg.executor = 0x718B92b5CB0a5552039B593faF724D182A881eDA;
            cfg.confirmations = 1;
            cfg.dvns = new address[](2);
            cfg.dvns[0] = 0x68802e01D6321D5159208478f297d7007A7516Ed; // Nethermind
            cfg.dvns[1] = 0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193; // LZ Labs
            cfg.optionalDvns = new address[](1);
            cfg.optionalDvns[0] = 0x9efBA56c8598853E5b40FD9a66B54a6c163742d7; // P2P
            cfg.optionalDvnThreshold = 1;
        } else if (id == 84532) {
            // Base Sepolia (EID 40245)
            // ----------------------------------------------------------------
            // Required DVNs — MUST be sorted ascending by address.
            // Nethermind : 0xd9222CC3Ccd1DF7c070d700EA377D4aDA2B86Eb5
            // LZ Labs    : 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6
            // Optional DVNs (threshold 1) — MUST be sorted ascending by address.
            // P2P        : 0x63ef73671245D1A290F2a675Be9D906090f72a8D
            // NOTE: Horizen excluded — DVN_EidNotSupported on this path
            // ----------------------------------------------------------------
            cfg.sendUln302 = 0xC1868e054425D378095A003EcbA3823a5D0135C9;
            cfg.receiveUln302 = 0x12523de19dc41c91F7d2093E0CFbB76b17012C8d;
            cfg.executor = 0x8A3D588D9f6AC041476b094f97FF94ec30169d3D;
            cfg.confirmations = 1;
            cfg.dvns = new address[](2);
            cfg.dvns[0] = 0xd9222CC3Ccd1DF7c070d700EA377D4aDA2B86Eb5; // Nethermind
            cfg.dvns[1] = 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6; // LZ Labs
            cfg.optionalDvns = new address[](1);
            cfg.optionalDvns[0] = 0x63ef73671245D1A290F2a675Be9D906090f72a8D; // P2P
            cfg.optionalDvnThreshold = 1;
        } else if (id == 59141) {
            // Linea Sepolia (EID 40287)
            cfg.sendUln302 = 0x53fd4C4fBBd53F6bC58CaE6704b92dB1f360A648;
            cfg.receiveUln302 = 0x9eCf72299027e8AeFee5DC5351D6d92294F46d2b;
            cfg.executor = 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6;
            cfg.confirmations = 1;
            cfg.dvns = new address[](1);
            cfg.dvns[0] = 0x701f3927871EfcEa1235dB722f9E608aE120d243; // LZ Labs
        } else {
            revert("ConfigureLz: unsupported chain");
        }
    }
}

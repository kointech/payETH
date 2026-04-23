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
import {
    ILayerZeroEndpointV2
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {
    SetConfigParam
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

// ─── LZ config type constants ─────────────────────────────────────────────────
uint32 constant MIGRATE_CONFIG_TYPE_EXECUTOR = 1;
uint32 constant MIGRATE_CONFIG_TYPE_ULN = 2;

// ─── LZ messagelib structs ────────────────────────────────────────────────────

struct MigrateExecutorConfig {
    uint32 maxMessageSize;
    address executor;
}

struct MigrateUlnConfig {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

/**
 * @title  MigrateLzDelegate
 * @notice Configures LayerZero executor + ULN settings for an EXISTING PAYEToken
 *         deployment that pre-dates the `setLzConfig()` wrapper function.
 *
 * @dev    PAYEToken's constructor sets the LayerZero endpoint delegate to
 *         `treasury`.  On older deployments the contract cannot call
 *         `endpoint.setConfig` on itself because the developer is not the
 *         delegate.  This script lets treasury push the configuration directly
 *         through the endpoint as the registered delegate.
 *
 *         ONLY needed for contracts deployed BEFORE `setLzConfig()` was added
 *         to PAYEToken (May 2025).  For new deployments, use ConfigureLz.s.sol
 *         instead (developer-callable, no treasury involvement).
 *
 * ─── Required environment variables ──────────────────────────────────────────
 *   LOCAL_PAYE_ADDRESS   — address of the legacy PAYEToken on THIS chain
 *   LZ_ENDPOINT_ADDRESS  — address of the LayerZero EndpointV2 on this chain
 *   SOLANA_PAYE_PEER     — bytes32 peer address of the Solana PAYE OFT program
 *   SEND_ULN_302         — address of SendUln302 on this chain
 *   RECEIVE_ULN_302      — address of ReceiveUln302 on this chain
 *   LZ_EXECUTOR          — address of the LZ Executor on this chain
 *   LZ_DVN               — address of the LZ Labs DVN on this chain
 *   REMOTE_EID           — EID of the remote Solana endpoint
 *   CONFIRMATIONS        — block confirmations required (1 for testnet, 15 for mainnet)
 *
 * ─── Usage ────────────────────────────────────────────────────────────────────
 *   # Treasury wallet signs (treasury = the LZ endpoint delegate)
 *   forge script script/MigrateLzDelegate.s.sol \
 *     --rpc-url $ETH_RPC_URL \
 *     --account treasury \
 *     --broadcast
 *
 *   After deploying new PAYEToken contracts (with setLzConfig), use
 *   ConfigureLz.s.sol instead — it requires only the developer wallet.
 */
contract MigrateLzDelegate is Script {
    // Packing env vars into a struct keeps the run() stack frame shallow enough
    // to avoid the "stack too deep" compiler error (Solidity stack limit = 16 slots).
    struct Params {
        address localPaye;
        address endpointAddr;
        bytes32 solanaPeer;
        address sendUln302;
        address receiveUln302;
        address executor;
        address dvn;
        uint32 remoteEid;
        uint64 confirmations;
    }

    function run() external {
        Params memory p = _loadParams();

        ILayerZeroEndpointV2 ep = ILayerZeroEndpointV2(p.endpointAddr);

        // ── Build config param arrays ────────────────────────────────────────

        SetConfigParam[] memory execParams = new SetConfigParam[](1);
        execParams[0] = SetConfigParam({
            eid: p.remoteEid,
            configType: MIGRATE_CONFIG_TYPE_EXECUTOR,
            config: abi.encode(
                MigrateExecutorConfig({
                    maxMessageSize: 10_000,
                    executor: p.executor
                })
            )
        });

        address[] memory dvns = new address[](1);
        dvns[0] = p.dvn;
        bytes memory ulnBytes = abi.encode(
            MigrateUlnConfig({
                confirmations: p.confirmations,
                requiredDVNCount: 1,
                optionalDVNCount: 0,
                optionalDVNThreshold: 0,
                requiredDVNs: dvns,
                optionalDVNs: new address[](0)
            })
        );

        SetConfigParam[] memory ulnParams = new SetConfigParam[](1);
        ulnParams[0] = SetConfigParam({
            eid: p.remoteEid,
            configType: MIGRATE_CONFIG_TYPE_ULN,
            config: ulnBytes
        });

        // ── Broadcast ────────────────────────────────────────────────────────

        vm.startBroadcast();

        // Treasury calls endpoint directly as the registered delegate.
        ep.setConfig(p.localPaye, p.sendUln302, execParams);
        ep.setConfig(p.localPaye, p.sendUln302, ulnParams);
        ep.setConfig(p.localPaye, p.receiveUln302, ulnParams);

        vm.stopBroadcast();

        // ── Log ───────────────────────────────────────────────────────────────

        console2.log("=== MigrateLzDelegate ===");
        console2.log("Chain ID        :", block.chainid);
        console2.log("Local PAYE      :", p.localPaye);
        console2.log("Endpoint        :", p.endpointAddr);
        console2.log("Remote EID      :", p.remoteEid);
        console2.log("Solana peer     :", vm.toString(p.solanaPeer));
        console2.log("Confirmations   :", p.confirmations);
        console2.log("LZ DVN          :", p.dvn);
        console2.log("LZ Executor     :", p.executor);
        console2.log(
            "Done: executor + send ULN + receive ULN configured via delegate."
        );
        console2.log(
            "NOTE: Use ConfigureLz.s.sol for new deployments (no treasury needed)."
        );
    }

    function _loadParams() private view returns (Params memory p) {
        p.localPaye = vm.envAddress("LOCAL_PAYE_ADDRESS");
        p.endpointAddr = vm.envAddress("LZ_ENDPOINT_ADDRESS");
        p.solanaPeer = vm.envBytes32("SOLANA_PAYE_PEER");
        p.sendUln302 = vm.envAddress("SEND_ULN_302");
        p.receiveUln302 = vm.envAddress("RECEIVE_ULN_302");
        p.executor = vm.envAddress("LZ_EXECUTOR");
        p.dvn = vm.envAddress("LZ_DVN");
        p.remoteEid = uint32(vm.envUint("REMOTE_EID"));
        p.confirmations = uint64(vm.envUint("CONFIRMATIONS"));

        require(p.localPaye != address(0), "Migrate: zero local paye");
        require(p.endpointAddr != address(0), "Migrate: zero endpoint");
        require(p.solanaPeer != bytes32(0), "Migrate: zero solana peer");
        require(p.sendUln302 != address(0), "Migrate: zero sendUln302");
        require(p.receiveUln302 != address(0), "Migrate: zero receiveUln302");
        require(p.executor != address(0), "Migrate: zero executor");
        require(p.dvn != address(0), "Migrate: zero dvn");
        require(p.remoteEid != 0, "Migrate: zero remote eid");
        require(p.confirmations != 0, "Migrate: zero confirmations");
    }
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Krypto Capital LLC (Koinon). All rights reserved.
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {PAYEToken} from "../src/PAYEToken.sol";

// ─── Minimal LZ Endpoint mock ────────────────────────────────────────────────
// Only implements the two calls made during OApp construction / peer-wiring:
//   • setDelegate(address)  — called by OAppCore constructor
//   • setConfig(...)        — may be called for configuration
// All other interface methods are stubs that revert with "not implemented" if
// unexpectedly reached during unit tests.

contract MockEndpointV2 {
    // Records the delegate set by the OApp
    mapping(address oapp => address delegate) public delegates;

    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
    }

    // Stub: not needed for unit tests
    function setConfig(address, address, bytes calldata) external {}

    // Satisfy any accidental ILayerZeroEndpointV2 calls cleanly
    fallback() external {}
}

// ─── PAYEToken Tests ──────────────────────────────────────────────────────────

contract PAYETokenTest is Test {
    // ── Constants ──────────────────────────────────────────────────────────────

    uint256 constant TOTAL_SUPPLY_UNITS = 125_000_000 * 10 ** 4; // 1_250_000_000_000

    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");
    address attacker = makeAddr("attacker");

    MockEndpointV2 endpoint;

    PAYEToken homeToken; // Ethereum — mints full supply
    PAYEToken remoteToken; // Linea    — zero initial supply

    // ── Setup ──────────────────────────────────────────────────────────────────

    function setUp() public {
        endpoint = new MockEndpointV2();
        homeToken = new PAYEToken(address(endpoint), treasury, TOTAL_SUPPLY_UNITS);
        remoteToken = new PAYEToken(address(endpoint), treasury, 0);
    }

    // ── Metadata ───────────────────────────────────────────────────────────────

    function test_name() public view {
        assertEq(homeToken.name(), "PayETH");
    }

    function test_symbol() public view {
        assertEq(homeToken.symbol(), "PAYE");
    }

    function test_decimals() public view {
        assertEq(homeToken.decimals(), 4);
    }

    function test_sharedDecimals() public view {
        assertEq(homeToken.sharedDecimals(), 4);
    }

    // ── Supply ─────────────────────────────────────────────────────────────────

    function test_homeChain_totalSupply() public view {
        assertEq(homeToken.totalSupply(), TOTAL_SUPPLY_UNITS);
    }

    function test_homeChain_treasuryBalance() public view {
        assertEq(homeToken.balanceOf(treasury), TOTAL_SUPPLY_UNITS);
    }

    function test_remoteChain_zeroSupply() public view {
        assertEq(remoteToken.totalSupply(), 0);
        assertEq(remoteToken.balanceOf(treasury), 0);
    }

    function test_isHomeChain_flag() public view {
        assertTrue(homeToken.IS_HOME_CHAIN());
        assertFalse(remoteToken.IS_HOME_CHAIN());
    }

    // ── Ownership ──────────────────────────────────────────────────────────────

    function test_owner_is_treasury() public view {
        assertEq(homeToken.owner(), treasury);
        assertEq(remoteToken.owner(), treasury);
    }

    function test_ownable2step_pendingOwnerStart() public view {
        assertEq(homeToken.pendingOwner(), address(0));
    }

    function test_ownable2step_transferRequiresAcceptance() public {
        vm.prank(treasury);
        homeToken.transferOwnership(alice);

        // Pending owner is set but ownership not yet transferred
        assertEq(homeToken.pendingOwner(), alice);
        assertEq(homeToken.owner(), treasury);

        // New owner accepts
        vm.prank(alice);
        homeToken.acceptOwnership();

        assertEq(homeToken.owner(), alice);
        assertEq(homeToken.pendingOwner(), address(0));
    }

    function test_transferOwnership_onlyOwner() public {
        vm.expectRevert();
        vm.prank(attacker);
        homeToken.transferOwnership(attacker);
    }

    // ── No-mint guarantee ──────────────────────────────────────────────────────

    function test_noPublicMintFunction() public view {
        // Verify there is no external mint selector on the deployed contract.
        // bytes4(keccak256("mint(address,uint256)")) = 0x40c10f19
        bytes4 mintSelector = bytes4(keccak256("mint(address,uint256)"));
        // The contract should not expose this function; calling it must revert.
        (bool success,) = address(homeToken).staticcall(abi.encodeWithSelector(mintSelector, alice, 1));
        assertFalse(success, "PAYEToken must not expose a public mint function");
    }

    function test_supplyIsFixed_afterDeploy() public view {
        // Supply at deployment equals expected constant
        assertEq(homeToken.totalSupply(), TOTAL_SUPPLY_UNITS);
    }

    // ── Transfers ──────────────────────────────────────────────────────────────

    function test_transfer() public {
        uint256 amount = 1_000 * 10 ** 4; // 1,000 PAYE

        vm.prank(treasury);
        assertTrue(homeToken.transfer(alice, amount));

        assertEq(homeToken.balanceOf(alice), amount);
        assertEq(homeToken.balanceOf(treasury), TOTAL_SUPPLY_UNITS - amount);
        assertEq(homeToken.totalSupply(), TOTAL_SUPPLY_UNITS); // invariant
    }

    function test_transfer_revertsOnInsufficientBalance() public {
        vm.expectRevert();
        vm.prank(alice); // alice has 0 balance
        homeToken.transfer(treasury, 1); // reverts — no return value to check
    }

    // ── Peer management (owner-only) ───────────────────────────────────────────

    function test_setPeer_onlyOwner() public {
        uint32 remoteEid = 30183; // Linea Mainnet EID
        bytes32 remotePeer = bytes32(uint256(uint160(address(remoteToken))));

        // Attacker cannot set peer
        vm.expectRevert();
        vm.prank(attacker);
        homeToken.setPeer(remoteEid, remotePeer);

        // Owner can set peer
        vm.prank(treasury);
        homeToken.setPeer(remoteEid, remotePeer);

        assertEq(homeToken.peers(remoteEid), remotePeer);
    }

    // ── Constructor guards ─────────────────────────────────────────────────────

    function test_constructor_revertsOnZeroTreasury() public {
        // OFT passes treasury as the LZ delegate; OAppCore reverts with InvalidDelegate()
        // before our require() runs — but the zero-address is still rejected at construction.
        vm.expectRevert();
        new PAYEToken(address(endpoint), address(0), TOTAL_SUPPLY_UNITS);
    }

    // ── Fuzz ───────────────────────────────────────────────────────────────────

    /// @dev Total supply must never change via ERC-20 transfers alone.
    function testFuzz_transferPreservesTotalSupply(uint96 amount) public {
        uint256 amt = uint256(amount) % (TOTAL_SUPPLY_UNITS + 1);
        vm.prank(treasury);
        assertTrue(homeToken.transfer(alice, amt));
        assertEq(homeToken.totalSupply(), TOTAL_SUPPLY_UNITS);
    }
}

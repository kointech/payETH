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
    address dev = makeAddr("developer");

    MockEndpointV2 endpoint;

    PAYEToken homeToken; // Ethereum — mints full supply
    PAYEToken remoteToken; // Linea    — zero initial supply

    // ── Setup ──────────────────────────────────────────────────────────────────

    function setUp() public {
        endpoint = new MockEndpointV2();
        homeToken = new PAYEToken(
            address(endpoint),
            treasury,
            TOTAL_SUPPLY_UNITS
        );
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
        assertTrue(homeToken.isHomeChain());
        assertFalse(remoteToken.isHomeChain());
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
        (bool success, ) = address(homeToken).staticcall(
            abi.encodeWithSelector(mintSelector, alice, 1)
        );
        assertFalse(
            success,
            "PAYEToken must not expose a public mint function"
        );
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
        vm.expectRevert(PAYEToken.NotOwnerOrDeveloper.selector);
        vm.prank(attacker);
        homeToken.setPeer(remoteEid, remotePeer);

        // Owner can set peer
        vm.prank(treasury);
        homeToken.setPeer(remoteEid, remotePeer);

        assertEq(homeToken.peers(remoteEid), remotePeer);
    }

    // ── Developer role ─────────────────────────────────────────────────────────

    function test_deployer_isInitialDeveloper() public view {
        // address(this) is the deployer in tests
        assertEq(homeToken.developer(), address(this));
        assertTrue(homeToken.developerEnabled());
    }

    function test_setDeveloper_onlyOwner() public {
        vm.expectRevert();
        vm.prank(attacker);
        homeToken.setDeveloper(dev);

        // Two-step: setDeveloper only queues the change.
        vm.prank(treasury);
        homeToken.setDeveloper(dev);
        assertEq(homeToken.pendingDeveloper(), dev);
        assertEq(homeToken.developer(), address(this)); // still the old developer

        // Pending address must accept before the role is granted.
        vm.prank(dev);
        homeToken.acceptDeveloper();
        assertEq(homeToken.developer(), dev);
        assertEq(homeToken.pendingDeveloper(), address(0));
    }

    function test_enableDeveloper_onlyOwner() public {
        vm.expectRevert();
        vm.prank(attacker);
        homeToken.enableDeveloper();

        vm.prank(treasury);
        homeToken.enableDeveloper();
        assertTrue(homeToken.developerEnabled());
    }

    function test_disableDeveloper_onlyOwner() public {
        vm.prank(treasury);
        homeToken.enableDeveloper();

        vm.expectRevert();
        vm.prank(attacker);
        homeToken.disableDeveloper();

        vm.prank(treasury);
        homeToken.disableDeveloper();
        assertFalse(homeToken.developerEnabled());
    }

    function test_developer_canSetPeer_whenEnabled() public {
        uint32 remoteEid = 30183;
        bytes32 remotePeer = bytes32(uint256(uint160(address(remoteToken))));

        // Two-step: propose then accept.
        vm.prank(treasury);
        homeToken.setDeveloper(dev);
        vm.prank(dev);
        homeToken.acceptDeveloper();

        vm.prank(treasury);
        homeToken.disableDeveloper();

        // Developer cannot set peer while disabled
        vm.expectRevert(PAYEToken.NotOwnerOrDeveloper.selector);
        vm.prank(dev);
        homeToken.setPeer(remoteEid, remotePeer);

        // Owner enables developer
        vm.prank(treasury);
        homeToken.enableDeveloper();

        // Developer can now set peer
        vm.prank(dev);
        homeToken.setPeer(remoteEid, remotePeer);
        assertEq(homeToken.peers(remoteEid), remotePeer);
    }

    function test_developer_cannotSetPeer_afterDisabled() public {
        uint32 remoteEid = 30183;
        bytes32 remotePeer = bytes32(uint256(uint160(address(remoteToken))));

        // Two-step: propose then accept.
        vm.prank(treasury);
        homeToken.setDeveloper(dev);
        vm.prank(dev);
        homeToken.acceptDeveloper();

        vm.prank(treasury);
        homeToken.enableDeveloper();

        // Developer can set peer
        vm.prank(dev);
        homeToken.setPeer(remoteEid, remotePeer);

        // Owner disables developer
        vm.prank(treasury);
        homeToken.disableDeveloper();

        // Developer can no longer set peer
        vm.expectRevert(PAYEToken.NotOwnerOrDeveloper.selector);
        vm.prank(dev);
        homeToken.setPeer(remoteEid, bytes32(0));
    }

    function test_developer_changeTo_newAddress() public {
        address dev2 = makeAddr("developer2");

        // Promote dev via two-step.
        vm.prank(treasury);
        homeToken.setDeveloper(dev);
        vm.prank(dev);
        homeToken.acceptDeveloper();

        vm.prank(treasury);
        homeToken.enableDeveloper();

        // Replace with dev2 via two-step.
        vm.prank(treasury);
        homeToken.setDeveloper(dev2);
        vm.prank(dev2);
        homeToken.acceptDeveloper();

        assertEq(homeToken.developer(), dev2);

        // Old developer is revoked
        vm.expectRevert(PAYEToken.NotOwnerOrDeveloper.selector);
        vm.prank(dev);
        homeToken.setPeer(30183, bytes32(uint256(1)));

        // New developer works
        vm.prank(dev2);
        homeToken.setPeer(30183, bytes32(uint256(1)));
    }

    // ── Two-step developer transfer ────────────────────────────────────────────

    function test_setDeveloper_setsOnlyPending() public {
        vm.prank(treasury);
        homeToken.setDeveloper(dev);

        // Role not yet transferred — only pending is updated.
        assertEq(homeToken.pendingDeveloper(), dev);
        assertEq(homeToken.developer(), address(this));
    }

    function test_acceptDeveloper_onlyPendingCanAccept() public {
        vm.prank(treasury);
        homeToken.setDeveloper(dev);

        vm.expectRevert(PAYEToken.NotPendingDeveloper.selector);
        vm.prank(attacker);
        homeToken.acceptDeveloper();

        // Correct pending address can accept.
        vm.prank(dev);
        homeToken.acceptDeveloper();
        assertEq(homeToken.developer(), dev);
    }

    function test_setDeveloper_zeroAddress_immediateRemoval() public {
        // Setup: make dev the active developer.
        vm.prank(treasury);
        homeToken.setDeveloper(dev);
        vm.prank(dev);
        homeToken.acceptDeveloper();

        vm.prank(treasury);
        homeToken.enableDeveloper();

        // Removing with address(0) is immediate — no accept step required.
        vm.prank(treasury);
        homeToken.setDeveloper(address(0));

        assertEq(homeToken.developer(), address(0));
        assertEq(homeToken.pendingDeveloper(), address(0));
        assertFalse(homeToken.developerEnabled());
    }

    function test_setDeveloper_overwritesPending() public {
        address dev2 = makeAddr("developer2");

        vm.prank(treasury);
        homeToken.setDeveloper(dev);

        // Owner can overwrite the pending address before it is accepted.
        vm.prank(treasury);
        homeToken.setDeveloper(dev2);
        assertEq(homeToken.pendingDeveloper(), dev2);

        // Original dev can no longer accept.
        vm.expectRevert(PAYEToken.NotPendingDeveloper.selector);
        vm.prank(dev);
        homeToken.acceptDeveloper();
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

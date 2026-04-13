// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Krypto Capital LLC (Koinon). All rights reserved.
// PAYE / PayETH — Omnichain Fungible Token (LayerZero OFT v2)
//
// IP NOTICE:
//   This contract and all derivative works are the exclusive intellectual property
//   of Krypto Capital LLC (operating as Koinon).  No licence to reproduce, distribute,
//   or create derivative works is granted without prior written consent from Krypto
//   Capital LLC.
//
// SECURITY NOTICE:
//   - Fixed total supply: 125,000,000 PAYE (minted once at deployment on the home chain)
//   - No privileged mint or burn functions beyond the LayerZero OFT bridge mechanism
//   - Ownership transferred via two-step process to prevent accidental loss
//   - No backdoors; contract logic is fully transparent and auditable
//
// CROSS-CHAIN ARCHITECTURE:
//   Home chain  (Ethereum)  — deploys with initialSupply = 125_000_000 × 10^4
//   Remote chains (Linea, …) — deploys with initialSupply = 0  (supply arrives via bridge)
//   All deployments must be wired together with setPeer() before any bridging

pragma solidity 0.8.22;

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title  PAYEToken
 * @author Krypto Capital LLC (Koinon)
 * @notice PAYE is the native token of the PayETH project.
 *         It is a LayerZero OFT (Omnichain Fungible Token) with a fixed total supply
 *         of 125,000,000 PAYE distributed across all connected chains.
 *
 * @dev Decimals are set to 4 (not the ERC-20 default of 18).
 *      sharedDecimals() is overridden to 4 so the inter-chain decimal conversion
 *      rate is exactly 1 (no dust loss on any EVM chain).
 *
 *      Deployment pattern:
 *        • Home chain   → pass initialSupply = 125_000_000 * 10**4
 *        • Remote chains → pass initialSupply = 0
 */
contract PAYEToken is OFT, Ownable2Step {
    // ─── Constants ────────────────────────────────────────────────────────────

    uint8 private constant _DECIMALS = 4;
    uint8 private constant _SHARED_DECIMALS = 4;
    string private constant _NAME = "PayETH";
    string private constant _SYMBOL = "PAYE";

    // ─── Immutables ───────────────────────────────────────────────────────────

    /// @notice True on the Ethereum home-chain deployment where the full supply was minted.
    bool public immutable IS_HOME_CHAIN;

    // ─── Events ───────────────────────────────────────────────────────────────

    /// @dev Emitted once at construction when the full supply is minted.
    event SupplyMinted(address indexed treasury, uint256 amount);

    // ─── Constructor ─────────────────────────────────────────────────────────

    /**
     * @param lzEndpoint   Address of the LayerZero EndpointV2 on this chain.
     * @param treasury     Address that receives the initial supply (Koinon wallet).
     *                     Also becomes the initial owner / delegate.
     * @param initialSupply Amount of PAYE (in smallest units, i.e. × 10**4) to mint
     *                     at deployment.  Must be 0 on remote chains.
     */
    constructor(address lzEndpoint, address treasury, uint256 initialSupply) OFT(_NAME, _SYMBOL, lzEndpoint, treasury) {
        require(treasury != address(0), "PAYE: zero treasury");

        // OZ v4 Ownable defaults owner to msg.sender (deployer).
        // Transfer ownership to the Koinon treasury wallet immediately so that
        // the treasury holds full control from the moment the contract is live.
        _transferOwnership(treasury);

        IS_HOME_CHAIN = (initialSupply > 0);

        if (initialSupply > 0) {
            _mint(treasury, initialSupply);
            emit SupplyMinted(treasury, initialSupply);
        }
    }

    // ─── ERC-20 overrides ─────────────────────────────────────────────────────

    /**
     * @notice Returns the number of decimal places used by PAYE.
     * @dev    Overrides the ERC-20 default of 18.  Must equal or exceed sharedDecimals().
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    // ─── OFT overrides ────────────────────────────────────────────────────────

    /**
     * @notice Returns the shared decimal precision used across all chains in the OFT mesh.
     * @dev    Must be ≤ decimals().  Setting this equal to decimals() means the
     *         decimalConversionRate == 1, so no dust is ever lost during bridging.
     */
    function sharedDecimals() public pure override returns (uint8) {
        return _SHARED_DECIMALS;
    }

    // ─── Ownership (Ownable2Step) ─────────────────────────────────────────────

    /**
     * @dev Overrides both OFT (Ownable) and Ownable2Step.  Ownership transfers are
     *      two-step: the proposed new owner must explicitly accept before the transfer
     *      is finalised, protecting against accidental key-loss.
     */
    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) onlyOwner {
        Ownable2Step.transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        Ownable2Step._transferOwnership(newOwner);
    }

    // ─── Safety ───────────────────────────────────────────────────────────────

    /**
     * @notice PAYE has no public mint function.  Supply is fixed at deployment.
     * @dev    The only way new tokens appear on a chain is via the LayerZero bridge
     *         (i.e. _credit() inside OFTCore), which is strictly offset by a
     *         corresponding _debit() on the source chain — total supply is conserved.
     */
}

# PAYEToken — Slither Static Analysis Report

**Date:** 2026-04-19  
**Tool:** Slither (Trail of Bits)  
**Command:** `.venv/bin/slither . --filter-paths "lib/"`  
**Contracts analysed:** 39 (101 detectors)  
**Findings:** 3 (0 High, 0 Medium, 1 Low, 2 Informational)

---

## Finding 1 — Missing Zero-Address Check

| Field       | Value |
|-------------|-------|
| Severity    | Low |
| Detector    | `missing-zero-check` |
| File        | `src/PAYEToken.sol` |
| Function    | `setDeveloper(address)` |
| Status      | **Fixed** |

### Description
`setDeveloper()` assigns `newDeveloper` to the `developer` state variable without first checking whether the address is `address(0)`.  Slither flags this as a potential accidental zero-address assignment.

### Context
`address(0)` is **intentionally** permitted — it is the documented mechanism for removing the developer role.  However, leaving `developerEnabled = true` while `developer == address(0)` creates a misleading state (the flag says enabled but no address can match `address(0)`).

### Fix Applied
- Added `// slither-disable-next-line missing-zero-check` with an inline explanation.
- Added automatic self-correction: when `newDeveloper == address(0)`, `developerEnabled` is set to `false` and a `DeveloperToggled(false)` event is emitted.  This keeps the contract state consistent and makes the intent explicit.

---

## Finding 2 — Compiler Version with Known Bug

| Field       | Value |
|-------------|-------|
| Severity    | Informational |
| Detector    | `solc-version` |
| File        | `src/PAYEToken.sol` |
| Previous    | `pragma solidity 0.8.22` |
| Status      | **Fixed** |

### Description
Solidity 0.8.22 contains the known bug `VerbatimInvalidDeduplication`.  This bug affects the Yul optimizer when `verbatim` built-ins are used inside inline assembly.

### Context
PAYEToken contains **no inline assembly** and does not use `verbatim` built-ins, so the bug has no practical impact on the deployed bytecode.  Upgrading is nonetheless recommended as good hygiene.

### Fix Applied
- `pragma solidity 0.8.22` upgraded to `pragma solidity 0.8.28` in `src/PAYEToken.sol`.
- `solc = "0.8.22"` upgraded to `solc = "0.8.28"` in `foundry.toml`.

---

## Finding 3 — Naming Convention Violations

| Field       | Value |
|-------------|-------|
| Severity    | Informational |
| Detector    | `naming-convention` |
| File        | `src/PAYEToken.sol` |
| Status      | **Fixed** |

### Description
Three naming issues were reported:

| Symbol | Issue |
|--------|-------|
| `IS_HOME_CHAIN` (immutable) | `UPPER_CASE` — Slither expects `mixedCase` for non-constant state variables |
| `_eid` (parameter of `setPeer`) | Leading underscore — Slither expects pure `mixedCase` |
| `_peer` (parameter of `setPeer`) | Leading underscore — Slither expects pure `mixedCase` |

### Fix Applied

**`IS_HOME_CHAIN`** — Renamed to `isHomeChain` throughout:
- `src/PAYEToken.sol` (declaration + assignment)
- `script/DeployHome.s.sol`
- `script/DeployRemote.s.sol`
- `test/PAYEToken.t.sol`

**`_eid` / `_peer`** — These parameters override the LayerZero `OAppCore.setPeer()` interface where the upstream library uses this exact naming convention.  Renaming them would diverge from the LZ standard for no functional benefit.  A `// slither-disable-next-line naming-convention` suppression was added.

---

## Summary

| # | Detector | Severity | Resolution |
|---|----------|----------|------------|
| 1 | `missing-zero-check` | Low | Functional fix + inline suppression |
| 2 | `solc-version` | Info | Upgraded to Solidity 0.8.28 |
| 3 | `naming-convention` (IS_HOME_CHAIN) | Info | Renamed to `isHomeChain` |
| 3 | `naming-convention` (_eid, _peer) | Info | Suppressed (LZ interface override) |

No High or Medium severity issues were found.

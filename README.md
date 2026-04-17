# PAYE / PayETH — Omnichain Token

> Issued by a United States Entity (US Virgin Islands)  
> Beneficially owned 100% by **Matthew Mecke** and/or assigns  
> Held through **Krypto Capital LLC (Koinon)** — interim USVI holding entity  
> IP © 2025–2026 Matthew Mecke / Krypto Capital LLC. All rights reserved.

## Overview

PAYE is the native token of the PayETH project — a single-supply, cross-chain fungible token built on [LayerZero v2 OFT](https://docs.layerzero.network/v2/developers/evm/oft/quickstart).

| Property | Value |
|---|---|
| Token name | PayETH |
| Symbol | PAYE |
| Total supply | 125,000,000 PAYE (fixed) |
| Decimal places | 4 |
| Standard | LayerZero OFT v2 |
| Home chain | Linea (full supply minted here) |
| Remote chains | Solana (bridged representation) |
| Future chains | Ethereum, and others (expanding) |

## Architecture

```
Linea  ──── PAYEToken (OFT) ← mints 125M PAYE to treasury
                │
        LayerZero bridge  (burn ↔ mint, total supply preserved)
                │
Solana ──── PAYEToken (OFT/SPL) ← starts with 0 supply; receives bridged tokens
                │
         (more chains to follow)
```

Solana bridging uses the [LayerZero Solana OFT program](https://docs.layerzero.network/v2/developers/solana/oft/quickstart) — see the Solana section below.

## Security

- **No public mint function** — supply is fixed from block 0; only the LZ bridge can move tokens between chains (burn on source → mint on destination), preserving total supply across all chains.
- **Ownable2Step** — ownership transfers are two-step; the proposed new owner must explicitly call `acceptOwnership()` before the transfer finalises, preventing accidental key loss.
- **Audit-ready** — no backdoors, no privileged hidden functions, fully transparent logic.
- **Recommended**: use a Gnosis Safe multisig as the `TREASURY_ADDRESS`.

## Deployment

### Prerequisites

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
cp .env.example .env   # fill in your values
```

### Wallet setup

Deployment uses a [`cast wallet`](https://book.getfoundry.sh/reference/cast/cast-wallet) account instead of raw private keys:

```bash
cast wallet import deployer --interactive
```

You'll be prompted for the private key and a password to encrypt it on disk.

### 1 — Deploy on Linea (home chain)

```bash
make deploy-home
```

### 2 — Deploy on Solana (remote chain)

```bash
make deploy-remote
```

### 3 — Wire peers (run on both chains)

After both deployments, update `.env` with `LOCAL_PAYE_ADDRESS`, `REMOTE_EID`, and `REMOTE_PAYE_ADDRESS`, then:

```bash
make wire
```

Or run each side individually:

```bash
make wire-home
make wire-remote
```

### Dry run (simulate without broadcasting)

```bash
make dry-deploy-home
make dry-deploy-remote
```

Override the wallet account: `make deploy-home ACCOUNT=myaccount`

#### LayerZero Endpoint IDs

| Chain | Mainnet EID | Testnet EID |
|---|---|---|
| Linea | 30183 | 40287 (Linea Sepolia) |
| Solana | 30168 | 40168 (Devnet) |
| Ethereum | 30101 | 40161 (Sepolia) |

## Solana

The Solana OFT representation of PAYE uses the [LayerZero Solana OFT program](https://docs.layerzero.network/v2/developers/solana/oft/quickstart). It is maintained in a separate repository: **[kointech/payETH-solana](https://github.com/kointech/payETH-solana)**. Tokens bridged to Solana are represented as an SPL token with a corresponding Solana OFT store; bridging burns tokens on the Linea side and mints on Solana (and vice-versa), keeping total supply constant.

## Before pushing

Always run the formatter before committing or pushing:

```bash
forge fmt
```

CI enforces this with `forge fmt --check` — any unformatted files will fail the pipeline.

## Tests

```bash
make test        # or: forge test
make test-v      # verbose (-vvv)
```

19 tests covering: decimals, supply, ownership (Ownable2Step), no-mint guarantee, transfer invariants, peer access control, constructor guards, and a fuzz suite.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Makefile targets

| Target | Description |
|---|---|
| `make build` | Compile contracts |
| `make test` | Run test suite |
| `make test-v` | Run tests with `-vvv` |
| `make clean` | Remove build artifacts |
| `make deploy-home` | Deploy to Linea |
| `make deploy-remote` | Deploy to Solana |
| `make wire-home` | Wire peers (Ethereum side) |
| `make wire-remote` | Wire peers (Linea side) |
| `make wire` | Wire both sides |
| `make dry-deploy-home` | Simulate home deploy |
| `make dry-deploy-remote` | Simulate remote deploy |

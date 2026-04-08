# PAYE / PayETH — Omnichain Token

> Issued and owned by **Krypto Capital LLC (Koinon)**  
> IP © 2026 Krypto Capital LLC. All rights reserved.

## Overview

PAYE is the native token of the PayETH project — a single-supply, cross-chain fungible token built on [LayerZero v2 OFT](https://docs.layerzero.network/v2/developers/evm/oft/quickstart).

| Property | Value |
|---|---|
| Token name | PayETH |
| Symbol | PAYE |
| Total supply | 125,000,000 PAYE (fixed) |
| Decimal places | 4 |
| Standard | LayerZero OFT v2 |
| Home chain | Ethereum (full supply minted here) |
| Remote chains | Linea (bridged representation) |
| Future chains | Solana (LayerZero OFT Solana program) |

## Architecture

```
Ethereum ──── PAYEToken (OFT) ← mints 125M PAYE to treasury
                  │
          LayerZero bridge  (burn ↔ mint, total supply preserved)
                  │
Linea    ──── PAYEToken (OFT) ← starts with 0 supply; receives bridged tokens
```

Solana bridging requires the [LayerZero Solana OFT program](https://docs.layerzero.network/v2/developers/solana/oft/quickstart) — see the Solana section below.

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

### 1 — Deploy on Ethereum (home chain)

```bash
forge script script/DeployHome.s.sol \
  --rpc-url $ETH_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2 — Deploy on Linea (remote chain)

```bash
forge script script/DeployRemote.s.sol \
  --rpc-url $LINEA_RPC_URL \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url https://api.lineascan.build/api
```

### 3 — Wire peers (run on both chains)

After both deployments, update `.env` with `LOCAL_PAYE_ADDRESS`, `REMOTE_EID`, and `REMOTE_PAYE_ADDRESS`, then run once per chain:

```bash
# From Ethereum side
forge script script/WirePeers.s.sol --rpc-url $ETH_RPC_URL --broadcast

# From Linea side
forge script script/WirePeers.s.sol --rpc-url $LINEA_RPC_URL --broadcast
```

#### LayerZero Endpoint IDs

| Chain | Mainnet EID | Testnet EID |
|---|---|---|
| Ethereum | 30101 | 40161 (Sepolia) |
| Linea | 30183 | 40287 (Linea Sepolia) |
| Solana | 30168 | 40168 (Devnet) |

## Solana

The Solana OFT representation of PAYE uses the [LayerZero Solana OFT program](https://docs.layerzero.network/v2/developers/solana/oft/quickstart). It is a separate deployment outside this Foundry project. Tokens bridged to Solana are represented as an SPL token with a corresponding Solana OFT store; bridging burns tokens on the EVM side and mints on Solana (and vice-versa), keeping total supply constant.

## Tests

```bash
forge test -v
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

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

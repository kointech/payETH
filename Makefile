-include .env

# ─── Configuration ────────────────────────────────────────────────────────────
ACCOUNT     ?= deployer
FORGE_FLAGS ?=

# ─── Build & Test ─────────────────────────────────────────────────────────────

build:
	forge build

test:
	forge test

test-v:
	forge test -vvv

clean:
	forge clean

# ─── Deploy ───────────────────────────────────────────────────────────────────

deploy-home:
	forge script script/DeployHome.s.sol \
		--rpc-url $(ETH_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(FORGE_FLAGS)

deploy-remote:
	forge script script/DeployRemote.s.sol \
		--rpc-url $(LINEA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--verify \
		--verifier blockscout \
		--verifier-url https://api.lineascan.build/api \
		$(FORGE_FLAGS)

# ─── Wire Peers ───────────────────────────────────────────────────────────────

wire-home:
	forge script script/WirePeers.s.sol \
		--rpc-url $(ETH_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		$(FORGE_FLAGS)

wire-remote:
	forge script script/WirePeers.s.sol \
		--rpc-url $(LINEA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		$(FORGE_FLAGS)

wire: wire-home wire-remote

# ─── Dry Runs (no broadcast) ─────────────────────────────────────────────────

dry-deploy-home:
	forge script script/DeployHome.s.sol \
		--rpc-url $(ETH_RPC_URL) \
		--account $(ACCOUNT) \
		$(FORGE_FLAGS)

dry-deploy-remote:
	forge script script/DeployRemote.s.sol \
		--rpc-url $(LINEA_RPC_URL) \
		--account $(ACCOUNT) \
		$(FORGE_FLAGS)

.PHONY: build test test-v clean deploy-home deploy-remote wire-home wire-remote wire dry-deploy-home dry-deploy-remote

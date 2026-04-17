# Issued by a United States Entity (US Virgin Islands)
# Beneficially owned 100% by Matthew Mecke and/or assigns.
# Held through Krypto Capital LLC (Koinon) — interim USVI holding entity.
# IP © 2025–2026 Matthew Mecke / Krypto Capital LLC. All rights reserved.

-include .env

# ─── Configuration ────────────────────────────────────────────────────────────
ACCOUNT            ?= deployer
FORGE_FLAGS        ?=

# Chain RPC URLs (set in .env)
HOME_RPC_URL       ?=
REMOTE_RPC_URL     ?=

# Explorer API keys for contract verification (set in .env)
HOME_VERIFY_KEY    ?=
REMOTE_VERIFY_KEY  ?=

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
		--rpc-url $(HOME_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--verify \
		--etherscan-api-key $(HOME_VERIFY_KEY) \
		$(FORGE_FLAGS)

deploy-remote:
	forge script script/DeployRemote.s.sol \
		--rpc-url $(REMOTE_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--verify \
		--etherscan-api-key $(REMOTE_VERIFY_KEY) \
		$(FORGE_FLAGS)

# ─── Wire Peers ───────────────────────────────────────────────────────────────

wire-home:
	forge script script/WirePeers.s.sol \
		--rpc-url $(HOME_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		$(FORGE_FLAGS)

wire-remote:
	forge script script/WirePeers.s.sol \
		--rpc-url $(REMOTE_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		$(FORGE_FLAGS)

wire: wire-home wire-remote

# ─── Dry Runs (no broadcast) ─────────────────────────────────────────────────

dry-deploy-home:
	forge script script/DeployHome.s.sol \
		--rpc-url $(HOME_RPC_URL) \
		--account $(ACCOUNT) \
		$(FORGE_FLAGS)

dry-deploy-remote:
	forge script script/DeployRemote.s.sol \
		--rpc-url $(REMOTE_RPC_URL) \
		--account $(ACCOUNT) \
		$(FORGE_FLAGS)

# ─── Bridge ───────────────────────────────────────────────────────────────────
# Usage:  make bridge-home-to-remote AMOUNT=10 BRIDGE_ACCOUNT=treasury
#   Sends AMOUNT PAYE from the home chain to the remote chain.
#   BRIDGE_ACCOUNT must be a cast wallet account that holds PAYE on the source.
#   GAS_LIMIT is the executor gas on the destination (default 60000).

BRIDGE_ACCOUNT     ?= treasury
AMOUNT             ?= 10
GAS_LIMIT          ?= 60000
PAYE_DECIMALS      := 4
HOME_EID           ?= 40161
# Convert human amount → raw units (e.g. 10 → 100000 with 4 decimals)
RAW_AMOUNT          = $(shell echo '$(AMOUNT) * 10 ^ $(PAYE_DECIMALS)' | bc)

# LZ extra options: TYPE_3 + executor(01) + size(0011=17) + gasOption(01) + uint128 gas
LZ_OPTIONS          = $(shell printf '0x000301001101%032x' $(GAS_LIMIT))

# Address → left-zero-padded bytes32 (as LayerZero expects)
# 0x000000000000000000000000<40 hex chars of address>
addr_to_bytes32     = 0x000000000000000000000000$(subst 0x,,$(1))
SENDER_B32          = $(call addr_to_bytes32,$(TREASURY_ADDRESS))

# ── Quote (view the fee before sending) ──────────────────────────────────────

quote-home-to-remote:
	@echo "Quoting $(AMOUNT) PAYE ($(RAW_AMOUNT) raw) from Home → Remote (EID $(REMOTE_EID))..."
	@cast call $(LOCAL_PAYE_ADDRESS) \
		"quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)((uint256,uint256))" \
		"($(REMOTE_EID),$(SENDER_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		false \
		--rpc-url $(HOME_RPC_URL)

quote-remote-to-home:
	@echo "Quoting $(AMOUNT) PAYE ($(RAW_AMOUNT) raw) from Remote → Home (EID $(HOME_EID))..."
	@cast call $(LOCAL_PAYE_ADDRESS) \
		"quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)((uint256,uint256))" \
		"($(HOME_EID),$(SENDER_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		false \
		--rpc-url $(REMOTE_RPC_URL)

# ── Send ─────────────────────────────────────────────────────────────────────

bridge-home-to-remote:
	$(eval FEE := $(shell cast call $(LOCAL_PAYE_ADDRESS) \
		"quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)((uint256,uint256))" \
		"($(REMOTE_EID),$(SENDER_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		false \
		--rpc-url $(HOME_RPC_URL) | awk -F'[, ]+' '{gsub(/[()]/,""); print $$1}'))
	@echo "Bridging $(AMOUNT) PAYE  Home → Remote (EID $(REMOTE_EID))"
	@echo "Fee: $(FEE) wei"
	cast send $(LOCAL_PAYE_ADDRESS) \
		"send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)" \
		"($(REMOTE_EID),$(SENDER_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		"($(FEE),0)" \
		"$(TREASURY_ADDRESS)" \
		--rpc-url $(HOME_RPC_URL) \
		--value $(FEE) \
		--account $(BRIDGE_ACCOUNT)

bridge-remote-to-home:
	$(eval FEE := $(shell cast call $(LOCAL_PAYE_ADDRESS) \
		"quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)((uint256,uint256))" \
		"($(HOME_EID),$(SENDER_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		false \
		--rpc-url $(REMOTE_RPC_URL) | awk -F'[, ]+' '{gsub(/[()]/,""); print $$1}'))
	@echo "Bridging $(AMOUNT) PAYE  Remote → Home (EID $(HOME_EID))"
	@echo "Fee: $(FEE) wei"
	cast send $(LOCAL_PAYE_ADDRESS) \
		"send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)" \
		"($(HOME_EID),$(SENDER_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		"($(FEE),0)" \
		"$(TREASURY_ADDRESS)" \
		--rpc-url $(REMOTE_RPC_URL) \
		--value $(FEE) \
		--account $(BRIDGE_ACCOUNT)

# ─── Utilities ────────────────────────────────────────────────────────────────

DEPLOYER_ADDRESS ?= $(shell cast wallet address --account $(ACCOUNT))

nonce-home:
	@cast nonce $(DEPLOYER_ADDRESS) --rpc-url $(HOME_RPC_URL)

nonce-remote:
	@cast nonce $(DEPLOYER_ADDRESS) --rpc-url $(REMOTE_RPC_URL)

nonce: nonce-home nonce-remote

balance-home:
	@cast call $(LOCAL_PAYE_ADDRESS) "balanceOf(address)(uint256)" $(TREASURY_ADDRESS) --rpc-url $(HOME_RPC_URL)

balance-remote:
	@cast call $(LOCAL_PAYE_ADDRESS) "balanceOf(address)(uint256)" $(TREASURY_ADDRESS) --rpc-url $(REMOTE_RPC_URL)

.PHONY: build test test-v clean deploy-home deploy-remote wire-home wire-remote wire dry-deploy-home dry-deploy-remote nonce-home nonce-remote nonce quote-home-to-remote quote-remote-to-home bridge-home-to-remote bridge-remote-to-home balance-home balance-remote

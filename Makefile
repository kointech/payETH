# Issued by a United States Entity (US Virgin Islands)
# Beneficially owned 100% by Matthew Mecke and/or assigns.
# Held through Krypto Capital LLC (Koinon) — interim USVI holding entity.
# IP © 2025–2026 Matthew Mecke / Krypto Capital LLC. All rights reserved.

-include .env

# ─── Configuration ────────────────────────────────────────────────────────────
ACCOUNT            ?= deployer
FORGE_FLAGS        ?=

# Chain RPC URL (set in .env — one active line, others commented out)
RPC_URL            ?=

# Explorer API key for contract verification (set in .env)
VERIFY_KEY         ?=

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
# Set IS_HOME=true for the home chain (mints supply), IS_HOME=false for remote.

IS_HOME            ?= false

deploy:
	forge script script/Deploy.s.sol \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--verify \
		--etherscan-api-key $(VERIFY_KEY) \
		$(FORGE_FLAGS)

# ─── Wire Peers ───────────────────────────────────────────────────────────────
# Set LOCAL_PAYE_ADDRESS, REMOTE_EID, and REMOTE_PEER_BYTES32
# (non-EVM) or REMOTE_PAYE_ADDRESS (EVM) in .env, then run once per direction.

wire:
	forge script script/WirePeers.s.sol \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		$(FORGE_FLAGS)

# ─── Dry Run (no broadcast) ──────────────────────────────────────────────────

dry-deploy:
	forge script script/Deploy.s.sol \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		$(FORGE_FLAGS)

# ─── Bridge ───────────────────────────────────────────────────────────────────
# Set LOCAL_PAYE_ADDRESS and REMOTE_EID in .env, then:
#   make quote  [AMOUNT=10]                    — preview the LZ fee
#   make bridge [AMOUNT=10] [BRIDGE_ACCOUNT=…] — send PAYE to REMOTE_EID
# BRIDGE_ACCOUNT must be a cast wallet account that holds PAYE on LOCAL chain.
# GAS_LIMIT is the executor gas on the destination (default 60000).

BRIDGE_ACCOUNT     ?= treasury
AMOUNT             ?= 10
GAS_LIMIT          ?= 60000
PAYE_DECIMALS      := 4
# Convert human amount → raw units (e.g. 10 → 100000 with 4 decimals)
RAW_AMOUNT          = $(shell echo '$(AMOUNT) * 10 ^ $(PAYE_DECIMALS)' | bc)

# LZ extra options: TYPE_3 + executor(01) + size(0011=17) + gasOption(01) + uint128 gas
LZ_OPTIONS          = $(shell printf '0x000301001101%032x' $(GAS_LIMIT))

# Address → left-zero-padded bytes32 (as LayerZero expects)
# 0x000000000000000000000000<40 hex chars of address>
addr_to_bytes32     = 0x000000000000000000000000$(subst 0x,,$(1))
SENDER_B32          = $(call addr_to_bytes32,$(TREASURY_ADDRESS))
# Destination recipient on the remote chain.
# EVM chains: leave unset — defaults to your treasury address.
# Non-EVM (e.g. Solana): set RECIPIENT_B32 in .env to the wallet bytes32.
RECIPIENT_B32      ?= $(SENDER_B32)

# ── Quote (view the fee before sending) ──────────────────────────────────────

quote:
	@echo "Quoting $(AMOUNT) PAYE ($(RAW_AMOUNT) raw) → EID $(REMOTE_EID)..."
	@cast call $(LOCAL_PAYE_ADDRESS) \
		"quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)((uint256,uint256))" \
		"($(REMOTE_EID),$(RECIPIENT_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		false \
		--rpc-url $(RPC_URL)

# ── Send ───────────────────────────────────────────────────────────────────────────

bridge:
	$(eval FEE := $(shell cast call $(LOCAL_PAYE_ADDRESS) \
		"quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)((uint256,uint256))" \
		"($(REMOTE_EID),$(RECIPIENT_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		false \
		--rpc-url $(RPC_URL) | awk -F'[, ]+' '{gsub(/[()]/,""); print $$1}'))
	@echo "Bridging $(AMOUNT) PAYE → EID $(REMOTE_EID) → $(RECIPIENT_B32)"
	@echo "Fee: $(FEE) wei"
	cast send $(LOCAL_PAYE_ADDRESS) \
		"send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)" \
		"($(REMOTE_EID),$(RECIPIENT_B32),$(RAW_AMOUNT),$(RAW_AMOUNT),$(LZ_OPTIONS),0x,0x)" \
		"($(FEE),0)" \
		"$(TREASURY_ADDRESS)" \
		--rpc-url $(RPC_URL) \
		--value $(FEE) \
		--account $(BRIDGE_ACCOUNT)

# ─── Utilities ────────────────────────────────────────────────────────────────

DEPLOYER_ADDRESS ?= $(shell cast wallet address --account $(ACCOUNT))

nonce:
	@cast nonce $(DEPLOYER_ADDRESS) --rpc-url $(RPC_URL)

balance:
	@cast call $(LOCAL_PAYE_ADDRESS) "balanceOf(address)(uint256)" $(TREASURY_ADDRESS) --rpc-url $(RPC_URL)

.PHONY: build test test-v clean deploy dry-deploy wire nonce balance

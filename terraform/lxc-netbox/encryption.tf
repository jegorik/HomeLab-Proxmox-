# =============================================================================
# OpenTofu State File Encryption Configuration - Vault Transit Engine
# =============================================================================
# This file configures state file encryption using HashiCorp Vault's Transit
# Secrets Engine for centralized encryption key management and cryptographic
# operations as a service.
#
# Security Features:
# - Centralized key management via Vault Transit engine
# - Keys never leave Vault (encryption/decryption via API)
# - Automatic key versioning and rotation support
# - Full audit trail of all cryptographic operations
# - AES-256-GCM authenticated encryption
# - Policy-based access control
#
# Vault Transit Engine Benefits:
# - No local key storage (keys managed by Vault)
# - Simple key rotation (vault write -f transit/keys/<name>/rotate)
# - Compliance-ready (FIPS 140-2 compatible)
# - Multi-version key support (old ciphertext still decrypts)
# - Automatic key derivation and management
#
# Prerequisites:
# 1. Enable Transit secrets engine in Vault:
#    vault secrets enable transit
#
# 2. Create encryption key in Vault:
#    vault write -f transit/keys/tofu-state-encryption
#
# 3. Update Vault policy to allow OpenTofu access:
#    path \"transit/encrypt/tofu-state-encryption\" {
#      capabilities = [\"update\"]
#    }
#    path \"transit/decrypt/tofu-state-encryption\" {
#      capabilities = [\"update\"]
#    }
#
# 4. Authenticate OpenTofu with Vault (via userpass, AppRole, or token)
#
# Key Rotation:
# - Rotate key: vault write -f transit/keys/tofu-state-encryption/rotate
# - Old state files automatically decrypt with previous key versions
# - New encryptions use latest key version
#
# References:
# - OpenTofu Encryption: https://opentofu.org/docs/language/state/encryption/
# - Vault Transit Engine: https://developer.hashicorp.com/vault/docs/secrets/transit
# - OpenBao Provider: Compatible with Vault 1.14 and older (MPL license)
# =============================================================================

terraform {
  encryption {
    # -------------------------------------------------------------------------
    # OpenBao Key Provider Configuration (Vault Transit Engine)
    # -------------------------------------------------------------------------
    # The OpenBao key provider integrates with Vault's Transit Secrets Engine
    # to perform encryption and decryption operations. Keys are managed by
    # Vault and never exposed to OpenTofu.
    #
    # Compatibility: Works with Vault 1.14 and older (MPL license)
    # Note: Not compatible with Vault 1.15+ (BUSL license)

    key_provider "openbao" "vault_transit" {
      # Vault server address
      address = var.vault_address

      # Transit secrets engine mount path (default: "transit")
      transit_engine_path = var.transit_engine_path

      # Name of the encryption key in Vault
      # This key must be created in Vault before using:
      # vault write -f transit/keys/tofu-state-encryption
      key_name = var.transit_key_name

      # Key length in bytes (32 bytes = 256-bit AES encryption)
      key_length = var.transit_key_length

      # Note: Authentication is handled by the Vault provider in providers.tf
      # The openbao key provider will use the same Vault session
      # No additional token parameter needed when using provider-based auth
    }

    # -------------------------------------------------------------------------
    # AES-GCM Encryption Method Configuration
    # -------------------------------------------------------------------------
    # AES-GCM (Advanced Encryption Standard - Galois/Counter Mode) provides
    # both confidentiality and authenticity. It's a widely-adopted AEAD
    # (Authenticated Encryption with Associated Data) cipher.
    #
    # This method uses keys from the Vault Transit engine (via OpenBao provider)

    method "aes_gcm" "vault_method" {
      # Use the key from Vault Transit engine
      keys = key_provider.openbao.vault_transit
    }

    # -------------------------------------------------------------------------
    # State Encryption Configuration
    # -------------------------------------------------------------------------
    # Apply encryption to the OpenTofu state file to protect sensitive data
    # such as API tokens, IP addresses, passwords, and infrastructure details.
    #
    # All cryptographic operations are performed by Vault's Transit engine.

    state {
      # Encryption method to use for state file
      method = method.aes_gcm.vault_method

      # Enforce encryption (true = fail if encryption cannot be applied)
      # Set to true in production to prevent accidental plaintext state
      enforced = true
    }
  }
}

data "vault_generic_secret" "s3_bucket_name" {
  path = var.s3_bucket_name_vault_path
}


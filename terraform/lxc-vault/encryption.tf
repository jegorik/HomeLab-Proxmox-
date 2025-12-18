# =============================================================================
# OpenTofu State File Encryption Configuration
# =============================================================================
# This file configures state file encryption using PBKDF2 key derivation and
# AES-GCM encryption to protect sensitive information stored in the state.
#
# Security Features:
# - PBKDF2 key derivation with configurable iterations (default: 600,000)
# - SHA-512 hash function for enhanced security
# - AES-GCM authenticated encryption
# - Passphrase-based encryption with salt
# - 32-byte key length (256-bit encryption)
#
# Setup:
# 1. Store your passphrase securely (minimum 16 characters recommended)
# 2. Create passphrase file: echo "your-strong-passphrase" > ~/.ssh/state_passphrase
# 3. Set file permissions: chmod 600 ~/.ssh/state_passphrase
# 4. Configure var.passphrase to point to this file
#
# Security Best Practices:
# - Use a strong passphrase (16+ characters with mixed case, numbers, symbols)
# - Store passphrase file outside the repository
# - Use AWS Secrets Manager or HashiCorp Vault in production
# - Never commit the passphrase file to version control
# - Rotate passphrases periodically
#
# Algorithm Details:
# - Key Derivation: PBKDF2 (Password-Based Key Derivation Function 2)
# - Hash Function: SHA-512 (configurable via var.key_hash_function)
# - Iterations: 600,000 (configurable via var.key_iterations)
# - Salt Length: 32 bytes (configurable via var.key_salt_length)
# - Encryption: AES-GCM (Galois/Counter Mode with authentication)
# - Key Length: 32 bytes / 256 bits (configurable via var.key_length)
#
# References:
# - OpenTofu Encryption: https://opentofu.org/docs/language/state/encryption/
# - PBKDF2 Specification: RFC 8018
# - AES-GCM: NIST SP 800-38D
# =============================================================================

terraform {
  encryption {
    # -------------------------------------------------------------------------
    # PBKDF2 Key Provider Configuration
    # -------------------------------------------------------------------------
    # Password-Based Key Derivation Function 2 (PBKDF2) converts the passphrase
    # into a cryptographic key suitable for encryption. High iteration count
    # (600,000) provides protection against brute-force attacks.

    key_provider "pbkdf2" "generated_passphrase" {
      # Path to file containing the encryption passphrase
      # Security: File should be outside repository with chmod 600 permissions
      #
      # Passphrase File Setup:
      # 1. Create passphrase file:
      #    echo "your-strong-passphrase-min-16-characters" > ~/.ssh/state_passphrase
      # 2. Set strict permissions:
      #    chmod 600 ~/.ssh/state_passphrase
      # 3. Update terraform.tfvars:
      #    passphrase = "~/.ssh/state_passphrase"
      #
      # Passphrase Strength Requirements:
      # - Minimum 16 characters (recommended 32+)
      # - Mix of uppercase, lowercase, numbers, symbols
      # - Avoid dictionary words
      # - Use password manager to generate
      #
      # Example strong passphrase generation:
      #   openssl rand -base64 32 > ~/.ssh/state_passphrase
      #   chmod 600 ~/.ssh/state_passphrase
      #
      # ⚠️ WARNING: NEVER commit passphrase file to version control!
      # Add to .gitignore:
      #   echo "*_passphrase" >> .gitignore
      passphrase = file(var.passphrase)

      # Encryption key length in bytes (32 bytes = 256 bits)
      # Default: 32 (suitable for AES-256)
      key_length = var.key_length

      # Number of PBKDF2 iterations for key derivation
      # Higher values = more secure but slower (600,000 is recommended minimum)
      # Default: 600000
      iterations = var.key_iterations

      # Salt length in bytes for key derivation
      # Salt prevents rainbow table attacks and ensures unique keys
      # Default: 32
      salt_length = var.key_salt_length

      # Hash function for PBKDF2 (sha256 or sha512)
      # SHA-512 provides stronger security than SHA-256
      # Default: sha512
      hash_function = var.key_hash_function
    }

    # -------------------------------------------------------------------------
    # AES-GCM Encryption Method Configuration
    # -------------------------------------------------------------------------
    # AES-GCM (Advanced Encryption Standard - Galois/Counter Mode) provides
    # both confidentiality and authenticity. It's a widely-adopted AEAD
    # (Authenticated Encryption with Associated Data) cipher.

    method "aes_gcm" "default_method" {
      # Use the key derived from PBKDF2 key provider
      keys = key_provider.pbkdf2.generated_passphrase
    }

    # -------------------------------------------------------------------------
    # State Encryption Configuration
    # -------------------------------------------------------------------------
    # Apply encryption to the OpenTofu state file to protect sensitive data
    # such as API tokens, IP addresses, passwords, and infrastructure details.

    state {
      # Encryption method to use for state file
      method = method.aes_gcm.default_method

      # Enforce encryption (true = fail if encryption cannot be applied)
      # Set to true in production to prevent accidental plaintext state
      enforced = true
    }
  }
}


# =============================================================================
# Terraform Backend Configuration - PostgreSQL
# =============================================================================
#
# This file configures remote state storage using PostgreSQL database.
# Remote state enables team collaboration and provides state locking.
#
# Backend: pg (PostgreSQL)
# Documentation: https://opentofu.org/docs/language/settings/backends/pg/
#
# Setup Requirements:
#   1. PostgreSQL 12+ database server
#   2. Database and user with appropriate permissions
#   3. Connection string in pg.backend.conf file
#
# Database Setup (run on PostgreSQL server):
#   CREATE DATABASE terraform_state;
#   CREATE USER terraform WITH PASSWORD 'secure_password';
#   GRANT ALL PRIVILEGES ON DATABASE terraform_state TO terraform;
#
# Connection String Format (pg.backend.conf):
#   conn_str = "postgres://user:password@host:5432/database?sslmode=disable"
#
# Security Notes:
#   - Never commit pg.backend.conf to version control
#   - Use SSL/TLS in production (sslmode=require or verify-full)
#   - Restrict database access to Terraform runners only
#   - Consider using environment variable: PG_CONN_STR
#
# For Local State:
#   Comment out the entire backend block below and run:
#   tofu init -migrate-state
#
# Author: HomeLab Infrastructure
# Last Updated: December 2025
# =============================================================================

terraform {
  # PostgreSQL backend for remote state storage
  # 
  # Option 1: Use environment variable PG_CONN_STR (recommended for CI/CD)
  # Option 2: Use -backend-config=pg.backend.conf
  # Option 3: Use -backend-config="conn_str=..." on command line
  #
  # Initialize with: tofu init -backend-config=pg.backend.conf
  # Or set: export PG_CONN_STR="postgres://user:pass@host:5432/db"
  backend "pg" {
    # Schema name for state table (isolates from other projects)
    schema_name = "vm_fedora_core"
    
    # Connection string is provided via:
    # - Environment variable: PG_CONN_STR
    # - Or: -backend-config="conn_str=..."
    # - Or: pg.backend.conf file
  }
}

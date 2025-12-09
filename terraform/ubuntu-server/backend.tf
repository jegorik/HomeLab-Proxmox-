# Terraform backend configuration for PostgreSQL state storage
#
# Prerequisites:
# 1. PostgreSQL server running on LXC container
# 2. Database 'terraform_state' created
# 3. User 'terraform' with privileges on the database
# 4. Network access from this machine to PostgreSQL server
#
# Usage:
# Set the connection string via environment variable before init:
#   export PG_CONN_STR="postgres://terraform:password@<PG_HOST>:5432/terraform_state?sslmode=disable"
#   tofu init
#
# Or use -backend-config during init:
#   tofu init -backend-config="conn_str=postgres://terraform:password@<PG_HOST>:5432/terraform_state?sslmode=disable"

terraform {
  backend "pg" {
    # Connection string is provided via PG_CONN_STR environment variable
    # or via -backend-config="conn_str=..." during init
    #
    # Schema name for state storage (optional, defaults to "terraform_remote_state")
    schema_name = var.schema_name
  }
}

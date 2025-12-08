#!/usr/bin/env bash
# =============================================================================
# Ansible User Setup Script
# =============================================================================
#
# Description:
#   Creates and configures a dedicated Ansible automation user on Linux systems.
#   This script is designed to be run on target hosts to prepare them for
#   Ansible/Semaphore UI management.
#
# Features:
#   - Creates user account with SSH access
#   - Configures SSH public key authentication
#   - Sets up passwordless sudo access
#   - Supports both Debian/Ubuntu (sudo) and RHEL/CentOS (wheel) groups
#   - Idempotent - safe to run multiple times
#   - Validates all configurations after setup
#
# Usage:
#   # With default .env file in same directory:
#   sudo ./ansible_user_setup.sh
#
#   # With custom environment file:
#   sudo ./ansible_user_setup.sh /path/to/custom.env
#
#   # With environment variables:
#   ANSIBLE_USER=deploy ANSIBLE_SSH_KEY="ssh-rsa ..." sudo -E ./ansible_user_setup.sh
#
# Environment Variables (via .env file or exported):
#   ANSIBLE_USER      - Username to create (default: ansible)
#   ANSIBLE_SSH_KEY   - SSH public key for authentication (required)
#   ANSIBLE_SHELL     - User shell (default: /bin/bash)
#   ANSIBLE_SUDO      - Enable passwordless sudo (default: true)
#
# Requirements:
#   - Root or sudo privileges
#   - Bash 4.0+
#   - Standard Linux utilities (useradd, usermod, chmod, etc.)
#
# Security Notes:
#   - The .env file contains sensitive SSH keys - never commit to git
#   - Passwordless sudo is enabled by default for automation
#   - SSH key authentication is the only allowed access method
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Missing required configuration
#   3 - Permission denied (not root)
#   4 - Validation failed
#
# Author: HomeLab Infrastructure
# Version: 2.0.0
# Last Updated: December 2025
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly LOG_PREFIX="[${SCRIPT_NAME}]"

# Color codes for output (disabled if not a terminal)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}${LOG_PREFIX}${NC} [INFO] $*"
}

log_success() {
    echo -e "${GREEN}${LOG_PREFIX}${NC} [OK] $*"
}

log_warn() {
    echo -e "${YELLOW}${LOG_PREFIX}${NC} [WARN] $*" >&2
}

log_error() {
    echo -e "${RED}${LOG_PREFIX}${NC} [ERROR] $*" >&2
}

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Display usage information
show_usage() {
    cat << EOF
Usage: sudo ${SCRIPT_NAME} [OPTIONS] [ENV_FILE]

Creates and configures an Ansible automation user.

Arguments:
  ENV_FILE          Path to environment file (default: .env in script directory)

Options:
  -h, --help        Show this help message
  -v, --version     Show version information
  -d, --dry-run     Show what would be done without making changes
  -q, --quiet       Suppress non-error output

Environment Variables:
  ANSIBLE_USER      Username to create (default: ansible)
  ANSIBLE_SSH_KEY   SSH public key (required)
  ANSIBLE_SHELL     User shell (default: /bin/bash)
  ANSIBLE_SUDO      Enable passwordless sudo (default: true)

Examples:
  sudo ./ansible_user_setup.sh
  sudo ./ansible_user_setup.sh /etc/ansible/ansible.env
  ANSIBLE_USER=deploy sudo -E ./ansible_user_setup.sh

EOF
}

# Display version information
show_version() {
    echo "${SCRIPT_NAME} version 2.0.0"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 3
    fi
}

# Load environment file
load_env_file() {
    local env_file="$1"
    
    if [[ -f "${env_file}" ]]; then
        log_info "Loading configuration from: ${env_file}"
        # shellcheck source=/dev/null
        source "${env_file}"
    else
        log_warn "Environment file not found: ${env_file}"
        log_info "Using environment variables or defaults"
    fi
}

# Validate required configuration
validate_config() {
    local errors=0
    
    if [[ -z "${ANSIBLE_SSH_KEY:-}" ]]; then
        log_error "ANSIBLE_SSH_KEY is required but not set"
        errors=$((errors + 1))
    fi
    
    if [[ -n "${ANSIBLE_SSH_KEY:-}" ]] && ! [[ "${ANSIBLE_SSH_KEY}" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
        log_error "ANSIBLE_SSH_KEY does not appear to be a valid SSH public key"
        errors=$((errors + 1))
    fi
    
    if [[ ${errors} -gt 0 ]]; then
        log_error "Configuration validation failed with ${errors} error(s)"
        exit 2
    fi
    
    log_success "Configuration validated"
}

# -----------------------------------------------------------------------------
# Main Setup Functions
# -----------------------------------------------------------------------------

# Create user account
create_user() {
    local username="$1"
    local shell="$2"
    
    if id -u "${username}" >/dev/null 2>&1; then
        log_info "User '${username}' already exists"
        
        # Ensure correct shell
        if [[ "$(getent passwd "${username}" | cut -d: -f7)" != "${shell}" ]]; then
            usermod -s "${shell}" "${username}"
            log_info "Updated shell to ${shell}"
        fi
    else
        useradd -m -s "${shell}" "${username}"
        log_success "Created user '${username}'"
    fi
}

# Add user to appropriate sudo/wheel group
configure_sudo_group() {
    local username="$1"
    
    if getent group sudo >/dev/null 2>&1; then
        usermod -aG sudo "${username}"
        log_info "Added '${username}' to sudo group"
    elif getent group wheel >/dev/null 2>&1; then
        usermod -aG wheel "${username}"
        log_info "Added '${username}' to wheel group"
    else
        log_warn "Neither sudo nor wheel group found"
    fi
}

# Setup SSH directory and authorized_keys
setup_ssh_keys() {
    local username="$1"
    local ssh_key="$2"
    local home_dir
    local ssh_dir
    local auth_keys
    
    home_dir="$(getent passwd "${username}" | cut -d: -f6)"
    ssh_dir="${home_dir}/.ssh"
    auth_keys="${ssh_dir}/authorized_keys"
    
    # Create .ssh directory
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    chown "${username}:${username}" "${ssh_dir}"
    
    # Create/update authorized_keys
    touch "${auth_keys}"
    chmod 600 "${auth_keys}"
    chown "${username}:${username}" "${auth_keys}"
    
    # Add key if not already present
    if ! grep -Fxq "${ssh_key}" "${auth_keys}" 2>/dev/null; then
        printf '%s\n' "${ssh_key}" >> "${auth_keys}"
        log_success "SSH key added to ${auth_keys}"
    else
        log_info "SSH key already present in ${auth_keys}"
    fi
}

# Configure passwordless sudo
configure_sudoers() {
    local username="$1"
    local sudoers_file="/etc/sudoers.d/${username}"
    local sudoers_entry="${username} ALL=(ALL) NOPASSWD:ALL"
    local tmp_sudoers
    
    tmp_sudoers="$(mktemp)"
    
    # Write sudoers entry
    printf '%s\n' "${sudoers_entry}" > "${tmp_sudoers}"
    
    # Validate syntax
    if visudo -cf "${tmp_sudoers}" >/dev/null 2>&1; then
        mv "${tmp_sudoers}" "${sudoers_file}"
        chmod 0440 "${sudoers_file}"
        chown root:root "${sudoers_file}"
        log_success "Sudoers configured at ${sudoers_file}"
    else
        log_error "Sudoers syntax validation failed"
        rm -f "${tmp_sudoers}"
        return 1
    fi
}

# Verify all configurations
verify_setup() {
    local username="$1"
    local ssh_key="$2"
    local errors=0
    local home_dir
    local auth_keys
    local sudoers_file
    
    home_dir="$(getent passwd "${username}" | cut -d: -f6)"
    auth_keys="${home_dir}/.ssh/authorized_keys"
    sudoers_file="/etc/sudoers.d/${username}"
    
    log_info "Verifying setup..."
    
    # Check user exists
    if id -u "${username}" >/dev/null 2>&1; then
        log_success "User '${username}' exists"
    else
        log_error "User '${username}' not found"
        errors=$((errors + 1))
    fi
    
    # Check SSH key
    if [[ -f "${auth_keys}" ]] && grep -Fxq "${ssh_key}" "${auth_keys}" 2>/dev/null; then
        log_success "SSH key present in authorized_keys"
    else
        log_error "SSH key not found in authorized_keys"
        errors=$((errors + 1))
    fi
    
    # Check sudoers
    if [[ -f "${sudoers_file}" ]] && visudo -cf "${sudoers_file}" >/dev/null 2>&1; then
        log_success "Sudoers file valid"
    else
        log_error "Sudoers file missing or invalid"
        errors=$((errors + 1))
    fi
    
    # Check SSH directory permissions
    if [[ "$(stat -c '%a' "${home_dir}/.ssh" 2>/dev/null)" == "700" ]]; then
        log_success "SSH directory permissions correct (700)"
    else
        log_error "SSH directory permissions incorrect"
        errors=$((errors + 1))
    fi
    
    if [[ ${errors} -gt 0 ]]; then
        log_error "Verification failed with ${errors} error(s)"
        return 4
    fi
    
    log_success "All verifications passed"
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------

main() {
    local env_file="${SCRIPT_DIR}/.env"
    local dry_run=false
    local quiet=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                env_file="$1"
                shift
                ;;
        esac
    done
    
    # Check root privileges
    check_root
    
    # Load configuration
    load_env_file "${env_file}"
    
    # Set defaults
    local username="${ANSIBLE_USER:-ansible}"
    local ssh_key="${ANSIBLE_SSH_KEY:-}"
    local shell="${ANSIBLE_SHELL:-/bin/bash}"
    local enable_sudo="${ANSIBLE_SUDO:-true}"
    
    # Validate configuration
    validate_config
    
    # Show configuration (unless quiet)
    if [[ "${quiet}" != "true" ]]; then
        log_info "Configuration:"
        log_info "  Username: ${username}"
        log_info "  Shell: ${shell}"
        log_info "  Sudo: ${enable_sudo}"
        log_info "  SSH Key: ${ssh_key:0:50}..."
    fi
    
    # Dry run mode
    if [[ "${dry_run}" == "true" ]]; then
        log_warn "Dry run mode - no changes will be made"
        exit 0
    fi
    
    # Execute setup
    log_info "Starting Ansible user setup..."
    
    create_user "${username}" "${shell}"
    
    if [[ "${enable_sudo}" == "true" ]]; then
        configure_sudo_group "${username}"
        configure_sudoers "${username}"
    fi
    
    setup_ssh_keys "${username}" "${ssh_key}"
    
    # Verify setup
    verify_setup "${username}" "${ssh_key}"
    
    log_success "Ansible user setup completed successfully!"
    log_info "Test with: ssh ${username}@$(hostname -I | awk '{print $1}')"
}

# Run main function
main "$@"

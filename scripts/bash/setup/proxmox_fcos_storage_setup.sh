#!/usr/bin/env bash
# ==============================================================================
# Proxmox VE - Fedora CoreOS Storage Setup
# ==============================================================================
#
# This script prepares Proxmox VE for Fedora CoreOS VM deployment by:
# 1. Creating a dedicated storage directory for FCOS images and Ignition configs
# 2. Registering the storage in Proxmox VE
# 3. Downloading the latest Fedora CoreOS image
#
# USAGE:
#   Run directly on Proxmox VE host as root:
#     bash proxmox_fcos_storage_setup.sh
#
#   Or remotely via SSH:
#     ssh root@proxmox-host 'bash -s' < proxmox_fcos_storage_setup.sh
#
#   Dry-run mode (preview changes without making them):
#     bash proxmox_fcos_storage_setup.sh --dry-run
#
# Based on official Fedora CoreOS documentation:
# https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-proxmoxve/
#
# Author: jegorik
# Last Updated: December 2025
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

STORAGE_NAME="${STORAGE_NAME:-coreos}"
STORAGE_PATH="${STORAGE_PATH:-/var/coreos}"
FCOS_STREAM="${FCOS_STREAM:-stable}"
SKIP_IMAGE_DOWNLOAD="${SKIP_IMAGE_DOWNLOAD:-false}"
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_dry_run() {
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
}

execute_command() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would execute: $*"
        return 0
    else
        "$@"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_proxmox() {
    if ! command -v pvesm &> /dev/null; then
        log_error "pvesm command not found. Is this a Proxmox VE host?"
        exit 1
    fi
}

# ==============================================================================
# MAIN FUNCTIONS
# ==============================================================================

create_storage_directory() {
    log_info "Creating Fedora CoreOS storage directory structure..."
    
    if [[ -d "$STORAGE_PATH" ]]; then
        log_warning "Directory $STORAGE_PATH already exists"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would create: $STORAGE_PATH/{images,snippets}"
        else
            mkdir -p "$STORAGE_PATH"/{images,snippets}
            log_success "Created $STORAGE_PATH with subdirectories: images, snippets"
        fi
    fi
    
    # Set proper permissions
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would set permissions: chmod 755 on $STORAGE_PATH and subdirectories"
    else
        chmod 755 "$STORAGE_PATH"
        chmod 755 "$STORAGE_PATH/images"
        chmod 755 "$STORAGE_PATH/snippets"
    fi
}

register_storage_in_proxmox() {
    log_info "Registering storage in Proxmox VE..."
    
    # Check if storage already exists
    if pvesm status | grep -q "^$STORAGE_NAME"; then
        log_warning "Storage '$STORAGE_NAME' already registered in Proxmox"
        log_info "Current configuration:"
        pvesm status | grep "^$STORAGE_NAME"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would execute: pvesm add dir $STORAGE_NAME --path $STORAGE_PATH --content images,snippets"
        else
            pvesm add dir "$STORAGE_NAME" --path "$STORAGE_PATH" --content images,snippets
            log_success "Storage '$STORAGE_NAME' registered successfully"
            log_info "Storage details:"
            pvesm status | grep "^$STORAGE_NAME"
        fi
    fi
}

download_fcos_image() {
    if [[ "$SKIP_IMAGE_DOWNLOAD" == "true" ]]; then
        log_info "Skipping Fedora CoreOS image download (SKIP_IMAGE_DOWNLOAD=true)"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Downloading Fedora CoreOS image (stream: $FCOS_STREAM)..."
    fi
    
    # Check if coreos-installer is available
    if command -v coreos-installer &> /dev/null; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would execute: coreos-installer download -s $FCOS_STREAM -p proxmoxve -f qcow2.xz --decompress -C $STORAGE_PATH/images"
        else
            log_info "Using coreos-installer binary"
            coreos-installer download \
                -s "$FCOS_STREAM" \
                -p proxmoxve \
                -f qcow2.xz \
                --decompress \
                -C "$STORAGE_PATH/images"
        fi
    elif command -v podman &> /dev/null; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would execute: podman run --pull=always --rm -v $STORAGE_PATH/images:/data quay.io/coreos/coreos-installer:release download -s $FCOS_STREAM -p proxmoxve -f qcow2.xz --decompress"
        else
            log_info "Using coreos-installer via podman"
            podman run --pull=always --rm \
                -v "$STORAGE_PATH/images:/data" -w /data \
                quay.io/coreos/coreos-installer:release \
                download -s "$FCOS_STREAM" -p proxmoxve -f qcow2.xz --decompress
        fi
    elif command -v docker &> /dev/null; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would execute: docker run --pull=always --rm -v $STORAGE_PATH/images:/data quay.io/coreos/coreos-installer:release download -s $FCOS_STREAM -p proxmoxve -f qcow2.xz --decompress"
        else
            log_info "Using coreos-installer via docker"
            docker run --pull=always --rm \
                -v "$STORAGE_PATH/images:/data" -w /data \
                quay.io/coreos/coreos-installer:release \
                download -s "$FCOS_STREAM" -p proxmoxve -f qcow2.xz --decompress
        fi
    else
        log_error "Neither coreos-installer nor podman/docker found"
        log_error "Install one of them to download FCOS images"
        log_info "Alternatively, download manually from:"
        log_info "https://fedoraproject.org/coreos/download/"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log_success "Fedora CoreOS image downloaded successfully"
        log_info "Images in $STORAGE_PATH/images:"
        ls -lh "$STORAGE_PATH/images/"
    fi
}

display_summary() {
    echo ""
    echo "========================================================================"
    echo "  Fedora CoreOS Storage Setup Complete"
    echo "========================================================================"
    echo "  Storage Name: $STORAGE_NAME"
    echo "  Storage Path: $STORAGE_PATH"
    echo "  Stream:       $FCOS_STREAM"
    echo "========================================================================"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy VM using OpenTofu/Terraform:"
    echo "     cd terraform/fedora_core && tofu apply"
    echo ""
    echo "  2. OpenTofu will automatically:"
    echo "     - Upload Ignition config to $STORAGE_PATH/snippets/"
    echo "     - Create VM with Cloud-Init pointing to Ignition"
    echo "     - Start VM (Ignition applies on first boot)"
    echo ""
    echo "  3. Access VM after boot:"
    echo "     ssh core@<vm-ip-address>"
    echo "========================================================================"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                DRY_RUN=true
                log_warning "DRY-RUN MODE: No changes will be made"
                shift
                ;;
            --help|-h)
                cat << EOF
Proxmox VE - Fedora CoreOS Storage Setup

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run, -n    Preview changes without making them
    --help, -h       Show this help message

ENVIRONMENT VARIABLES:
    STORAGE_NAME            Storage name in Proxmox (default: coreos)
    STORAGE_PATH            Storage path on filesystem (default: /var/coreos)
    FCOS_STREAM             FCOS stream to download (default: stable)
    SKIP_IMAGE_DOWNLOAD     Skip image download (default: false)

EXAMPLES:
    # Normal execution
    $0

    # Dry-run mode
    $0 --dry-run

    # Custom storage name
    STORAGE_NAME=fcos $0

    # Skip image download
    SKIP_IMAGE_DOWNLOAD=true $0
EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    log_info "Starting Proxmox VE Fedora CoreOS storage setup..."
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
    fi
    
    # Pre-flight checks
    check_root
    check_proxmox
    
    # Execute setup steps
    create_storage_directory
    register_storage_in_proxmox
    download_fcos_image
    
    # Display summary
    display_summary
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY-RUN MODE: No actual changes were made"
    else
        log_success "Setup completed successfully!"
    fi
}

# Run main function
main "$@"

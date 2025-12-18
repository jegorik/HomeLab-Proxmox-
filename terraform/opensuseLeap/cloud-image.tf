# =============================================================================
# Cloud Image Download Configuration
# =============================================================================
# This file handles the automatic download of openSUSE Leap 15.6 cloud image
# to Proxmox storage. The cloud image is a pre-built, minimal OS installation
# designed for cloud-init automated provisioning.
#
# Download Behavior:
# - Image is downloaded only if var.cloud_image_download = true
# - Download is skipped if file already exists (overwrite = false)
# - Checksum verification ensures image integrity
# - 30-minute timeout accommodates slow network connections
#
# Cloud Image vs ISO:
# - Cloud Image: Pre-installed OS, boots immediately, cloud-init ready
# - ISO: Requires manual installation, no cloud-init by default
# - Use cloud image for automated infrastructure deployment
# - Use ISO for custom installations or non-cloud-init setups
#
# Image Location in Proxmox:
# - Default: /var/lib/vz/template/import/
# - Storage: Specified by vm_cloud_image_datastore_id (usually "local")
# - Format: qcow2 (QEMU Copy-On-Write disk image)
#
# Checksum Verification:
# - Ensures downloaded image matches official release
# - Protects against corrupted downloads or tampering
# - SHA256 is cryptographically secure hash algorithm
# - Get latest checksum: https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/
#
# Updating Cloud Image:
# 1. Check for new version at openSUSE repository
# 2. Update cloud_image_checksum in terraform.tfvars
# 3. Delete old image from Proxmox or set overwrite = true
# 4. Run: tofu apply -replace=proxmox_virtual_environment_download_file.opensuse_cloud_image
#
# Troubleshooting:
# - "download failed": Check network connectivity and URL accessibility
# - "checksum mismatch": Verify checksum value, check for corrupted download
# - "timeout": Increase upload_timeout or check network speed
# - "storage full": Free up space on Proxmox storage
# - "permission denied": Check Proxmox API token permissions
# =============================================================================

resource "proxmox_virtual_environment_download_file" "opensuse_cloud_image" {
  count = var.cloud_image_download ? 1 : 0

  # Content type for cloud images (imported disk images)
  content_type = "import"
  datastore_id = var.vm_cloud_image_datastore_id
  node_name    = var.proxmox_node_name

  # Download source from official openSUSE repository
  # URL: https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/
  url       = var.cloud_image_url
  file_name = var.cloud_image_file_name

  # Don't re-download if file already exists in Proxmox storage
  # Set to true to force re-download (e.g., for image updates)
  overwrite = false

  # Verification and timeout settings
  checksum           = var.cloud_image_checksum           # SHA256 hash for verification
  checksum_algorithm = var.cloud_image_checksum_algorithm # Usually "sha256"
  verify             = true                               # Enable checksum verification
  upload_timeout     = 1800                               # 30 minutes (sufficient for slow connections)

  # Prevent resource recreation if checksum variable changes
  # This avoids unnecessary re-downloads when updating configuration
  # To force update: manually delete image or use -replace flag
  lifecycle {
    ignore_changes = [checksum]
  }
}

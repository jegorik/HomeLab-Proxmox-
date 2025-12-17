# =============================================================================
# Cloud Image Download Configuration
# =============================================================================
# This file handles the automatic download of openSUSE Leap 15.6 cloud image
# to Proxmox storage. The image is downloaded only if:
# - var.cloud_image_download = true
# - The image doesn't already exist in Proxmox storage (overwrite = false)
# =============================================================================

resource "proxmox_virtual_environment_download_file" "opensuse_cloud_image" {
  count = var.cloud_image_download ? 1 : 0

  # Content type for cloud images
  content_type = "iso"
  datastore_id = var.vm_disk_datastore_id
  node_name    = var.proxmox_node_name

  # Download source
  url       = var.cloud_image_url
  file_name = "openSUSE-Leap-15.6-NoCloud.qcow2.img"

  # Don't re-download if file exists
  overwrite = false

  # Verification and timeouts
  checksum           = var.cloud_image_checksum
  checksum_algorithm = var.cloud_image_checksum_algorithm
  verify             = true
  upload_timeout     = 1800  # 30 minutes

  # Prevent resource recreation if hash changes
  lifecycle {
    ignore_changes = [checksum]
  }
}

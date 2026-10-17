packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.7, < 2.0.0"
    }
  }
}

# Azure Marketplace has no first-party Alpine image, so the Alpine VM image is
# built with the qemu builder from the official Alpine "virt" ISO and applied
# with scripts/vm/harden-alpine.sh. Alpine has no CIS SCAP Security Guide
# content, so there is no OpenSCAP gate for Alpine (see docs/CIS-COMPLIANCE.md).
#
# NOTE: an unattended Alpine install needs a boot_command + http/ answerfile
# (setup-alpine). Provide those for your environment; the source below is the
# hardening-ready skeleton.

variable "iso_url" {
  default = "https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-virt-3.24.2-x86_64.iso"
}
variable "iso_checksum" {
  # Pinned (not fetched from the same server as the ISO). Bump with iso_url.
  default = "sha256:3ab424762af704b2c2a9e57df1dc37f982af260071504d977f2fb96822e7130b"
}
variable "output_dir" { default = "output-alpine" }
# Transient credential for the throwaway build VM only — never baked into the
# produced image.
variable "build_password" {
  default   = "packerbuild"
  sensitive = true
}

source "qemu" "alpine" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = var.output_dir
  disk_size        = "4096M"
  format           = "qcow2"
  accelerator      = "kvm"
  headless         = true
  ssh_username     = "root"
  ssh_password     = var.build_password
  ssh_timeout      = "20m"
  shutdown_command = "poweroff"
}

build {
  sources = ["source.qemu.alpine"]

  provisioner "file" {
    source      = "../scripts/vm"
    destination = "/tmp"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/vm/*.sh",
      "echo '== CIS host hardening (Alpine) =='",
      "/tmp/vm/harden-alpine.sh"
    ]
  }
}

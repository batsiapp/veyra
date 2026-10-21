#!/usr/bin/env bash
# One-time preparation of a fresh Ubuntu or Debian VPS for Veyra.
# Adds swap (a 1 GB machine needs it), installs Docker, and turns on the
# firewall with only SSH allowed in. Run as root or with sudo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run with sudo" >&2
  exit 1
fi

SWAP_GB="${SWAP_GB:-2}"
if ! swapon --show | grep -q .; then
  echo "adding ${SWAP_GB} GB swap at /swapfile"
  fallocate -l "${SWAP_GB}G" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  sysctl -w vm.swappiness=10
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-veyra-swap.conf
else
  echo "swap already present"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "installing Docker"
  curl -fsSL https://get.docker.com | sh
else
  echo "Docker already installed"
fi
systemctl enable --now docker

TARGET_USER="${SUDO_USER:-}"
if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != root ]; then
  usermod -aG docker "$TARGET_USER"
  echo "added $TARGET_USER to the docker group (log out and back in)"
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH
  ufw --force enable
  echo "firewall on: only SSH is allowed in"
fi

# The clock matters for trading sessions and the news calendar.
timedatectl set-ntp true 2>/dev/null || true
echo "VPS ready."

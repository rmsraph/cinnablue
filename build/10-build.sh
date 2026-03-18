#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
shopt -s nullglob
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
shopt -u nullglob

echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >>/usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Install Graphics Stack"

# Install session/graphics compatibility packages when available.
graphics_pkgs=()
for pkg in \
	xorg-x11-server-Xorg \
	xorg-x11-server-Xwayland \
	xorg-x11-drivers \
	xorg-x11-xinit \
	xorg-x11-xauth \
	xorg-x11-xrandr \
	xorg-x11-xkb-utils \
	mesa-dri-drivers \
	mesa-vulkan-drivers \
	vulkan-loader \
	gnome-terminal \
	network-manager-applet \
	policycoreutils-python-utils; do
	if dnf5 list --available "$pkg" >/dev/null 2>&1; then
		graphics_pkgs+=("$pkg")
	fi
done

if ((${#graphics_pkgs[@]})); then
	dnf5 install -y "${graphics_pkgs[@]}"
fi

echo "::endgroup::"

echo "::group:: Ensure UEFI Boot Artifacts"

# bootc-image-builder infers the UEFI vendor from shim/EFI paths inside
# the source image. Ensure the architecture-specific UEFI packages exist
# so ARM64 ISO builds don't fail with missing UEFI vendor.
uefi_pkgs=()
arch="$(uname -m)"

if [[ "$arch" == "aarch64" ]]; then
	for pkg in \
		shim-aa64 \
		grub2-efi-aa64 \
		grub2-efi-aa64-modules; do
		if dnf5 list --available "$pkg" >/dev/null 2>&1; then
			uefi_pkgs+=("$pkg")
		fi
	done
elif [[ "$arch" == "x86_64" ]]; then
	for pkg in \
		shim-x64 \
		grub2-efi-x64 \
		grub2-efi-x64-modules; do
		if dnf5 list --available "$pkg" >/dev/null 2>&1; then
			uefi_pkgs+=("$pkg")
		fi
	done
fi

if ((${#uefi_pkgs[@]})); then
	dnf5 install -y "${uefi_pkgs[@]}"
fi

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl set-default graphical.target
# Example: systemctl mask unwanted-service

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"

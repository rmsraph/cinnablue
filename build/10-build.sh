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
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

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

echo "::group:: Install Cinnamon Desktop Environment"
# Install Cinnamon desktop environment and related packages

# Install Cinnamon from comps group when available (pulls desktop dependencies).
if dnf5 group info "Cinnamon Desktop" >/dev/null 2>&1; then
	dnf5 group install -y "Cinnamon Desktop"
elif dnf5 group info cinnamon-desktop-environment >/dev/null 2>&1; then
	dnf5 group install -y cinnamon-desktop-environment
else
	# Fallback package set if comps metadata/group names differ.
	dnf5 install -y \
		cinnamon \
		cinnamon-control-center \
		cinnamon-screensaver \
		cinnamon-session \
		cinnamon-settings-daemon \
		cinnamon-desktop \
		nemo \
		muffin \
		xed \
		xreader \
		xviewer \
		lightdm \
		slick-greeter
fi

# Ensure a login manager exists even if the comps group did not pull one.
dnf5 install -y lightdm slick-greeter

echo "::endgroup::"

echo "::group:: Install Packages"

# Install packages using dnf5
# Example: dnf5 install -y tmux

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable lightdm.service
systemctl set-default graphical.target
# Example: systemctl mask unwanted-service

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"

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

echo "::group:: Install Packages"

install_if_available() {
	local package_name="$1"
	if dnf5 repoquery --available "$package_name" >/dev/null 2>&1; then
		dnf5 install -y "$package_name"
		return 0
	fi
	return 1
}

# Refresh repository metadata and GPG keys to avoid transient signature failures
dnf5 clean all
rm -rf /var/cache/libdnf5/*
dnf5 makecache --refresh
rpm --import /etc/pki/rpm-gpg/* || true

# Install Cinnamon desktop environment
echo "Installing Cinnamon desktop..."

dnf5 install -y \
	cinnamon \
	cinnamon-control-center \
	cinnamon-screensaver \
	cinnamon-session \
	nemo \
	lightdm

echo "Cinnamon desktop installed"

# Install Linux Mint theme and icons
echo "Installing Linux Mint theme and icons..."

if ! install_if_available mint-themes; then
	tmp_mint_themes="$(mktemp -d)"
	curl -fsSL https://github.com/linuxmint/mint-themes/archive/refs/heads/master.tar.gz | tar -xzf - -C "$tmp_mint_themes"
	if [ -d "$tmp_mint_themes/mint-themes-main/usr/share/themes" ]; then
		cp -r "$tmp_mint_themes/mint-themes-main/usr/share/themes/"* /usr/share/themes/
	elif [ -d "$tmp_mint_themes/mint-themes-main/files/usr/share/themes" ]; then
		cp -r "$tmp_mint_themes/mint-themes-main/files/usr/share/themes/"* /usr/share/themes/
	fi
	rm -rf "$tmp_mint_themes"
fi

if ! install_if_available mint-y-icons; then
	tmp_mint_icons="$(mktemp -d)"
	curl -fsSL https://github.com/linuxmint/mint-y-icons/archive/refs/heads/master.tar.gz | tar -xzf - -C "$tmp_mint_icons"
	if [ -d "$tmp_mint_icons/mint-y-icons-main/usr/share/icons" ]; then
		cp -r "$tmp_mint_icons/mint-y-icons-main/usr/share/icons/"Mint-Y* /usr/share/icons/
	fi
	rm -rf "$tmp_mint_icons"
fi

echo "Linux Mint theme and icons installed"

# Install Bibata Modern Classic (black) cursor
echo "Installing Bibata cursor..."

if ! install_if_available bibata-cursor-themes; then
	copr_install_isolated "peterwu/rendezvous" bibata-cursor-themes
fi

echo "Bibata cursor installed"

# Install Linux Mint wallpaper
echo "Installing Linux Mint wallpaper..."

mkdir -p /usr/share/backgrounds/cinablue
MINT_WALLPAPER_PATH=""

if install_if_available mint-backgrounds; then
	MINT_WALLPAPER_PATH="$(find /usr/share/backgrounds -type f \( -iname '*mint*.jpg' -o -iname '*mint*.jpeg' -o -iname '*mint*.png' \) | head -n 1 || true)"
fi

if [ -z "$MINT_WALLPAPER_PATH" ]; then
	tmp_mint_backgrounds="$(mktemp -d)"
	curl -fsSL https://github.com/linuxmint/mint-backgrounds/archive/refs/heads/master.tar.gz | tar -xzf - -C "$tmp_mint_backgrounds"
	MINT_WALLPAPER_SOURCE="$(find "$tmp_mint_backgrounds" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | head -n 1 || true)"
	if [ -n "$MINT_WALLPAPER_SOURCE" ]; then
		cp "$MINT_WALLPAPER_SOURCE" /usr/share/backgrounds/cinablue/linux-mint.jpg
		MINT_WALLPAPER_PATH="/usr/share/backgrounds/cinablue/linux-mint.jpg"
	fi
	rm -rf "$tmp_mint_backgrounds"
fi

echo "Linux Mint wallpaper installed"

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable lightdm.service
systemctl set-default graphical.target

# Set Cinnamon defaults (theme, icon, cursor, wallpaper)
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-cinnamon-defaults << EOF
[org/cinnamon/theme]
name='Mint-Y'

[org/cinnamon/desktop/interface]
gtk-theme='Mint-Y'
icon-theme='Mint-Y'
cursor-theme='Bibata-Modern-Classic'

[org/cinnamon/desktop/background]
picture-uri='file://${MINT_WALLPAPER_PATH:-/usr/share/backgrounds/cinablue/linux-mint.jpg}'
picture-options='zoom'
EOF
dconf update
# Example: systemctl mask unwanted-service

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"

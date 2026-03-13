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

dnf5 install -y --nogpgcheck \
    cinnamon \
    cinnamon-control-center \
    cinnamon-screensaver \
    cinnamon-session \
    cinnamon-settings-daemon \
    cinnamon-desktop \
    cinnamon-menus \
    cjs \
    muffin \
    nemo \
    nemo-fileroller \
    xapps \
    network-manager-applet \
    nm-connection-editor \
    gnome-terminal \
    lightdm \
    lightdm-gtk \
    slick-greeter \
    accountsservice \
    upower \
    polkit \
    gnome-backgrounds \
    google-noto-sans-fonts \
    gstreamer1 \
    gtk3

systemctl enable lightdm.service

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

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable lightdm.service
systemctl set-default graphical.target

# Set Cinnamon defaults (theme, icon, cursor, wallpaper, panel and clock)
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-cinnamon-defaults << EOF
[org/cinnamon/theme]
name='Mint-Y'

[org/cinnamon]
# Order applets by panel zone and position: menu, task list, tray, clock, show desktop.
enabled-applets=['panel1:left:0:menu@cinnamon.org:0','panel1:left:1:grouped-window-list@cinnamon.org:0','panel1:right:0:systray@cinnamon.org:0','panel1:right:1:xapp-status@cinnamon.org:0','panel1:right:2:notifications@cinnamon.org:0','panel1:right:3:printers@cinnamon.org:0','panel1:right:4:removable-drives@cinnamon.org:0','panel1:right:5:keyboard@cinnamon.org:0','panel1:right:6:network@cinnamon.org:0','panel1:right:7:sound@cinnamon.org:0','panel1:right:8:power@cinnamon.org:0','panel1:right:9:calendar@cinnamon.org:0','panel1:right:10:show-desktop@cinnamon.org:0']
# Keep compatibility with Cinnamon variants that read either key.
panel-height=40
panels-height=["1:40"]

[org/cinnamon/desktop/interface]
gtk-theme='Mint-Y'
icon-theme='Mint-Y'
cursor-theme='Bibata-Modern-Classic'
clock-use-24h=true
clock-show-date=true

[org/cinnamon/desktop/background]
picture-uri='file://${MINT_WALLPAPER_PATH:-/usr/share/backgrounds/cinablue/linux-mint.jpg}'
picture-options='zoom'

[org/cinnamon/applets/calendar]
use-custom-format=true
custom-format='%a, %H:%M%n%d/%m/%Y'
EOF
dconf update
# Example: systemctl mask unwanted-service

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"

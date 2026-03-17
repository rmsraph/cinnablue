#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source /ctx/build/copr-helpers.sh

echo "::group:: Remove GNOME Desktop"

# Remove GNOME Shell and related packages
dnf5 remove -y \
    gnome-shell \
    gnome-shell-extension* \
    gnome-software \
    gnome-control-center \
    nautilus \
    gdm

echo "GNOME desktop removed"
echo "::endgroup::"

echo "::group:: Install Cinnamon Desktop"

# Install Cinnamon desktop from System76's COPR
# Using isolated pattern to prevent COPR from persisting
copr_install_isolated "leigh123linux/cinnamon-6.6.x" \
    cinnamon \
    cinnamon-session \
    cinnamon-desktop \
    cinnamon-settings-daemon \
    nemo \
    muffin \
    lightdm \
    slick-greeter \
    cinnamon-control-center \
	cinnamon-screensaver \
	xed \
	xreader \
    mint-themes \
    mint-y-icons

echo "Cinnamon desktop installed successfully"
echo "::endgroup::"

echo "::group:: Configure Display Manager"

# Enable LightDM as display manager for Cinnamon
systemctl enable lightdm.service

# Set Cinnamon as default session
mkdir -p /etc/X11/sessions
cat > /etc/X11/sessions/cinnamon.desktop << 'CINNAMONDESKTOP'
[Desktop Entry]
Name=Cinnamon
Comment=Cinnamon Desktop Environment
Exec=cinnamon-session
Type=Application
DesktopNames=Cinnamon
CINNAMONDESKTOP

echo "Display manager configured"
echo "::endgroup::"

echo "::group:: Install Additional Utilities"

# Install additional utilities that work well with Cinnamon
dnf5 install -y \
    kitty \
    xdg-desktop-portal-xapp

echo "Additional utilities installed"
echo "::endgroup::"

echo "Cinnamon desktop installation complete!"
echo "After booting, select 'Cinnamon' session at the login screen"

echo "Custom build complete!"
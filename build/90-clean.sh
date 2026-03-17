#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Final Cleanup"

# Clean dnf metadata and caches to avoid persisting transient package manager state.
dnf5 clean all
rm -rf /var/cache/dnf/*
rm -rf /var/lib/dnf/repos/*

# Remove runtime-only paths that should be empty in the final image.
rm -rf /run/dnf
rm -rf /run/systemd/resolve
rm -rf /tmp/*

# Drop generated xkb artifact reported by bootc lint when present.
rm -f /var/lib/xkb/README.compiled
rmdir --ignore-fail-on-non-empty /var/lib/xkb || true

echo "::endgroup::"

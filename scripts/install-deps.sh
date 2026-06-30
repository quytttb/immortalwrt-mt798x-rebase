#!/bin/bash
# Install build dependencies for ImmortalWrt (Ubuntu/Debian).
# Used by GitHub Actions CI and for local first-time setup.
#
# Usage (from repo root):
#   bash scripts/install-deps.sh
#
# Requires sudo on systems where apt-get needs elevated privileges (CI and most
# local Ubuntu/Debian installs). Run once before your first build.

set -euo pipefail

APT_GET=(apt-get)
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  APT_GET=(sudo apt-get)
fi

"${APT_GET[@]}" update
"${APT_GET[@]}" install -y \
  build-essential clang flex bison g++ gawk gettext git \
  libncurses5-dev libssl-dev python3 python3-setuptools \
  rsync unzip zlib1g-dev file wget curl libelf-dev \
  subversion swig time

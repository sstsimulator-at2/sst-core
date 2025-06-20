#!/bin/bash

# install_os_level_dependencies.sh: Install dependencies at the operating
# system level needed for GitHub Actions CI runs.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
if command -v brew; then
    brew install \
         autoconf \
         automake \
         coreutils \
         doxygen \
         libtool \
         ncurses \
         open-mpi \
         pygments
    python -m pip install blessings
elif command -v apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get -y update
    sudo apt-get -y install \
         autoconf \
         automake \
         doxygen \
         libopenmpi-dev \
         libtool-bin \
         python3-blessings \
         python3-pygments
elif command -v pacman >/dev/null 2>&1; then
    pacman -Syu --noconfirm
    pacman -S --noconfirm \
           python \
           python-blessings
fi

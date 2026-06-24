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
elif command -v dnf; then
    dnf -y upgrade
    dnf -y install \
        gcc-c++ \
        libtool \
        openmpi \
        python39-devel
    if [[ -f "${GITHUB_PATH}" ]]; then
        if [[ -d "/usr/lib64/openmpi/bin" ]]; then
            echo "/usr/lib64/openmpi/bin" >> "${GITHUB_PATH}"
        fi
    fi
elif command -v apt-get; then
    apt-get -y update
    apt-get -y install \
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
           autoconf \
           automake \
           gcc \
           make \
           ncurses \
           openmpi \
           python \
           wget
fi

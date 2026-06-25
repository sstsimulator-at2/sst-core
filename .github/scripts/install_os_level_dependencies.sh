#!/bin/bash

# install_os_level_dependencies.sh: Install dependencies at the operating
# system level needed for GitHub Actions CI runs.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
if command -v brew >/dev/null 2>&1; then
    brew install \
         autoconf \
         automake \
         ccache \
         coreutils \
         doxygen \
         libtool \
         ncurses \
         open-mpi \
         pygments
    python -m pip install blessings
elif command -v dnf >/dev/null 2>&1; then
    dnf -y upgrade
    dnf -y install \
        'dnf-command(config-manager)' \
        file \
        gcc-c++ \
        libtool \
        libtool-ltdl-devel \
        make \
        ncurses-devel \
        openmpi \
        python39-devel \
        zlib-devel
    dnf -y config-manager --set-enabled powertools
    dnf -y install epel-release
    dnf -y install ccache
    if [[ -f "${GITHUB_PATH}" ]]; then
        if [[ -d "/usr/lib64/openmpi/bin" ]]; then
            echo "/usr/lib64/openmpi/bin" >> "${GITHUB_PATH}"
        fi
    fi
elif command -v apt-get >/dev/null 2>&1; then
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
           ccache \
           gcc \
           make \
           ncurses \
           openmpi \
           python \
           wget
fi

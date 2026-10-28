#!/usr/bin/env bash

# install-os-level-dependencies.sh: Install dependencies at the operating
# system level needed for GitHub Actions CI runs.
#
# Set SST_INSTALL_CLANG=1 to also install Clang from the distribution.
#
# With SST_DEPS=all (the default), also install the third-party dependencies
# that build-options.bash asks configure for; with SST_DEPS=none, do not.

set -euo pipefail

# Doxygen and bzip3 are for `make dist`.

case "${SST_DEPS:-all}" in
    all) deps=1 ;;
    none) deps=0 ;;
    *)
        echo "SST_DEPS must be all or none, not ${SST_DEPS}" >&2
        exit 1
        ;;
esac

export DEBIAN_FRONTEND=noninteractive
if command -v brew; then
    packages=(
        autoconf
        automake
        coreutils
        doxygen
        libtool
        ncurses
        ccache
        open-mpi
        pygments
    )
    # macOS has zlib.  The SST python is the one of actions/setup-python,
    # so numpy comes from pip.
    if [[ "${deps}" -eq 1 ]]; then
        packages+=(hdf5 pkgconf)
    fi
    brew install "${packages[@]}"
    python -m pip install blessings
    if [[ "${deps}" -eq 1 ]]; then
        python -m pip install numpy
    fi
elif command -v dnf; then
    # shellcheck source=/dev/null
    el_major="$(. /etc/os-release && echo "${VERSION_ID%%.*}")"
    dnf -y upgrade
    # ccache comes from EPEL, which needs PowerTools/CRB for its
    # dependencies.
    dnf -y install 'dnf-command(config-manager)'
    if [[ "${el_major}" -eq 8 ]]; then
        dnf -y config-manager --set-enabled powertools
    else
        dnf -y config-manager --set-enabled crb
    fi
    dnf -y install epel-release
    packages=(
        autoconf
        automake
        bzip2
        ccache
        diffutils
        doxygen
        gcc-c++
        gzip
        libtool
        libtool-ltdl-devel
        make
        ncurses-devel
        openmpi
        openmpi-devel
        procps-ng
        tar
        wget
        which
    )
    if [[ "${el_major}" -eq 8 ]]; then
        packages+=(python39-devel)
    else
        packages+=(python3-devel)
    fi
    if [[ "${deps}" -eq 1 ]]; then
        # hdf5-devel is in EPEL, and has the C++ library that core needs.
        packages+=(hdf5-devel pkgconf-pkg-config zlib-devel)
        if [[ "${el_major}" -eq 8 ]]; then
            packages+=(python39-numpy)
        else
            packages+=(python3-numpy)
        fi
    fi
    if [[ "${SST_INSTALL_CLANG:-0}" == "1" ]]; then
        packages+=(clang)
    fi
    dnf -y install "${packages[@]}"
    if [[ -f "${GITHUB_PATH}" ]]; then
        if [[ -d "/usr/lib64/openmpi/bin" ]]; then
            echo "/usr/lib64/openmpi/bin" >> "${GITHUB_PATH}"
        fi
    fi
elif command -v apt-get; then
    packages=(
        autoconf
        automake
        build-essential
        ccache
        doxygen
        file
        libltdl-dev
        libncurses-dev
        libopenmpi-dev
        libtool-bin
        openmpi-bin
        python3-dev
        python3-pygments
        wget
    )
    if [[ "${deps}" -eq 1 ]]; then
        packages+=(libhdf5-dev pkg-config python3-numpy zlib1g-dev)
    fi
    if [[ "${SST_INSTALL_CLANG:-0}" == "1" ]]; then
        packages+=(clang)
    fi
    apt-get -y update
    # blessings is optional (colored test output).  Ubuntu 26.04 does not
    # have it.
    if apt-cache show python3-blessings >/dev/null 2>&1; then
        packages+=(python3-blessings)
    fi
    apt-get -y install "${packages[@]}"
fi

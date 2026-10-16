#!/bin/bash

# build-elements-autotools.sh: Compile and install elements with the
# Autotools build system, into the core that build-core-autotools.sh
# installed, in the configuration that build-options.bash reads from the
# environment (SST_MPI, SST_DEBUG_OUTPUT, SST_DEPS).
#
# Usage: build-elements-autotools.sh TOOLCHAIN
#
# Run it from the directory that contains sst-elements/.  It builds in
# sst-elements-build-<suffix>/ and installs into install_<suffix>/, with the
# suffix from sst_build_suffix.
#
# Not "#!/usr/bin/env bash": this runs under /bin/bash, which is bash 3.2 on
# macOS.

# https://web.archive.org/web/20230401201759/https://wiki.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

set -eo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/../compilers.bash
source "${SCRIPTDIR}"/../compilers.bash
# shellcheck source=SCRIPTDIR/../build-options.bash
source "${SCRIPTDIR}"/../build-options.bash

toolchain="${1}"

sst_options_check
if [[ "${SST_MPI:-true}" == "true" ]]; then
    source_compilers_mpi "${toolchain}"
else
    source_compilers_nompi "${toolchain}"
    # Ariel MPI finds mpicc on PATH.  Let it call the compiler of the
    # toolchain, not the one Open MPI was built with.
    export OMPI_CC="${CC}"
    export OMPI_CXX="${CXX}"
fi

# Not mapfile: bash 3.2.
configure_args=()
while IFS= read -r arg; do
    configure_args+=("${arg}")
done < <(sst_elements_configure_args)

suffix="$(sst_build_suffix "${toolchain}")"

dir_src="${PWD}/sst-elements"
dir_build="${PWD}/sst-elements-build-${suffix}"
dir_core="${PWD}/install_${suffix}"
dir_install="${dir_core}"

\rm -rf "${dir_build}" || true

pushd "${dir_src}"
# A source tree from "make dist" is not a git checkout and must build with
# configure alone.
if [[ -d .git ]]; then
    git clean -Xdf .
    ./autogen.sh
fi
popd

mkdir -p "${dir_build}"
pushd "${dir_build}"

INSTALL="$(command -v install) -p" "${dir_src}"/configure \
    --prefix="${dir_install}" \
    --with-sst-core="${dir_core}" \
    "${configure_args[@]}"

config_header="${dir_build}/src/sst_element_config.h"
sst_elements_deps_defines | sst_check_deps_defines "${config_header}"
# --enable-ariel-mpi only warns when it cannot find MPI.
if [[ "${SST_MPI:-true}" == "false" ]] &&
    ! grep --quiet '^#define ENABLE_ARIEL_MPI 1$' "${config_header}"; then
    echo "--enable-ariel-mpi did not enable Ariel MPI; is mpicc on PATH?" >&2
    exit 1
fi

bear_make_install
ln -fsv "${dir_build}"/compile_commands.json "${dir_src}"/compile_commands.json

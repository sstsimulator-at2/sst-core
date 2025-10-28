#!/bin/bash

# core_cmake_noflags_nodeps.sh: Compile and install core, using the CMake
# build system, without explicitly specifying any additional build
# dependencies at configure time.

# shellcheck disable=SC2086
# https://web.archive.org/web/20230401201759/https://wiki.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPTDIR}"/compilers.bash

toolchain="${1}"

source_compilers_mpi "${toolchain}"

suffix="$(clean_suffix cmake_noflags_nodeps_${toolchain})"

dir_src="${PWD}/sst-core"
dir_build="${PWD}"/sst-core-build-${suffix}
dir_install="${PWD}"/install_${suffix}

\rm -rf "${dir_build}" || true
\rm -rf "${dir_install}" || true

cmake \
    -GNinja \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -B"${dir_build}" \
    -S"${dir_src}/experimental" \
    -DCMAKE_INSTALL_PREFIX="${dir_install}"

cmake --build "${dir_build}"
cmake --install "${dir_build}"
ln -fsv "${dir_build}"/compile_commands.json "${dir_src}"/compile_commands.json

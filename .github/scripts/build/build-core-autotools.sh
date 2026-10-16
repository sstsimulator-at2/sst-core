#!/usr/bin/env bash

# build-core-autotools.sh: Compile and install core with the Autotools build
# system, in the configuration that build-options.bash reads from the
# environment (SST_MPI, SST_DEBUG_OUTPUT, SST_DEPS).
#
# Usage: build-core-autotools.sh TOOLCHAIN
#
# Run it from the directory that contains sst-core/.  It builds in
# sst-core-build-<suffix>/ and installs into install_<suffix>/, with the
# suffix from sst_build_suffix.

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
fi

configure_args=()
while IFS= read -r arg; do
    configure_args+=("${arg}")
done < <(sst_core_configure_args)

suffix="$(sst_build_suffix "${toolchain}")"

dir_src="${PWD}/sst-core"
dir_build="${PWD}/sst-core-build-${suffix}"
dir_install="${PWD}/install_${suffix}"

\rm -rf "${dir_build}" || true
\rm -rf "${dir_install}" || true

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
    "${configure_args[@]}"

sst_core_deps_defines |
    sst_check_deps_defines "${dir_build}/src/sst/core/sst_config.h"

bear_make_install
ln -fsv "${dir_build}"/compile_commands.json "${dir_src}"/compile_commands.json
# no installation available
# make html

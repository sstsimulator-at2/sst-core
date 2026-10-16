#!/bin/bash

# build-elements-autotools-noflags-nodeps.sh: TODO

# shellcheck disable=SC2086
# https://web.archive.org/web/20230401201759/https://wiki.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPTDIR}"/../compilers.bash
source "${SCRIPTDIR}"/../variant.bash

toolchain="${1}"

source_compilers_mpi "${toolchain}"

variant="${SST_VARIANT:-default}"
sst_variant_check "${variant}"

suffix="$(clean_suffix "autotools_noflags_nodeps_${toolchain}$(sst_variant_suffix "${variant}")")"

dir_src="${PWD}"/sst-elements
dir_build="${PWD}"/sst-elements-build-${suffix}
dir_core="${PWD}"/install_${suffix}
dir_install="${dir_core}"

\rm -rf "${dir_build}" || true
# \rm -rf "${dir_install}" || true

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

[ -n "${INTEL_PIN_DIRECTORY}" ] && PIN_TEXT="--with-pin=${INTEL_PIN_DIRECTORY}" || PIN_TEXT="--without-pin"
INSTALL="$(command -v install) -p" "${dir_src}"/configure \
       "${PIN_TEXT}" \
       --prefix="${dir_install}" \
       --with-sst-core="${dir_core}"

bear_make_install
ln -fsv "${dir_build}"/compile_commands.json "${dir_src}"/compile_commands.json

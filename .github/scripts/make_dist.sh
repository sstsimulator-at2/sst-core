#!/usr/bin/env bash

# make_dist.sh: Replace the sst-core and sst-elements git checkouts with the
# source trees from their "make dist" tarballs, so that later steps build
# and test what a release would ship.
#
# Usage: make_dist.sh TOOLCHAIN
#
# Run it from the directory that contains sst-core/ and sst-elements/,
# before the normal compile steps.  It follows sst-sqe buildsys/bamboo.sh
# (sstmainline_config_make_dist_test):
#
#   1. core: autogen, configure, make dist, then build and install, because
#      elements needs an installed core to configure;
#   2. elements: autogen, configure, make dist;
#   3. delete the git checkouts and unpack the tarballs in their place.
#
# The tarballs are kept in dist/.  The unpacked trees have no .git, so the
# compile scripts run configure only, without autogen.sh.  The tests then
# read their reference files from the unpacked elements tarball.
#
# Run this script from a copy outside sst-core/, since it deletes
# sst-core/.

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "usage: ${0} TOOLCHAIN" >&2
    exit 2
fi
toolchain="${1}"

scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# compilers.bash is not clean under "set -u".
set +u
# shellcheck source=compilers.bash
source "${scriptdir}/compilers.bash"
source_compilers_mpi "${toolchain}"
set -u

# The same directories as core_autotools_noflags_nodeps.sh, so that the
# second build of core gets ccache hits from the first one.
suffix="$(clean_suffix "autotools_noflags_nodeps_${toolchain}")"
dir_core_src="${PWD}/sst-core"
dir_core_build="${PWD}/sst-core-build-${suffix}"
dir_elements_src="${PWD}/sst-elements"
dir_elements_build="${PWD}/sst-elements-build-${suffix}"
dir_install="${PWD}/install_${suffix}"
dir_dist="${PWD}/dist"

rm -rf "${dir_core_build}" "${dir_elements_build}" "${dir_install}" "${dir_dist}"
mkdir -p "${dir_dist}"

# Print the only tarball in directory $1.
find_tarball() {
    local dir="${1}"
    local tarballs=()
    mapfile -t tarballs < <(find "${dir}" -maxdepth 1 -name 'sst-*.tar.gz')
    if [[ "${#tarballs[@]}" -ne 1 ]]; then
        echo "expected one sst-*.tar.gz in ${dir}, found ${#tarballs[@]}" >&2
        exit 1
    fi
    echo "${tarballs[0]}"
}

# Unpack tarball $1 and rename its top-level directory to $2.
unpack_as() {
    local tarball="${1}"
    local dest="${2}"
    local top
    top="$(tar -tzf "${tarball}" | sed -n 1p)"
    top="${top%%/*}"
    tar -xzf "${tarball}"
    mv "${top}" "${dest}"
}

echo "::group::make dist: core"
pushd "${dir_core_src}"
./autogen.sh
popd
mkdir -p "${dir_core_build}"
pushd "${dir_core_build}"
"${dir_core_src}/configure" --prefix="${dir_install}"
make dist
mv "$(find_tarball "${dir_core_build}")" "${dir_dist}/"
make -j"$(max_cpus)"
make install
popd
echo "::endgroup::"

echo "::group::make dist: elements"
pushd "${dir_elements_src}"
./autogen.sh
popd
mkdir -p "${dir_elements_build}"
pushd "${dir_elements_build}"
"${dir_elements_src}/configure" \
    --prefix="${dir_install}" \
    --with-sst-core="${dir_install}" \
    --without-pin
make dist
mv "$(find_tarball "${dir_elements_build}")" "${dir_dist}/"
popd
echo "::endgroup::"

echo "::group::replace the git checkouts with the tarballs"
rm -rf "${dir_core_src}" "${dir_elements_src}"
rm -rf "${dir_core_build}" "${dir_elements_build}" "${dir_install}"
# Both tarballs are in dist/ now; tell them apart by name.
core_tarball=""
elements_tarball=""
for tarball in "${dir_dist}"/sst-*.tar.gz; do
    case "$(basename "${tarball}")" in
        sst-core-*)
            core_tarball="${tarball}"
            ;;
        *)
            elements_tarball="${tarball}"
            ;;
    esac
done
if [[ -z "${core_tarball}" || -z "${elements_tarball}" ]]; then
    echo "expected a core and an elements tarball in ${dir_dist}" >&2
    exit 1
fi
unpack_as "${core_tarball}" "${dir_core_src}"
unpack_as "${elements_tarball}" "${dir_elements_src}"
ls -l "${dir_dist}" "${dir_core_src}" "${dir_elements_src}"
echo "::endgroup::"

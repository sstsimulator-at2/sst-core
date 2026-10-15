#!/usr/bin/env bash

# run-tests.sh: Run the tests of core or elements on an installed SST.
#
# Usage: run-tests.sh core|elements
#
# Reads from the environment:
#   SST_INSTALL_DIR      install prefix of SST (required)
#   SST_TEST_RANKS       MPI ranks, -r (default 1)
#   SST_TEST_THREADS     threads, -t (default 1)
#   SST_TEST_CATEGORIES  space-separated test categories, -m (default pr)
#   SST_VARIANT          build variant from variant.bash (default "default");
#                        its test environment is exported first
#
# Nothing here is GitHub-specific, so it runs the same on a local machine.
# Run it from the directory where sst_test_outputs/ should go.

set -euo pipefail

if [[ "$#" -ne 1 ]] || [[ "${1}" != "core" && "${1}" != "elements" ]]; then
    echo "usage: ${0} core|elements" >&2
    exit 2
fi
what="${1}"

scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/variant.bash
source "${scriptdir}/variant.bash"

variant="${SST_VARIANT:-default}"
sst_variant_check "${variant}"
# Not mapfile: keep this usable with bash 3.2 (macOS /bin/bash).
while IFS= read -r assignment; do
    echo "variant ${variant}: export ${assignment}"
    export "${assignment?}"
done < <(sst_variant_test_env "${variant}")

read -r -a categories <<<"${SST_TEST_CATEGORIES:-pr}"

"${SST_INSTALL_DIR:?}/bin/sst-test-${what}" \
    -r "${SST_TEST_RANKS:-1}" \
    -t "${SST_TEST_THREADS:-1}" \
    -m "${categories[@]}"

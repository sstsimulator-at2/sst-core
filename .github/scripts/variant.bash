# shellcheck shell=bash

# variant.bash: The build variants of the CI jobs.  A variant is a name for
# extra core configure arguments and extra test environment, on top of the
# normal build.  Source this file.
#
# Variants:
#   default  the normal build
#   debug    core with --enable-debug (__SST_DEBUG_OUTPUT__); the vanadis
#            tests use the vanadisdbg library
#
# Usage:
#   source variant.bash
#   variant="${SST_VARIANT:-default}"
#   sst_variant_check "${variant}"
#   mapfile -t configure_args < <(sst_variant_core_configure_args "${variant}")
#   suffix="...$(sst_variant_suffix "${variant}")"

# Return 1, with a message, if $1 is not a known variant.
sst_variant_check() {
    case "${1}" in
        default | debug) ;;
        *)
            echo "unknown SST variant: ${1}" >&2
            return 1
            ;;
    esac
}

# Print the extra arguments for the core configure of variant $1, one per
# line.
sst_variant_core_configure_args() {
    sst_variant_check "${1}" || return 1
    case "${1}" in
        debug) echo "--enable-debug" ;;
    esac
}

# Print the KEY=VALUE environment to export before the tests of variant $1,
# one per line.
sst_variant_test_env() {
    sst_variant_check "${1}" || return 1
    case "${1}" in
        debug) echo "VANADIS_LIBRARY=vanadisdbg" ;;
    esac
}

# Print the suffix for the build and install directories of variant $1:
# nothing for the default variant, so its paths do not change, and
# "_<variant>" otherwise.
sst_variant_suffix() {
    sst_variant_check "${1}" || return 1
    if [[ "${1}" != "default" ]]; then
        echo "_${1}"
    fi
}

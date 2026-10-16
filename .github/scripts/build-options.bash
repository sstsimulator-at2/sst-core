# shellcheck shell=bash

# build-options.bash: The build options of the CI jobs, and the configure
# arguments, test environment and directory names that follow from them.
# Source this file.
#
# Each option that varies between jobs is one environment variable, which
# set-env.sh sets from the input of the same name in sst-ci-job.yml:
#
#   SST_MPI           true (default) or false.  false: core --disable-mpi,
#                     and elements --enable-ariel-mpi, which works only with
#                     a core without MPI.
#   SST_DEBUG_OUTPUT  false (default) or true.  true: core --enable-debug,
#                     which defines __SST_DEBUG_OUTPUT__ (it does not change
#                     -O or -g); the vanadis tests use the vanadisdbg
#                     library.
#   SST_DEPS          all (default) or none.  all: --with-X for each
#                     third-party dependency, so that a missing one is an
#                     error.  none: --without-X, so that configure cannot
#                     find one by itself.
#
# Options that are the same for all jobs (elements --enable-picky-warnings),
# or that follow from another option or from the platform, are set here and
# are not inputs.
#
# Keep this usable with bash 3.2 (macOS /bin/bash): no mapfile.
#
# Usage:
#   source build-options.bash
#   sst_options_check
#   configure_args=()
#   while IFS= read -r arg; do
#       configure_args+=("${arg}")
#   done < <(sst_core_configure_args)

# Return 1, with a message, if an option has an unknown value.
sst_options_check() {
    case "${SST_MPI:-true}" in
        true | false) ;;
        *)
            echo "SST_MPI must be true or false, not ${SST_MPI}" >&2
            return 1
            ;;
    esac
    case "${SST_DEBUG_OUTPUT:-false}" in
        true | false) ;;
        *)
            echo "SST_DEBUG_OUTPUT must be true or false, not ${SST_DEBUG_OUTPUT}" >&2
            return 1
            ;;
    esac
    case "${SST_DEPS:-all}" in
        all | none) ;;
        *)
            echo "SST_DEPS must be all or none, not ${SST_DEPS}" >&2
            return 1
            ;;
    esac
}

# Print "with" or "without", for the --with-X/--without-X of SST_DEPS.
sst_deps_with() {
    if [[ "${SST_DEPS:-all}" == "all" ]]; then
        echo "with"
    else
        echo "without"
    fi
}

# Print the extra arguments for the core configure, one per line.
sst_core_configure_args() {
    sst_options_check || return 1
    local with
    with="$(sst_deps_with)"
    if [[ "${SST_MPI:-true}" == "false" ]]; then
        echo "--disable-mpi"
    fi
    if [[ "${SST_DEBUG_OUTPUT:-false}" == "true" ]]; then
        echo "--enable-debug"
    fi
    echo "--${with}-hdf5"
    echo "--${with}-libz"
    echo "--${with}-ncurses"
}

# Print the extra arguments for the elements configure, one per line.
#
# numpy, CUDA and GPGPU-Sim get no --without-X: their configure checks take
# "no" as a directory.  With SST_DEPS=none, install-os-level-dependencies.sh
# does not install numpy, and CUDA_INSTALL_PATH and GPGPUSIM_ROOT are
# ignored.
sst_elements_configure_args() {
    sst_options_check || return 1
    local with
    with="$(sst_deps_with)"
    echo "--enable-picky-warnings"
    if [[ "${SST_MPI:-true}" == "false" ]]; then
        echo "--enable-ariel-mpi"
    fi
    echo "--${with}-libz"
    if [[ "${with}" == "with" ]]; then
        echo "--with-numpy"
    fi
    # Pin is for Linux x86_64 only, so other platforms build without it.
    if [[ "${with}" == "with" ]] && [[ -n "${INTEL_PIN_DIRECTORY:-}" ]] &&
        [[ "$(uname -s)" == "Linux" ]] && [[ "$(uname -m)" == "x86_64" ]]; then
        echo "--with-pin=${INTEL_PIN_DIRECTORY}"
    else
        echo "--without-pin"
    fi
    if [[ "${with}" == "with" ]]; then
        if [[ -n "${CUDA_INSTALL_PATH:-}" ]]; then
            echo "--with-cuda=${CUDA_INSTALL_PATH}"
        elif [[ -n "${CUDA_HOME:-}" ]]; then
            echo "--with-cuda=${CUDA_HOME}"
        fi
        if [[ -n "${GPGPUSIM_ROOT:-}" ]]; then
            echo "--with-gpgpusim=${GPGPUSIM_ROOT}"
        fi
    fi
}

# Print the preprocessor symbols that the core configure must define in
# sst_config.h with SST_DEPS=all, and must not define with none.
sst_core_deps_defines() {
    echo "HAVE_HDF5"
    echo "HAVE_LIBZ"
    echo "HAVE_CURSES"
}

# Print the preprocessor symbols that the elements configure must define in
# sst_element_config.h with SST_DEPS=all, and must not define with none.
sst_elements_deps_defines() {
    echo "HAVE_LIBZ"
}

# Return 1, with a message, if config header $1 does not agree with
# SST_DEPS for each symbol on stdin.  Some configure checks only warn when
# a dependency that was asked for is missing; this makes that an error.
sst_check_deps_defines() {
    local header="${1}"
    local symbol
    local status=0
    while IFS= read -r symbol; do
        if grep --quiet "^#define ${symbol} 1\$" "${header}"; then
            if [[ "${SST_DEPS:-all}" == "none" ]]; then
                echo "SST_DEPS=none, but ${header} defines ${symbol}" >&2
                status=1
            fi
        else
            if [[ "${SST_DEPS:-all}" == "all" ]]; then
                echo "SST_DEPS=all, but ${header} does not define ${symbol}" >&2
                status=1
            fi
        fi
    done
    return "${status}"
}

# Print the KEY=VALUE environment to export before the tests, one per line.
sst_test_env() {
    sst_options_check || return 1
    if [[ "${SST_DEBUG_OUTPUT:-false}" == "true" ]]; then
        echo "VANADIS_LIBRARY=vanadisdbg"
    fi
}

# Print the suffix of the build and install directories for toolchain $1,
# such as "gcc", "gcc_nompi" or "clang_nompi_nodeps_debug".  The default of
# each option adds nothing.
sst_build_suffix() {
    sst_options_check || return 1
    local suffix="${1}"
    if [[ "${SST_MPI:-true}" == "false" ]]; then
        suffix="${suffix}_nompi"
    fi
    if [[ "${SST_DEPS:-all}" == "none" ]]; then
        suffix="${suffix}_nodeps"
    fi
    if [[ "${SST_DEBUG_OUTPUT:-false}" == "true" ]]; then
        suffix="${suffix}_debug"
    fi
    # Delete "@" and "=", as clean_suffix in compilers.bash does.
    suffix="${suffix//@/}"
    echo "${suffix//=/}"
}

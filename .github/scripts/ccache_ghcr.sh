#!/usr/bin/env bash

# ccache_ghcr.sh: Keep the ccache directory as an OCI artifact in the GitHub
# Container Registry, which has no 10 GB limit like the Actions cache.
#
# Usage:
#   ccache_ghcr.sh setup        configure ccache for the following steps
#   ccache_ghcr.sh restore KEY  pull ghcr.io/<owner>/ccache:KEY, if present;
#                               needs GITHUB_TOKEN with packages: read
#   ccache_ghcr.sh save KEY     push the cache as ghcr.io/<owner>/ccache:KEY;
#                               needs GITHUB_TOKEN with packages: write
#
# sst-core and sst-elements push to the same package, so a build in one
# repository warms the cache for the other.  CCACHE_BASEDIR makes the
# different workspace paths of the two repositories hash the same.
#
# Needs ccache (install_os_level_dependencies.sh) and oras
# (oras-project/setup-oras).  Without ccache, all commands do nothing.

set -euo pipefail

artifact_type="application/vnd.sstsimulator.ccache"
layer_type="application/vnd.sstsimulator.ccache.layer.v1.tar"
layer_file="ccache.tar"

usage() {
    echo "usage: ${0} setup | restore KEY | save KEY" >&2
    exit 2
}

image_ref() {
    local key="${1}"
    local owner
    owner="$(echo "${GITHUB_REPOSITORY_OWNER}" | tr '[:upper:]' '[:lower:]')"
    echo "ghcr.io/${owner}/ccache:${key}"
}

masquerade_dir() {
    local dir
    if command -v brew >/dev/null 2>&1; then
        dir="$(brew --prefix ccache)/libexec"
        if [[ -d "${dir}" ]]; then
            echo "${dir}"
            return
        fi
    fi
    for dir in /usr/lib64/ccache /usr/lib/ccache; do
        if [[ -d "${dir}" ]]; then
            echo "${dir}"
            return
        fi
    done
}

registry_login() {
    printf '%s' "${GITHUB_TOKEN}" |
        oras login ghcr.io --username "${GITHUB_ACTOR}" --password-stdin
}

ccache_major_version() {
    ccache --version | sed -E -n '1s/^ccache version ([0-9]+).*/\1/p'
}

do_setup() {
    local cache_root="${GITHUB_WORKSPACE}/.ccache"
    local dir
    mkdir -p "${cache_root}"
    dir="$(masquerade_dir)"
    if [[ -z "${dir}" ]]; then
        echo "::warning::no ccache compiler symlink directory found"
    else
        # Entries in GITHUB_PATH go before the existing PATH.
        echo "${dir}" >>"${GITHUB_PATH}"
    fi
    {
        echo "CCACHE_DIR=${cache_root}"
        echo "CCACHE_BASEDIR=${GITHUB_WORKSPACE}"
        echo "CCACHE_NOHASHDIR=true"
        echo "CCACHE_COMPILERCHECK=content"
        echo "CCACHE_MAXSIZE=2G"
        echo "SST_CCACHE_START=$(date +%s)"
    } >>"${GITHUB_ENV}"
    CCACHE_DIR="${cache_root}" ccache --zero-stats
}

do_restore() {
    local ref
    local tmp
    : "${CCACHE_DIR:?run setup first}"
    ref="$(image_ref "${1}")"
    tmp="$(mktemp -d "${RUNNER_TEMP:-/tmp}/ccache.XXXXXX")"
    # The package is private, so a pull without a login is denied.
    registry_login
    if oras pull --output "${tmp}" "${ref}"; then
        tar -xf "${tmp}/${layer_file}" -C "${CCACHE_DIR}"
        ccache --show-stats
    else
        echo "::notice::no ccache at ${ref}; this build starts cold"
    fi
    rm -rf "${tmp}"
}

do_save() {
    local ref
    local tmp
    local age
    : "${CCACHE_DIR:?run setup first}"
    ref="$(image_ref "${1}")"
    # Keep only the entries this job used, so the cache does not grow with
    # objects from old commits.  ccache 3 (Rocky 8) cannot do this, and
    # trims by CCACHE_MAXSIZE only.
    if [[ "$(ccache_major_version)" -ge 4 ]]; then
        age="$(($(date +%s) - SST_CCACHE_START))"
        ccache --evict-older-than "${age}s"
    fi
    ccache --show-stats
    tmp="$(mktemp -d "${RUNNER_TEMP:-/tmp}/ccache.XXXXXX")"
    # The cache entries are already compressed by ccache.
    tar -cf "${tmp}/${layer_file}" -C "${CCACHE_DIR}" .
    registry_login
    # oras refuses absolute file paths, so push from the directory.
    (
        cd "${tmp}"
        oras push \
            --artifact-type "${artifact_type}" \
            --annotation "org.opencontainers.image.source=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" \
            "${ref}" \
            "${layer_file}:${layer_type}"
    )
    rm -rf "${tmp}"
}

if [[ "$#" -lt 1 ]]; then
    usage
fi

if ! command -v ccache >/dev/null 2>&1; then
    echo "::warning::ccache not found; not using a compiler cache"
    exit 0
fi

case "${1}" in
    setup)
        [[ "$#" -eq 1 ]] || usage
        do_setup
        ;;
    restore)
        [[ "$#" -eq 2 ]] || usage
        do_restore "${2}"
        ;;
    save)
        [[ "$#" -eq 2 ]] || usage
        do_save "${2}"
        ;;
    *)
        usage
        ;;
esac

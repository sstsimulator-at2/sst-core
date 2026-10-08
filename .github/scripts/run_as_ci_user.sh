#!/usr/bin/env bash

# run_as_ci_user.sh: Run GitHub Actions step scripts as an unprivileged user
# inside a CI container, where steps otherwise run as root.
#
# Usage:
#   run_as_ci_user.sh --setup   create the user and give it the workspace
#   run_as_ci_user.sh SCRIPT    run SCRIPT as the user; use as a step's
#                               `shell: bash <this script> {0}`

set -euo pipefail

ci_user="sst-ci"
# GitHub sets HOME to this directory inside containers.  runuser resets HOME
# from passwd, so use the same directory to keep the config that
# ccache-action writes there.
ci_home="/github/home"

if [[ "$#" -ne 1 ]]; then
    echo "usage: ${0} --setup | SCRIPT" >&2
    exit 2
fi

if [[ "${1}" == "--setup" ]]; then
    useradd --home-dir "${ci_home}" --no-create-home --user-group "${ci_user}"
    chown --recursive "${ci_user}:${ci_user}" "${GITHUB_WORKSPACE}" "${ci_home}"
else
    exec runuser --user "${ci_user}" -- bash --noprofile --norc -eo pipefail "${1}"
fi

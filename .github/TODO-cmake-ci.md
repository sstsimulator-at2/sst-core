# TODO: add the CMake build back to CI

The CMake build of core (`experimental/`) was removed from CI when the jobs
moved to the shared template `.github/workflows/sst-ci-job.yml`.  Before that,
it was the self-hosted job `rocky9-cmake` (`.github/workflows/at2-rocky9-cmake.yml`,
commented out in `build_and_test_at2.yml`, now `test-matrix-at2.yml`).
These steps add it back.

## What the old job did

- Script `.github/scripts/core_cmake_noflags_nodeps.sh TOOLCHAIN`: configure
  with `cmake -GNinja -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -S sst-core/experimental`
  into `sst-core-build-cmake_noflags_nodeps_<toolchain>`, then
  `cmake --build` and `cmake --install` into
  `install_cmake_noflags_nodeps_<toolchain>`.
- Test with `install_cmake_noflags_nodeps_<toolchain>/bin/sst-test-core`.
- Core only.  It did not build or test elements.

## Steps

1. Restore the script from the commit before the removal, and give it the
   name of the other build scripts:

   ```bash
   commit="$(git log --diff-filter=D --format=%H -1 -- .github/scripts/core_cmake_noflags_nodeps.sh)"
   git checkout "${commit}^" -- .github/scripts/core_cmake_noflags_nodeps.sh
   git mv .github/scripts/core_cmake_noflags_nodeps.sh \
       .github/scripts/build/build-core-cmake-noflags-nodeps.sh
   ```

   Keep the `if [[ -d .git ]]` guard style of the autotools scripts if the
   script gets any source tree preparation, and source
   `"${SCRIPTDIR}"/../compilers.bash` like them.
2. Add an input `build-system` to `sst-ci-job.yml`, with values `autotools`
   (default) and `cmake`.  When it is `cmake`:
   - "Compile core" runs `build/build-core-cmake-noflags-nodeps.sh`.
   - `SST_INSTALL_DIR` is `install_cmake_noflags_nodeps_<toolchain>`.
   - Skip "Compile elements", "Test elements", their artifact upload, and
     make dist (`if: ${{ inputs.build-system == 'autotools' }}`).
3. Install `cmake` and `ninja-build` (`ninja` on Homebrew and Arch) in
   `.github/scripts/install-os-level-dependencies.sh`.  On Rocky Linux 9,
   `ninja-build` is in CRB, which the script already enables.
4. Add caller jobs, for example `rocky9-mpi-cmake` in `test-matrix-github.yml`
   and `at2-rocky9-cmake` in `test-matrix-at2.yml`.  Give each its own
   `ccache-key` (for example `rocky9-mpi-gcc-cmake`) with `ccache-save: true`.
   The CMake and Autotools compile command lines differ, so they cannot
   share a cache.
5. Add the same jobs to sst-elements only if elements gets a CMake build.

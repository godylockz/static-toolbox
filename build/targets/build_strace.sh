#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s [x86|x86_64|armhf|aarch64]\n' "$0" >&2
    exit 2
fi

ROOT_DIRECTORY=${GITHUB_WORKSPACE:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}
# shellcheck source=build/lib.sh
source "${ROOT_DIRECTORY}/build/lib.sh"
init_lib "$1"

install_host_toolchain
prepare_archive "strace-${STRACE_VERSION}" "$STRACE_SOURCE_URL" \
    "$STRACE_SOURCE_SHA256" "strace-${STRACE_VERSION}.tar.xz"

source_dir="${SOURCE_DIRECTORY}/strace-${STRACE_VERSION}"
build_dir="${BUILD_DIRECTORY}/strace-build-${CURRENT_ARCH}"
mkdir -p "$build_dir"
pushd "$build_dir" >/dev/null
CC=gcc \
CC_FOR_BUILD="$HOST_CC" \
CPP_FOR_BUILD="$HOST_CC -E" \
CXX_FOR_BUILD="$HOST_CXX" \
CFLAGS="$GCC_OPTS" \
LDFLAGS="-static -pthread" \
"${source_dir}/configure" \
    --build=x86_64-linux-musl \
    --host="$(get_host_triple)" \
    --disable-mpers \
    --without-libdw \
    --without-libunwind \
    --without-libiberty \
    --without-libselinux
make -j"$JOBS"
strip_binary "${build_dir}/src/strace"
popd >/dev/null

create_stage strace "$STRACE_VERSION"
cp "${build_dir}/src/strace" "${STAGE_DIRECTORY}/bin/strace"
copy_license "$source_dir" COPYING strace-COPYING

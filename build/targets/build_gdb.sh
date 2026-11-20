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
lib_build_gmp
lib_build_mpfr
prepare_archive "gdb-${GDB_VERSION}" "$GDB_SOURCE_URL" \
    "$GDB_SOURCE_SHA256" "gdb-${GDB_VERSION}.tar.xz"

source_dir="${SOURCE_DIRECTORY}/gdb-${GDB_VERSION}"
build_dir="${BUILD_DIRECTORY}/gdb-build-${CURRENT_ARCH}"
get_static_atomic_archive >/dev/null
if ! grep -Fq "LIBS=\"\$(gcc -print-file-name=libatomic.a) \$LIBS\"" \
    "${source_dir}/gdb/configure"; then
    patch -d "$source_dir" -p1 <"${ROOT_DIRECTORY}/patches/gdb/static-libatomic.patch"
fi
mkdir -p "$build_dir"
pushd "$build_dir" >/dev/null
CC=gcc \
CXX=g++ \
CC_FOR_BUILD="$HOST_CC" \
CXX_FOR_BUILD="$HOST_CXX" \
CFLAGS="$GCC_OPTS" \
CXXFLAGS="$GXX_OPTS" \
LDFLAGS=-static \
"${source_dir}/configure" \
    --build=x86_64-linux-musl \
    --host="$(get_host_triple)" \
    --target="$(get_host_triple)" \
    --with-gmp="$GMP_PREFIX" \
    --with-mpfr="$MPFR_PREFIX" \
    --with-python=no \
    --with-guile=no \
    --with-expat=no \
    --with-lzma=no \
    --with-debuginfod=no \
    --with-xxhash=no \
    --disable-binutils \
    --disable-gas \
    --disable-gold \
    --disable-gprof \
    --disable-ld \
    --disable-nls \
    --disable-sim \
    --disable-source-highlight \
    --disable-tui \
    --disable-werror \
    --disable-inprocess-agent \
    --enable-gdb \
    --enable-gdbserver \
    --enable-static \
    --disable-shared
make -j"$JOBS" all-gdb all-gdbserver
# GDB links through libtool, where -static selects static dependency archives but
# does not force a static executable. Pass the compiler flag through explicitly.
rm -f "${build_dir}/gdb/gdb"
make -C "${build_dir}/gdb" gdb LDFLAGS=-Wc,-static
strip_binary "${build_dir}/gdb/gdb"
strip_binary "${build_dir}/gdbserver/gdbserver"
popd >/dev/null

create_stage gdb "$GDB_VERSION"
cp "${build_dir}/gdb/gdb" "${STAGE_DIRECTORY}/bin/gdb"
cp "${build_dir}/gdbserver/gdbserver" "${STAGE_DIRECTORY}/bin/gdbserver"
copy_license "$source_dir" gdb/COPYING GDB-COPYING
copy_license "$source_dir" COPYING3 GPL-3.0
copy_license "${SOURCE_DIRECTORY}/gmp-${GMP_VERSION}" COPYINGv3 GMP-COPYINGv3
copy_license "${SOURCE_DIRECTORY}/gmp-${GMP_VERSION}" COPYING.LESSERv3 GMP-COPYING.LESSERv3
copy_license "${SOURCE_DIRECTORY}/mpfr-${MPFR_VERSION}" COPYING.LESSER MPFR-COPYING.LESSER

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

lib_build_openssl
lib_build_zlib
prepare_archive "nmap-${NMAP_VERSION}" "$NMAP_SOURCE_URL" \
    "$NMAP_SOURCE_SHA256" "nmap-${NMAP_VERSION}.tar.bz2"

source_dir="${SOURCE_DIRECTORY}/nmap-${NMAP_VERSION}"
install_root="${BUILD_DIRECTORY}/nmap-install-${CURRENT_ARCH}"
atomic_archive=$(get_static_atomic_archive)
target_strip=$(gcc -print-prog-name=strip)

pushd "$source_dir" >/dev/null
CC=gcc \
CXX=g++ \
STRIP="$target_strip" \
CFLAGS="$GCC_OPTS" \
CXXFLAGS="$GXX_OPTS" \
CPPFLAGS="-I${OPENSSL_PREFIX}/include -I${ZLIB_PREFIX}/include" \
LDFLAGS="-static -L${OPENSSL_PREFIX}/lib -L${ZLIB_PREFIX}/lib" \
LIBS="$atomic_archive" \
PKG_CONFIG_LIBDIR="${OPENSSL_PREFIX}/lib/pkgconfig:${ZLIB_PREFIX}/lib/pkgconfig" \
./configure \
    --build="$(get_build_triple)" \
    --host="$(get_host_triple)" \
    --prefix=/usr \
    --without-zenmap \
    --without-ndiff \
    --without-nmap-update \
    --with-openssl="$OPENSSL_PREFIX" \
    --with-libpcap=included \
    --with-libpcre=included \
    --with-libssh2=included \
    --with-liblua=included \
    --with-libz="$ZLIB_PREFIX"
make -j"$JOBS"
make install DESTDIR="$install_root" STRIP="$target_strip"
popd >/dev/null

create_stage nmap "$NMAP_VERSION"
for binary in nmap ncat nping; do
    strip_binary "${install_root}/usr/bin/${binary}"
    cp "${install_root}/usr/bin/${binary}" "${STAGE_DIRECTORY}/bin/${binary}"
done
mkdir -p "${STAGE_DIRECTORY}/share"
cp -R "${install_root}/usr/share/nmap" "${STAGE_DIRECTORY}/share/nmap"
cp "${ROOT_DIRECTORY}/package/targets/nmap/run-nmap.sh" "$STAGE_DIRECTORY/run-nmap.sh"
copy_license "$source_dir" LICENSE Nmap-LICENSE
copy_license "$source_dir" ncat/LICENSE Ncat-LICENSE
copy_license "$source_dir" nping/LICENSE Nping-LICENSE
copy_license "$source_dir" libpcap/LICENSE libpcap-LICENSE
copy_license "$source_dir" libssh2/COPYING libssh2-COPYING
copy_license "$source_dir" libpcre/LICENCE.md PCRE2-LICENCE.md
copy_license "${SOURCE_DIRECTORY}/zlib-${ZLIB_VERSION}" LICENSE zlib-LICENSE
copy_license "${SOURCE_DIRECTORY}/openssl-${OPENSSL_VERSION}" LICENSE.txt OpenSSL-LICENSE.txt

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

lib_build_libpcap
prepare_archive "tcpreplay-${TCPREPLAY_VERSION}" "$TCPREPLAY_SOURCE_URL" \
    "$TCPREPLAY_SOURCE_SHA256" "tcpreplay-${TCPREPLAY_VERSION}.tar.xz"

source_dir="${SOURCE_DIRECTORY}/tcpreplay-${TCPREPLAY_VERSION}"
pushd "$source_dir" >/dev/null
CC=gcc \
CFLAGS="$GCC_OPTS -I${LIBPCAP_PREFIX}/include" \
CPPFLAGS="-I${LIBPCAP_PREFIX}/include" \
LDFLAGS="-static -L${LIBPCAP_PREFIX}/lib" \
LIBS="${LIBPCAP_PREFIX}/lib/libpcap.a" \
./configure \
    --build=x86_64-linux-musl \
    --host="$(get_host_triple)" \
    --disable-shared \
    --enable-static \
    --enable-static-link \
    --with-libpcap="$LIBPCAP_PREFIX" \
    --with-libdnet=no
make -j"$JOBS" \
    AM_LDFLAGS=-all-static \
    tcpreplay_LDFLAGS=-all-static \
    tcpreplay_edit_LDFLAGS=-all-static \
    tcpbridge_LDFLAGS=-all-static
popd >/dev/null

create_stage tcpreplay "$TCPREPLAY_VERSION"
for binary in tcpreplay tcpreplay-edit tcprewrite tcpprep tcpcapinfo tcpbridge tcpliveplay; do
    strip_binary "${source_dir}/src/${binary}"
    cp "${source_dir}/src/${binary}" "${STAGE_DIRECTORY}/bin/${binary}"
done
copy_license "$source_dir" LICENSE tcpreplay-LICENSE
copy_license "$source_dir" libopts/COPYING.gplv3 libopts-COPYING.gplv3
copy_license "$source_dir" libopts/COPYING.lgplv3 libopts-COPYING.lgplv3
copy_license "${SOURCE_DIRECTORY}/libpcap-${LIBPCAP_VERSION}" LICENSE libpcap-LICENSE

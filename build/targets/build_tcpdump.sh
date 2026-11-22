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
prepare_archive "tcpdump-${TCPDUMP_VERSION}" "$TCPDUMP_SOURCE_URL" \
    "$TCPDUMP_SOURCE_SHA256" "tcpdump-${TCPDUMP_VERSION}.tar.xz"

source_dir="${SOURCE_DIRECTORY}/tcpdump-${TCPDUMP_VERSION}"
pushd "$source_dir" >/dev/null
CC=gcc \
CFLAGS="$GCC_OPTS -I${LIBPCAP_PREFIX}/include" \
CPPFLAGS="-I${LIBPCAP_PREFIX}/include" \
LDFLAGS="-static -L${LIBPCAP_PREFIX}/lib" \
LIBS="${LIBPCAP_PREFIX}/lib/libpcap.a" \
./configure \
    --build="$(get_build_triple)" \
    --host="$(get_host_triple)" \
    --without-crypto \
    --without-smi
make -j"$JOBS"
strip_binary tcpdump
popd >/dev/null

create_stage tcpdump "$TCPDUMP_VERSION"
cp "${source_dir}/tcpdump" "${STAGE_DIRECTORY}/bin/tcpdump"
copy_license "$source_dir" LICENSE tcpdump-LICENSE
copy_license "${SOURCE_DIRECTORY}/libpcap-${LIBPCAP_VERSION}" LICENSE libpcap-LICENSE

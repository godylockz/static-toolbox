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
prepare_git_source "socat-${SOCAT_VERSION}" "$SOCAT_GIT_URL" "$SOCAT_GIT_COMMIT"

source_dir="${SOURCE_DIRECTORY}/socat-${SOCAT_VERSION}"
if grep -Fq 'pName->d.iPAddress->data' "${source_dir}/xio-openssl.c"; then
    patch -d "$source_dir" -p1 <"${ROOT_DIRECTORY}/patches/socat/openssl-4-opaque-asn1.patch"
fi
atomic_archive=$(get_static_atomic_archive)
pushd "$source_dir" >/dev/null
autoconf
CC=gcc \
CFLAGS="$GCC_OPTS" \
CPPFLAGS="-I${OPENSSL_PREFIX}/include -DNETDB_INTERNAL=-1" \
LDFLAGS="-static -L${OPENSSL_PREFIX}/lib" \
LIBS="-lssl -lcrypto ${atomic_archive} -pthread" \
./configure \
    --build=x86_64-linux-musl \
    --host="$(get_host_triple)" \
    --disable-readline \
    --enable-openssl-base="$OPENSSL_PREFIX" \
    --enable-openssl-method
make -j"$JOBS" socat
strip_binary socat
popd >/dev/null

create_stage socat "$SOCAT_VERSION"
cp "${source_dir}/socat" "${STAGE_DIRECTORY}/bin/socat"
copy_license "$source_dir" COPYING socat-COPYING
copy_license "$source_dir" COPYING.OpenSSL socat-OpenSSL-exception
copy_license "${SOURCE_DIRECTORY}/openssl-${OPENSSL_VERSION}" LICENSE.txt OpenSSL-LICENSE.txt

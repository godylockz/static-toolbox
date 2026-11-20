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
prepare_archive "openssh-${OPENSSH_VERSION}" "$OPENSSH_SOURCE_URL" \
    "$OPENSSH_SOURCE_SHA256" "openssh-${OPENSSH_VERSION}.tar.gz"

source_dir="${SOURCE_DIRECTORY}/openssh-${OPENSSH_VERSION}"
atomic_archive=$(get_static_atomic_archive)
pushd "$source_dir" >/dev/null
CC=gcc \
CFLAGS="$GCC_OPTS -I${OPENSSL_PREFIX}/include -I${ZLIB_PREFIX}/include" \
CPPFLAGS="-I${OPENSSL_PREFIX}/include -I${ZLIB_PREFIX}/include" \
LDFLAGS="-static -L${OPENSSL_PREFIX}/lib -L${ZLIB_PREFIX}/lib" \
LIBS="-lz -lssl -lcrypto ${atomic_archive}" \
./configure \
    --build=x86_64-linux-musl \
    --host="$(get_host_triple)" \
    --prefix=/usr \
    --sysconfdir=/etc/ssh \
    --with-privsep-path=/var/empty \
    --with-privsep-user=nobody \
    --with-ssl-dir="$OPENSSL_PREFIX" \
    --with-zlib="$ZLIB_PREFIX" \
    --with-ldflags=-static \
    --without-pam \
    --without-selinux \
    --without-kerberos5 \
    --without-libedit
make -j"$JOBS"
popd >/dev/null

create_stage openssh "$OPENSSH_VERSION"
for binary in ssh sshd sshd-auth sshd-session scp sftp ssh-add ssh-agent \
    ssh-keygen ssh-keyscan ssh-keysign ssh-pkcs11-helper ssh-sk-helper; do
    strip_binary "${source_dir}/${binary}"
    cp "${source_dir}/${binary}" "${STAGE_DIRECTORY}/bin/${binary}"
done
strip_binary "${source_dir}/sftp-server"
cp "${source_dir}/sftp-server" "${STAGE_DIRECTORY}/bin/sftp-server"
cp "${ROOT_DIRECTORY}/package/targets/openssh/run-sshd.sh" "$STAGE_DIRECTORY/run-sshd.sh"
copy_license "$source_dir" LICENCE OpenSSH-LICENCE
copy_license "${SOURCE_DIRECTORY}/openssl-${OPENSSL_VERSION}" LICENSE.txt OpenSSL-LICENSE.txt
copy_license "${SOURCE_DIRECTORY}/zlib-${ZLIB_VERSION}" LICENSE zlib-LICENSE

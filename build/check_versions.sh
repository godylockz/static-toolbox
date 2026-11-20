#!/usr/bin/env bash
set -euo pipefail

ROOT_DIRECTORY=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=build/versions.env
source "${ROOT_DIRECTORY}/build/versions.env"

curl_page() {
    curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
        --retry 3 "$1"
}

require_version() {
    if [[ -z $2 ]]; then
        printf 'Unable to resolve the current %s version.\n' "$1" >&2
        exit 2
    fi
}

check_version() {
    local name=$1
    local pinned=$2
    local current=$3

    require_version "$name" "$current"
    if [[ $pinned == "$current" ]]; then
        printf -- "- %s: \`%s\` (current)\n" "$name" "$pinned"
    else
        printf -- "- %s: pinned \`%s\`, current \`%s\`\n" "$name" "$pinned" "$current"
        stale=1
    fi
}

nmap_page=$(curl_page https://nmap.org/dist/)
nmap_current=$(grep -Eo 'nmap-[0-9]+([.][0-9]+)+[.]tar[.]bz2' <<<"$nmap_page" | \
    sed -E 's/^nmap-//; s/[.]tar[.]bz2$//' | sort -Vu | tail -1)

tcpdump_page=$(curl_page https://www.tcpdump.org/release/)
tcpdump_current=$(grep -Eo 'tcpdump-[0-9]+([.][0-9]+)+[.]tar[.]xz' <<<"$tcpdump_page" | \
    sed -E 's/^tcpdump-//; s/[.]tar[.]xz$//' | sort -Vu | tail -1)
libpcap_current=$(grep -Eo 'libpcap-[0-9]+([.][0-9]+)+[.]tar[.]xz' <<<"$tcpdump_page" | \
    sed -E 's/^libpcap-//; s/[.]tar[.]xz$//' | sort -Vu | tail -1)

openssh_page=$(curl_page https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/)
openssh_current=$(grep -Eo 'openssh-[0-9]+([.][0-9]+)+p[0-9]+[.]tar[.]gz' \
    <<<"$openssh_page" | sed -E 's/^openssh-//; s/[.]tar[.]gz$//' | sort -Vu | tail -1)

zlib_page=$(curl_page https://zlib.net/)
zlib_current=$(grep -Eo 'zlib-[0-9]+([.][0-9]+)+[.]tar[.]gz' <<<"$zlib_page" | \
    sed -E 's/^zlib-//; s/[.]tar[.]gz$//' | sort -Vu | tail -1)

gdb_page=$(curl_page https://ftp.gnu.org/gnu/gdb/)
gdb_current=$(grep -Eo 'gdb-[0-9]+([.][0-9]+)+[.]tar[.]xz' <<<"$gdb_page" | \
    sed -E 's/^gdb-//; s/[.]tar[.]xz$//' | sort -Vu | tail -1)

gmp_page=$(curl_page https://ftp.gnu.org/gnu/gmp/)
gmp_current=$(grep -Eo 'gmp-[0-9]+([.][0-9]+)+[.]tar[.]xz' <<<"$gmp_page" | \
    sed -E 's/^gmp-//; s/[.]tar[.]xz$//' | sort -Vu | tail -1)

mpfr_page=$(curl_page https://www.mpfr.org/mpfr-current/)
mpfr_current=$(grep -Eo 'mpfr-[0-9]+([.][0-9]+)+[.]tar[.]xz' <<<"$mpfr_page" | \
    sed -E 's/^mpfr-//; s/[.]tar[.]xz$//' | sort -Vu | tail -1)

strace_page=$(curl_page https://strace.io/files/)
strace_current=$(grep -Eo 'href="[0-9]+([.][0-9]+)+/' <<<"$strace_page" | \
    sed -E 's/^href="//; s#/$##' | sort -Vu | tail -1)

openssl_current=$(git ls-remote --tags https://github.com/openssl/openssl.git \
    'refs/tags/openssl-3.5.*' | \
    sed -nE 's#.*refs/tags/openssl-([0-9]+([.][0-9]+)+)(\^\{\})?$#\1#p' | \
    sort -Vu | tail -1)
socat_current=$(git ls-remote --tags https://repo.or.cz/socat.git 'refs/tags/tag-*' | \
    sed -nE 's#.*refs/tags/tag-([0-9]+([.][0-9]+)+)(\^\{\})?$#\1#p' | \
    sort -Vu | tail -1)
tcpreplay_current=$(git ls-remote --tags https://github.com/appneta/tcpreplay.git \
    'refs/tags/v*' | \
    sed -nE 's#.*refs/tags/v([0-9]+([.][0-9]+)+)(\^\{\})?$#\1#p' | \
    sort -Vu | tail -1)

stale=0
printf '# Static source version check\n\n'
check_version Nmap "$NMAP_VERSION" "$nmap_current"
check_version tcpdump "$TCPDUMP_VERSION" "$tcpdump_current"
check_version libpcap "$LIBPCAP_VERSION" "$libpcap_current"
check_version OpenSSH "$OPENSSH_VERSION" "$openssh_current"
check_version 'OpenSSL 3.5 LTS' "$OPENSSL_VERSION" "$openssl_current"
check_version zlib "$ZLIB_VERSION" "$zlib_current"
check_version socat "$SOCAT_VERSION" "$socat_current"
check_version GDB "$GDB_VERSION" "$gdb_current"
check_version GMP "$GMP_VERSION" "$gmp_current"
check_version MPFR "$MPFR_VERSION" "$mpfr_current"
check_version strace "$STRACE_VERSION" "$strace_current"
check_version tcpreplay "$TCPREPLAY_VERSION" "$tcpreplay_current"

exit "$stale"

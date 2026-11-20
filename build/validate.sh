#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    printf 'Usage: %s <tool> <version> <arch> <stage-directory>\n' "$0" >&2
    exit 2
fi

tool=$1
version=$2
architecture=$3
stage_directory=$4

if [[ ! -d "$stage_directory" ]]; then
    printf 'Missing stage directory: %s\n' "$stage_directory" >&2
    exit 1
fi

case "$tool" in
    nmap) binaries=(nmap ncat nping) ;;
    tcpdump) binaries=(tcpdump) ;;
    openssh) binaries=(ssh sshd sshd-auth sshd-session scp sftp ssh-add ssh-agent ssh-keygen ssh-keyscan ssh-keysign ssh-pkcs11-helper ssh-sk-helper sftp-server) ;;
    socat) binaries=(socat) ;;
    gdb) binaries=(gdb gdbserver) ;;
    strace) binaries=(strace) ;;
    tcpreplay) binaries=(tcpreplay tcpreplay-edit tcprewrite tcpprep tcpcapinfo tcpbridge tcpliveplay) ;;
    *) printf 'Unknown tool: %s\n' "$tool" >&2; exit 2 ;;
esac

case "$architecture" in
    x86) architecture_pattern='Intel 80386'; runner=() ;;
    x86_64) architecture_pattern='x86-64'; runner=() ;;
    armhf) architecture_pattern='ARM,.*EABI5'; runner=(qemu-arm) ;;
    aarch64) architecture_pattern='ARM aarch64'; runner=(qemu-aarch64) ;;
    *) printf 'Unknown architecture: %s\n' "$architecture" >&2; exit 2 ;;
esac

run_target() {
    "${runner[@]}" "$@"
}

for binary in "${binaries[@]}"; do
    binary_path="${stage_directory}/bin/${binary}"
    if [[ ! -x "$binary_path" ]]; then
        printf 'Missing executable: %s\n' "$binary_path" >&2
        exit 1
    fi

    file_output=$(file --brief "$binary_path")
    if [[ ! $file_output =~ $architecture_pattern ]]; then
        printf 'Wrong architecture for %s: %s\n' "$binary" "$file_output" >&2
        exit 1
    fi
    if [[ $file_output != *"statically linked"* && $file_output != *"static-pie linked"* ]]; then
        printf 'Binary is not static: %s: %s\n' "$binary" "$file_output" >&2
        exit 1
    fi
    program_headers=$(readelf --program-headers "$binary_path")
    if grep -q 'INTERP' <<<"$program_headers"; then
        printf 'Binary has a dynamic interpreter: %s\n' "$binary" >&2
        exit 1
    fi
    dynamic_section=$(readelf --dynamic "$binary_path" 2>/dev/null || true)
    if grep -q 'NEEDED' <<<"$dynamic_section"; then
        printf 'Binary has a dynamic dependency: %s\n' "$binary" >&2
        exit 1
    fi
done

case "$tool" in
    nmap)
        export NMAPDIR="${stage_directory}/share/nmap"
        version_output=$(run_target "${stage_directory}/bin/nmap" --version)
        grep -Fq "Nmap version ${version}" <<<"$version_output"
        if [[ ${#runner[@]} -eq 0 ]]; then
            run_target "${stage_directory}/bin/nmap" -n -sn 127.0.0.1 >/dev/null
        fi
        run_target "${stage_directory}/bin/ncat" --version >/dev/null 2>&1
        run_target "${stage_directory}/bin/nping" --version >/dev/null
        ;;
    tcpdump)
        version_output=$(run_target "${stage_directory}/bin/tcpdump" --version 2>&1)
        grep -Fq "tcpdump version ${version}" <<<"$version_output"
        fixture=$(mktemp)
        printf '\xd4\xc3\xb2\xa1\x02\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x3c\x00\x00\x00\x3c\x00\x00\x00\xff\xff\xff\xff\xff\xff\x00\x11\x22\x33\x44\x55\x08\x00\x45\x00\x00\x1c\x00\x01\x00\x00\x40\x01\x7c\xde\x7f\x00\x00\x01\x7f\x00\x00\x01\x08\x00\xf7\xff\x00\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' >"$fixture"
        run_target "${stage_directory}/bin/tcpdump" -n -r "$fixture" >/dev/null
        ;;
    openssh)
        version_output=$(run_target "${stage_directory}/bin/ssh" -V 2>&1)
        grep -Fq "OpenSSH_${version}" <<<"$version_output"
        fixture_directory=$(mktemp -d)
        trap 'rm -rf "$fixture_directory"' EXIT
        run_target "${stage_directory}/bin/ssh-keygen" -q -t ed25519 -N '' \
            -f "${fixture_directory}/host_key"
        run_target "${stage_directory}/bin/sshd" -t \
            -f /dev/null \
            -h "${fixture_directory}/host_key" \
            -o "SshdAuthPath=${stage_directory}/bin/sshd-auth" \
            -o "SshdSessionPath=${stage_directory}/bin/sshd-session"
        ;;
    socat)
        version_output=$(run_target "${stage_directory}/bin/socat" -V 2>&1)
        grep -Fq "socat version ${version}" <<<"$version_output"
        ;;
    gdb)
        version_output=$(run_target "${stage_directory}/bin/gdb" --version)
        grep -Fq "GNU gdb (GDB) ${version}" <<<"$version_output"
        run_target "${stage_directory}/bin/gdbserver" --version >/dev/null
        ;;
    strace)
        version_output=$(run_target "${stage_directory}/bin/strace" -V)
        grep -Fq "strace -- version ${version}" <<<"$version_output"
        ;;
    tcpreplay)
        # tcpreplay initializes live-interface state before parsing --version and
        # exits 255 under user-mode QEMU. tcprewrite uses the same suite version
        # without requiring a live packet interface.
        version_output=$(run_target "${stage_directory}/bin/tcprewrite" --version 2>&1)
        grep -Fq "tcprewrite version: ${version}" <<<"$version_output"
        run_target "${stage_directory}/bin/tcpcapinfo" --version >/dev/null 2>&1
        ;;
esac

printf 'Validated %s %s for %s\n' "$tool" "$version" "$architecture"

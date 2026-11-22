#!/bin/sh
set -eu

: "${ARCHITECTURE:?ARCHITECTURE is required}"
: "${TOOLCHAIN_TRIPLE:?TOOLCHAIN_TRIPLE is required}"

case "${ARCHITECTURE}:${TOOLCHAIN_TRIPLE}" in
    x86:i686-unknown-linux-musl|\
    x86_64:x86_64-unknown-linux-musl|\
    armhf:arm-unknown-linux-musleabihf|\
    aarch64:aarch64-unknown-linux-musl) ;;
    *)
        printf 'Toolchain triple %s does not match architecture %s\n' \
            "$TOOLCHAIN_TRIPLE" "$ARCHITECTURE" >&2
        exit 1
        ;;
esac

toolchain_root=${TOOLCHAIN_ROOT:-/opt/x-tools}
target_bindir="${toolchain_root}/${TOOLCHAIN_TRIPLE}/bin"
target_gcc="${target_bindir}/${TOOLCHAIN_TRIPLE}-gcc"
target_gxx="${target_bindir}/${TOOLCHAIN_TRIPLE}-g++"

if [ ! -x "$target_gcc" ] || [ ! -x "$target_gxx" ]; then
    printf 'Target compilers are missing from %s\n' "$target_bindir" >&2
    exit 1
fi
if [ "$("$target_gcc" -dumpmachine)" != "$TOOLCHAIN_TRIPLE" ]; then
    printf 'Target compiler reports an unexpected machine\n' >&2
    exit 1
fi

ln -sf "$target_gcc" /usr/local/bin/gcc
ln -sf "$target_gxx" /usr/local/bin/g++
ln -sf "$target_gcc" /usr/local/bin/cc
ln -sf "$target_gxx" /usr/local/bin/c++

for target_tool in ar as ld nm objcopy objdump ranlib readelf strip; do
    target_tool_path=$($target_gcc -print-prog-name="$target_tool")
    if [ ! -x "$target_tool_path" ]; then
        printf 'Target tool is not executable: %s\n' "$target_tool_path" >&2
        exit 1
    fi
    ln -sf "$target_tool_path" "/usr/local/bin/${TOOLCHAIN_TRIPLE}-${target_tool}"
done

#!/bin/sh
set -eu

target_gcc=/bin/static-toolbox-target-gcc
target_gxx=/bin/static-toolbox-target-g++
# build-base replaces /bin/gcc; preserve the image's target compilers first.
if [ ! -x "$target_gcc" ]; then
    cp /bin/gcc "$target_gcc"
    cp /bin/g++ "$target_gxx"
fi

apk add --no-cache \
    bash \
    build-base \
    git \
    perl \
    make \
    cmake \
    flex \
    bison \
    automake \
    autoconf \
    libtool \
    qemu-arm \
    qemu-aarch64 \
    file \
    binutils \
    texinfo \
    tar \
    zip \
    xz \
    bzip2 \
    coreutils \
    diffutils \
    findutils \
    gawk \
    curl \
    pkgconf \
    linux-headers \
    rsync \
    util-linux \
    patch

ln -sf "$target_gcc" /usr/local/bin/gcc
ln -sf "$target_gxx" /usr/local/bin/g++

target_triple=$("$target_gcc" -dumpmachine)
ln -sf "$target_gcc" "/usr/local/bin/${target_triple}-gcc"
ln -sf "$target_gcc" "/usr/local/bin/${target_triple}-cc"
ln -sf "$target_gxx" "/usr/local/bin/${target_triple}-g++"
ln -sf "$target_gxx" "/usr/local/bin/${target_triple}-c++"
for target_tool in ar as ld nm objcopy objdump ranlib readelf strip; do
    target_tool_path=$("$target_gcc" -print-prog-name="$target_tool")
    if [ ! -x "$target_tool_path" ]; then
        printf 'Target tool is not executable: %s\n' "$target_tool_path" >&2
        exit 1
    fi
    ln -sf "$target_tool_path" "/usr/local/bin/${target_triple}-${target_tool}"
done

#!/bin/sh
set -eu

apk add --no-cache \
    bash \
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

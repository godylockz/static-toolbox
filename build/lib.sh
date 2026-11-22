#!/usr/bin/env bash

LIB_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=build/versions.env
source "${LIB_DIRECTORY}/versions.env"

BUILD_DIRECTORY=${BUILD_DIRECTORY:-/build}
OUTPUT_DIRECTORY=${OUTPUT_DIRECTORY:-/output}
DOWNLOAD_DIRECTORY=${DOWNLOAD_DIRECTORY:-${BUILD_DIRECTORY}/downloads}
SOURCE_DIRECTORY=${SOURCE_DIRECTORY:-${BUILD_DIRECTORY}/sources}
DEPENDENCY_DIRECTORY=${DEPENDENCY_DIRECTORY:-${BUILD_DIRECTORY}/dependencies}
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')}

GCC_OPTS=${GCC_OPTS:--O2 -static -fPIC}
GXX_OPTS=${GXX_OPTS:--O2 -static -static-libstdc++ -fPIC}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

init_lib() {
    if [[ $# -ne 1 ]]; then
        die "init_lib requires an architecture"
    fi

    CURRENT_ARCH=$1
    case "$CURRENT_ARCH" in
        x86|x86_64|armhf|aarch64) ;;
        *) die "unsupported architecture: ${CURRENT_ARCH}" ;;
    esac

    mkdir -p "$BUILD_DIRECTORY" "$OUTPUT_DIRECTORY" "$DOWNLOAD_DIRECTORY" \
        "$SOURCE_DIRECTORY" "$DEPENDENCY_DIRECTORY"
    export CURRENT_ARCH
}

get_host_triple() {
    case "$CURRENT_ARCH" in
        x86) printf 'i686-unknown-linux-musl\n' ;;
        x86_64) printf 'x86_64-unknown-linux-musl\n' ;;
        armhf) printf 'arm-unknown-linux-musleabihf\n' ;;
        aarch64) printf 'aarch64-unknown-linux-musl\n' ;;
        *) die "unsupported architecture: ${CURRENT_ARCH:-unset}" ;;
    esac
}

get_build_triple() {
    printf 'x86_64-linux-gnu\n'
}

tool_version() {
    case "$1" in
        nmap) printf '%s\n' "$NMAP_VERSION" ;;
        tcpdump) printf '%s\n' "$TCPDUMP_VERSION" ;;
        openssh) printf '%s\n' "$OPENSSH_VERSION" ;;
        socat) printf '%s\n' "$SOCAT_VERSION" ;;
        gdb) printf '%s\n' "$GDB_VERSION" ;;
        strace) printf '%s\n' "$STRACE_VERSION" ;;
        tcpreplay) printf '%s\n' "$TCPREPLAY_VERSION" ;;
        *) die "unknown tool: $1" ;;
    esac
}

download_file() {
    if [[ $# -ne 3 ]]; then
        die "download_file requires URL, SHA-256, and destination"
    fi

    local url=$1
    local expected_sha256=$2
    local destination=$3
    local temporary_file="${destination}.partial.$$"

    mkdir -p "$(dirname -- "$destination")"
    if [[ ! -f "$destination" ]]; then
        curl --proto '=https' --tlsv1.2 --fail --location --show-error --silent \
            --retry 3 --output "$temporary_file" "$url"
        mv "$temporary_file" "$destination"
    fi

    printf '%s  %s\n' "$expected_sha256" "$destination" | sha256sum --check --status || \
        die "checksum verification failed for ${destination}"
}

prepare_archive() {
    if [[ $# -ne 4 ]]; then
        die "prepare_archive requires name, URL, SHA-256, and archive suffix"
    fi

    local name=$1
    local url=$2
    local expected_sha256=$3
    local suffix=$4
    local archive="${DOWNLOAD_DIRECTORY}/${name}-${suffix}"
    local destination="${SOURCE_DIRECTORY}/${name}"
    local completion_marker="${destination}/.static-toolbox-extracted"

    if [[ -f "$completion_marker" ]]; then
        return
    fi

    download_file "$url" "$expected_sha256" "$archive"
    mkdir -p "$destination"
    tar --extract --file "$archive" --directory "$destination" --strip-components=1
    touch "$completion_marker"
}

prepare_git_source() {
    if [[ $# -ne 3 ]]; then
        die "prepare_git_source requires name, repository URL, and commit"
    fi

    local name=$1
    local repository_url=$2
    local expected_commit=$3
    local destination="${SOURCE_DIRECTORY}/${name}"

    if [[ -d "${destination}/.git" ]]; then
        local existing_commit
        existing_commit=$(git -C "$destination" rev-parse HEAD)
        [[ "$existing_commit" == "$expected_commit" ]] || \
            die "unexpected ${name} commit: ${existing_commit}"
        return
    fi

    mkdir -p "$destination"
    git -C "$destination" init --quiet
    git -C "$destination" remote add origin "$repository_url"
    git -C "$destination" fetch --quiet --depth=1 origin "$expected_commit"
    git -C "$destination" checkout --quiet --detach FETCH_HEAD

    local actual_commit
    actual_commit=$(git -C "$destination" rev-parse HEAD)
    [[ "$actual_commit" == "$expected_commit" ]] || \
        die "commit verification failed for ${name}"
}

create_stage() {
    if [[ $# -ne 2 ]]; then
        die "create_stage requires tool and version"
    fi

    STAGE_DIRECTORY="${OUTPUT_DIRECTORY}/$1-$2-linux-${CURRENT_ARCH}"
    if [[ -e "$STAGE_DIRECTORY" ]]; then
        die "staging directory already exists: ${STAGE_DIRECTORY}"
    fi
    mkdir -p "${STAGE_DIRECTORY}/bin" "${STAGE_DIRECTORY}/LICENSES"
    cp "${LIB_DIRECTORY}/versions.env" "${STAGE_DIRECTORY}/SOURCE-MANIFEST.env"
    export STAGE_DIRECTORY
}

copy_license() {
    if [[ $# -ne 3 ]]; then
        die "copy_license requires source directory, source file, and output name"
    fi
    cp "$1/$2" "${STAGE_DIRECTORY}/LICENSES/$3"
}

strip_binary() {
    if [[ $# -ne 1 || ! -f $1 ]]; then
        die "cannot strip missing binary: ${1:-unset}"
    fi
    local strip_tool
    strip_tool=$(gcc -print-prog-name=strip)
    [[ -x "$strip_tool" ]] || die "target strip tool is not executable: ${strip_tool}"
    "$strip_tool" "$1"
}

get_static_atomic_archive() {
    local atomic_archive
    atomic_archive=$(gcc -print-file-name=libatomic.a)
    [[ -f "$atomic_archive" ]] || die "static libatomic archive not found: ${atomic_archive}"
    printf '%s\n' "$atomic_archive"
}

install_host_toolchain() {
    HOST_CC=/usr/bin/gcc
    HOST_CXX=/usr/bin/g++
    [[ -x "$HOST_CC" ]] || die "native build compiler is not installed: ${HOST_CC}"
    [[ -x "$HOST_CXX" ]] || die "native build compiler is not installed: ${HOST_CXX}"
    export HOST_CC HOST_CXX
}

lib_build_openssl() {
    OPENSSL_PREFIX="${DEPENDENCY_DIRECTORY}/openssl-${CURRENT_ARCH}"
    if [[ -f "${OPENSSL_PREFIX}/lib/libssl.a" ]]; then
        export OPENSSL_PREFIX
        return
    fi

    prepare_archive "openssl-${OPENSSL_VERSION}" "$OPENSSL_SOURCE_URL" \
        "$OPENSSL_SOURCE_SHA256" "openssl-${OPENSSL_VERSION}.tar.gz"
    local source_dir="${SOURCE_DIRECTORY}/openssl-${OPENSSL_VERSION}"
    local openssl_target
    case "$CURRENT_ARCH" in
        x86) openssl_target=linux-generic32 ;;
        armhf) openssl_target=linux-armv4 ;;
        x86_64) openssl_target=linux-x86_64 ;;
        aarch64) openssl_target=linux-aarch64 ;;
    esac

    pushd "$source_dir" >/dev/null || return
    CC=gcc CFLAGS="$GCC_OPTS" ./Configure "$openssl_target" no-shared no-tests \
        --prefix="$OPENSSL_PREFIX" --openssldir=/etc/ssl --libdir=lib
    make -j"$JOBS" build_libs
    make install_dev
    popd >/dev/null || return
    export OPENSSL_PREFIX
}

lib_build_zlib() {
    ZLIB_PREFIX="${DEPENDENCY_DIRECTORY}/zlib-${CURRENT_ARCH}"
    if [[ -f "${ZLIB_PREFIX}/lib/libz.a" ]]; then
        export ZLIB_PREFIX
        return
    fi

    prepare_archive "zlib-${ZLIB_VERSION}" "$ZLIB_SOURCE_URL" \
        "$ZLIB_SOURCE_SHA256" "zlib-${ZLIB_VERSION}.tar.gz"
    local source_dir="${SOURCE_DIRECTORY}/zlib-${ZLIB_VERSION}"
    pushd "$source_dir" >/dev/null || return
    CC=gcc CFLAGS="$GCC_OPTS" ./configure --static --prefix="$ZLIB_PREFIX"
    make -j"$JOBS"
    make install
    popd >/dev/null || return
    export ZLIB_PREFIX
}

lib_build_libpcap() {
    LIBPCAP_PREFIX="${DEPENDENCY_DIRECTORY}/libpcap-${CURRENT_ARCH}"
    if [[ -f "${LIBPCAP_PREFIX}/lib/libpcap.a" ]]; then
        export LIBPCAP_PREFIX
        return
    fi

    prepare_archive "libpcap-${LIBPCAP_VERSION}" "$LIBPCAP_SOURCE_URL" \
        "$LIBPCAP_SOURCE_SHA256" "libpcap-${LIBPCAP_VERSION}.tar.xz"
    local source_dir="${SOURCE_DIRECTORY}/libpcap-${LIBPCAP_VERSION}"
    pushd "$source_dir" >/dev/null || return
    CC=gcc CFLAGS="$GCC_OPTS" LDFLAGS=-static ./configure \
        --build="$(get_build_triple)" \
        --host="$(get_host_triple)" \
        --prefix="$LIBPCAP_PREFIX" \
        --disable-shared \
        --disable-bluetooth \
        --disable-dbus \
        --disable-netmap \
        --disable-rdma \
        --disable-usb \
        --without-libnl
    make -j"$JOBS"
    make install
    popd >/dev/null || return
    export LIBPCAP_PREFIX
}

lib_build_gmp() {
    GMP_PREFIX="${DEPENDENCY_DIRECTORY}/gmp-${CURRENT_ARCH}"
    if [[ -f "${GMP_PREFIX}/lib/libgmp.a" ]]; then
        export GMP_PREFIX
        return
    fi

    prepare_archive "gmp-${GMP_VERSION}" "$GMP_SOURCE_URL" \
        "$GMP_SOURCE_SHA256" "gmp-${GMP_VERSION}.tar.xz"
    local source_dir="${SOURCE_DIRECTORY}/gmp-${GMP_VERSION}"
    local build_dir="${BUILD_DIRECTORY}/gmp-build-${CURRENT_ARCH}"
    mkdir -p "$build_dir"
    pushd "$build_dir" >/dev/null || return
    CC=gcc CFLAGS="$GCC_OPTS" LDFLAGS=-static "$source_dir/configure" \
        --build="$(get_build_triple)" \
        --host="$(get_host_triple)" \
        --prefix="$GMP_PREFIX" \
        --disable-shared \
        --enable-static
    make -j"$JOBS"
    make install
    popd >/dev/null || return
    export GMP_PREFIX
}

lib_build_mpfr() {
    MPFR_PREFIX="${DEPENDENCY_DIRECTORY}/mpfr-${CURRENT_ARCH}"
    if [[ -f "${MPFR_PREFIX}/lib/libmpfr.a" ]]; then
        export MPFR_PREFIX
        return
    fi

    [[ -n ${GMP_PREFIX:-} ]] || die "GMP must be built before MPFR"
    prepare_archive "mpfr-${MPFR_VERSION}" "$MPFR_SOURCE_URL" \
        "$MPFR_SOURCE_SHA256" "mpfr-${MPFR_VERSION}.tar.xz"
    local source_dir="${SOURCE_DIRECTORY}/mpfr-${MPFR_VERSION}"
    local build_dir="${BUILD_DIRECTORY}/mpfr-build-${CURRENT_ARCH}"
    mkdir -p "$build_dir"
    pushd "$build_dir" >/dev/null || return
    CC=gcc CFLAGS="$GCC_OPTS" LDFLAGS=-static "$source_dir/configure" \
        --build="$(get_build_triple)" \
        --host="$(get_host_triple)" \
        --prefix="$MPFR_PREFIX" \
        --with-gmp="$GMP_PREFIX" \
        --disable-shared \
        --enable-static
    make -j"$JOBS"
    make install
    popd >/dev/null || return
    export MPFR_PREFIX
}

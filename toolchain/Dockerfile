FROM debian:13-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

ARG DEBIAN_FRONTEND=noninteractive
ARG TOOLCHAIN_RELEASE
ARG TOOLCHAIN_SHA256
ARG TOOLCHAIN_TRIPLE

LABEL org.opencontainers.image.source="https://github.com/godylockz/static-toolbox" \
      org.opencontainers.image.description="Pinned musl cross-toolchain for static-toolbox" \
      org.opencontainers.image.licenses="MIT"

RUN set -eux; \
    apt-get update; \
    apt-get upgrade --yes; \
    apt-get install --yes --no-install-recommends \
        autoconf \
        automake \
        bash \
        binutils \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        cmake \
        coreutils \
        curl \
        diffutils \
        file \
        findutils \
        flex \
        gawk \
        git \
        libtool \
        linux-libc-dev \
        make \
        patch \
        perl \
        pkg-config \
        qemu-user \
        rsync \
        tar \
        texinfo \
        util-linux \
        xz-utils \
        zip; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "$TOOLCHAIN_TRIPLE" in \
        i686-unknown-linux-musl|x86_64-unknown-linux-musl|arm-unknown-linux-musleabihf|aarch64-unknown-linux-musl) ;; \
        *) printf 'Unsupported toolchain triple: %s\n' "$TOOLCHAIN_TRIPLE" >&2; exit 1 ;; \
    esac; \
    printf '%s\n' "$TOOLCHAIN_SHA256" | grep -Eq '^[0-9a-f]{64}$'; \
    archive=/tmp/toolchain.tar.xz; \
    curl --proto '=https' --tlsv1.2 --fail --location --show-error --silent \
        --retry 3 --output "$archive" \
        "https://github.com/cross-tools/musl-cross/releases/download/${TOOLCHAIN_RELEASE}/${TOOLCHAIN_TRIPLE}.tar.xz"; \
    printf '%s  %s\n' "$TOOLCHAIN_SHA256" "$archive" | sha256sum --check; \
    mkdir -p /opt/x-tools; \
    tar --extract --xz --file "$archive" --directory /opt/x-tools; \
    rm "$archive"; \
    compiler="/opt/x-tools/${TOOLCHAIN_TRIPLE}/bin/${TOOLCHAIN_TRIPLE}-gcc"; \
    test -x "$compiler"; \
    test "$("$compiler" -dumpmachine)" = "$TOOLCHAIN_TRIPLE"; \
    printf 'int main(void) { return 0; }\n' | "$compiler" -static -x c - -o /tmp/toolchain-smoke; \
    ! readelf --program-headers /tmp/toolchain-smoke | grep -q INTERP; \
    rm /tmp/toolchain-smoke

ENV TOOLCHAIN_TRIPLE=${TOOLCHAIN_TRIPLE}
ENV PATH=/opt/x-tools/${TOOLCHAIN_TRIPLE}/bin:${PATH}

CMD ["/bin/bash"]

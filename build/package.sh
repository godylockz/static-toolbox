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
package_directory=${PACKAGE_DIRECTORY:-/packaged}

if [[ ! -d "$stage_directory" ]]; then
    printf 'Missing stage directory: %s\n' "$stage_directory" >&2
    exit 1
fi

mkdir -p "$package_directory"
archive_name="${tool}-${version}-linux-${architecture}-static.tar.gz"
archive_path="${package_directory}/${archive_name}"

{
    printf 'tool=%s\n' "$tool"
    printf 'version=%s\n' "$version"
    printf 'architecture=%s\n' "$architecture"
    printf 'libc=musl\n'
    printf 'linkage=static\n'
    printf 'toolchain_image=%s\n' "${TOOLCHAIN_IMAGE:-unknown}"
    printf 'source_commit=%s\n' "${GITHUB_SHA:-unknown}"
} >"${stage_directory}/BUILD-INFO"

tar --create --gzip \
    --sort=name \
    --mtime='UTC 1970-01-01' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    --file "$archive_path" \
    --directory "$(dirname -- "$stage_directory")" \
    "$(basename -- "$stage_directory")"

pushd "$package_directory" >/dev/null
sha256sum "$archive_name" >"${archive_name}.sha256"
popd >/dev/null

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
    {
        printf 'ARTIFACT_NAME=%s\n' "${tool}-${version}-linux-${architecture}-static"
        printf 'ARTIFACT_PATH=%s\n' "$package_directory"
        printf 'PACKAGED_VERSION=%s\n' "$version"
    } >>"$GITHUB_OUTPUT"
fi

#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
apk add --no-cache bash
exec "$script_dir/install_deps_alpine.sh"

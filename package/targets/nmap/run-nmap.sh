#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
export NMAPDIR="${script_dir}/share/nmap"
exec "${script_dir}/bin/nmap" "$@"

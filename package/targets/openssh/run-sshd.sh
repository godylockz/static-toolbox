#!/bin/sh
set -eu

archive_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

exec "$archive_directory/bin/sshd" \
    -o "SshdAuthPath=$archive_directory/bin/sshd-auth" \
    -o "SshdSessionPath=$archive_directory/bin/sshd-session" \
    "$@"

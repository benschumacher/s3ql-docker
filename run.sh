#!/bin/sh
set -eu
set -o pipefail

RANDOM="$(od -vAn -N4 -tu4 < /dev/urandom)"

S3QL_AUTHFILE="${S3QL_AUTHFILE:-/etc/s3ql.authinfo2}"
S3QL_OPTS="${S3QL_OPTS:-}"
S3QL_LOG_OUTPUT="${S3QL_LOG_OUTPUT:-/.s3ql/s3ql.log}"

S3QL_STAT_SECS="${S3QL_STAT_PERIOD:-$((RANDOM % 300 + 1650))}"
# alternate
#S3QL_STAT_SECS="${S3QL_STAT_SECS:-$((1800 + $(od -vAn -N1 -td1 < /dev/urandom)))}"

S3QL_STORAGE_URL="${1:-}"
S3QL_MOUNTPOINT="${2:-}"

if [ ! -x "$1" ]; then
    trap "umount.s3ql --log=\"${S3QL_LOG_OUTPUT}\" \"${S3QL_MOUNTPOINT}\" && fusermount3 -u /mnt/media" INT
    trap "echo EXIT" EXIT
    trap "echo TERM" TERM

    fsck.s3ql --authfile="${S3QL_AUTHFILE}" --log="${S3QL_LOG_OUTPUT}" \
        "${S3QL_STORAGE_URL}" | tai64n
    mount.s3ql ${S3QL_OPTS} --authfile="${S3QL_AUTHFILE}" \
        --log="${S3QL_LOG_OUTPUT}" "${S3QL_STORAGE_URL}" "${S3QL_MOUNTPOINT}" | tai64n
    ((while :; do echo; s3qlstat "${S3QL_MOUNTPOINT}"; sleep 300; done) | tai64n) &

    sleep INF
else
    exec "$@"
fi


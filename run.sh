#!/bin/sh
set -e

S3QL_AUTHFILE="${S3QL_AUTHFILE:-/etc/s3ql.authinfo2}"
S3QL_OPTS="${S3QL_OPTS:-}"
S3QL_LOG_OUTPUT="${S3QL_LOG_OUTPUT:-/var/log/s3ql.log}"
S3QL_STORAGE_URL="$1"
S3QL_MOUNTPOINT="$2"

if [ ! -x "$1" ]; then
    trap "umount.s3ql \"${S3QL_MOUNTPOINT}\"" INT

    fsck.s3ql --authfile="${S3QL_AUTHFILE}" --log="${S3QL_LOG_OUTPUT}" \
        "${S3QL_STORAGE_URL}"
    mount.s3ql --allow-other --authfile="${S3QL_AUTHFILE}" \
        --log="${S3QL_LOG_OUTPUT}" "${S3QL_STORAGE_URL}" "${S3QL_MOUNTPOINT}"
    ((while :; do echo; s3qlstat "${S3QL_MOUNTPOINT}"; sleep 300; done) | tai64n) &

    sleep INF
else
    exec "$@"
fi


#!/bin/sh
# vim: set shiftwidth=4:
set -eu
set -o pipefail

[ -z "${S3QL_DEBUG:-}" ] || set -x

PID=0
RANDOM="$(od -vAn -N4 -tu4 < /dev/urandom)"
S3QL_AUTHFILE="${S3QL_AUTHFILE:-/etc/s3ql.authinfo2}"
S3QL_OPTS="${S3QL_OPTS:-}"
S3QL_LOG_OUTPUT="${S3QL_LOG_OUTPUT:-/.s3ql/s3ql.log}"

S3QL_STAT_SECS="${S3QL_STAT_PERIOD:-$((RANDOM % 300 + 1650))}"
# alternate
#S3QL_STAT_SECS="${S3QL_STAT_SECS:-$((1800 + $(od -vAn -N1 -td1 < /dev/urandom)))}"

S3QL_STORAGE_URL="${1:-}"
S3QL_MOUNTPOINT="${2:-}"

monitor() {
    while ! mountpoint $S3QL_MOUNTPOINT >/dev/null; do
	echo "not mountpoint"
	sleep 1
    done
    while mountpoint $S3QL_MOUNTPOINT >/dev/null; do
	echo "*** HEALTHCHECK"; s3qlstat "${S3QL_MOUNTPOINT}"; sleep ${S3QL_STAT_SECS} | tai64n
    done &
}

if [ ! -x "$1" ]; then
    trap "mountpoint \"${S3QL_MOUNTPOINT}\" && (umount.s3ql \"${S3QL_MOUNTPOINT}\" ; fusermount3 -u \"${S3QL_MOUNTPOINT}\")" INT
    trap "echo EXIT" EXIT
    trap "echo TERM" TERM

    echo $S3QL_MOUNTPOINT > /var/mountpoint

    fsck.s3ql --authfile="${S3QL_AUTHFILE}" --log="${S3QL_LOG_OUTPUT}" \
        "${S3QL_STORAGE_URL}" | tai64n
    (mount.s3ql ${S3QL_OPTS} --fg --authfile="${S3QL_AUTHFILE}" \
	--log="${S3QL_LOG_OUTPUT}" "${S3QL_STORAGE_URL}" "${S3QL_MOUNTPOINT}" | tai64n) & PID=$!
    (sleep 30; while :; do echo "*** HEALTHCHECK"; s3qlstat "${S3QL_MOUNTPOINT}"; sleep ${S3QL_STAT_SECS}; done) | tai64n &

    wait $PID
    #sleep INF
else
    exec "$@"
fi


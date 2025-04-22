ARG S3QL_VERSION=3.8.1
ARG S3QL_UID=911

FROM python:3.10-alpine as builder

ARG BUILD_DATE
ARG S3QL_VERSION
ENV S3QL_VERSION ${S3QL_VERSION}

RUN    set -ex \
    && env \
    && apk upgrade --no-cache --available \
    && apk add --no-cache psmisc libressl libffi sqlite-dev fuse3 dumb-init \
    && apk add --no-cache -U --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing daemontools \
    && apk add --no-cache --virtual .build-deps curl \
    && curl -Lf -o s3ql.tar.gz https://github.com/s3ql/s3ql/releases/download/release-${S3QL_VERSION}/s3ql-${S3QL_VERSION}.tar.gz \ 
    && mkdir -p /usr/src/s3ql \
    && tar -mx -C /usr/src/s3ql --strip 1 -f s3ql.tar.gz \
    && rm s3ql.tar.gz \
    && python -m venv /.local \
    && source /.local/bin/activate \
    && apk add --no-cache --virtual .build-deps \
         build-base \
         cargo \
         curl \
         findutils \
         fuse3-dev \
         libffi-dev \
         openssl-dev \
         sqlite-dev \
    && pip install --upgrade --no-cache-dir pip wheel \
    && pip install --no-cache-dir \
         cryptography \
         defusedxml \
         apsw \
         trio \
         pyfuse3 \
         dugong \
         pytest \
         async_generator \
         requests \
         google-auth \
         google-auth-oauthlib \
    && cd /usr/src/s3ql \
    && python setup.py build_ext --inplace \
    && python setup.py install \
    && find /.local /usr/local -depth \
         \( \
              \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
           -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
         \) -exec rm -vrf '{}' + \
    \
    && true

FROM python:3.10-alpine

ARG S3QL_VERSION
ARG S3QL_UID
ENV S3QL_UID ${S3QL_UID}

LABEL build_version="s3ql-docker python-version: ${PYTHON_VERSION} s3ql-version: ${S3QL_VERSION} build-date: ${BUILD_DATE}"

RUN    set -ex \
    && apk upgrade --no-cache --available \
    && apk add --no-cache psmisc libressl libffi sqlite-dev fuse3 dumb-init \
    && apk add --no-cache -U --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing daemontools

COPY --from=builder /.local /.local
COPY run.sh /run.sh

RUN    set -ex \ 
    && ln -nsf /usr/bin/fusermount3 /.local/bin/fusermount \
    && addgroup -g ${S3QL_UID} -S s3ql && adduser -u ${S3QL_UID} -G s3ql -H -S s3ql \
    && touch /var/mountpoint && chown ${S3QL_UID}:${S3QL_UID} /var/mountpoint

USER s3ql
ENV PATH=/.local/bin:$PATH
ENV HOME=/
RUN mount.s3ql --version

HEALTHCHECK --interval=5m --start-period=30s \
    CMD s3qlstat "$(cat /var/mountpoint)"
ENTRYPOINT ["/usr/bin/dumb-init", "--rewrite=15:2", "--", "/run.sh"]

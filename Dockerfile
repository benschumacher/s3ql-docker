FROM python:3.9-alpine

COPY run.sh /run.sh
RUN    set -ex \
    && env \
    && apk upgrade --no-cache --available \
    && apk add --no-cache psmisc libressl libffi sqlite-dev fuse3 dumb-init \
    && apk add --no-cache -U --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing daemontools \
    && apk add --no-cache --virtual .build-deps curl \
    && curl -L -o s3ql.tar.bz2 https://github.com/s3ql/s3ql/releases/download/release-3.7.3/s3ql-3.7.3.tar.bz2 \ 
    && mkdir -p /usr/src/s3ql \
    && tar -x -C /usr/src/s3ql --strip 1 -f s3ql.tar.bz2 \
    && rm s3ql.tar.bz2 \
    && python -m venv /.local \
    && source /.local/bin/activate \
    && apk add --no-cache --virtual .build-deps \
         build-base \
         cargo \
         curl \
         findutils \
         fuse3-dev \
         libffi-dev \
         libressl-dev \
         sqlite-dev \
    && pip install --upgrade --no-cache-dir pip wheel \
    && pip install --no-cache-dir \
         cython \
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
    && true
RUN    set -ex \
    && cd /usr/src/s3ql \
    && source /.local/bin/activate \
    && python setup.py build_ext --inplace \
    && python setup.py install \
    && cd / \
    && rm -rf /usr/src/s3ql \
    && find /.local /usr/local -depth \
         \( \
              \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
           -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
         \) -exec rm -rf '{}' + \
    \
    && apk del --no-network .build-deps \
    && mount.s3ql --version

ENV PATH=/.local/bin:$PATH
ENTRYPOINT ["/usr/bin/dumb-init", "--rewrite=15:2", "--", "/run.sh"]

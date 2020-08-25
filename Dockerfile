FROM python:3-alpine

ENV PATH=/usr/local/.venv/bin:$PATH
RUN    set -ex \
    && apk upgrade --no-cache --available \
    && apk add --no-cache psmisc libressl libffi sqlite-dev fuse3 \
    && apk add --no-cache --virtual .build-deps curl \
    && curl -L -o s3ql.tar.bz2 https://github.com/s3ql/s3ql/releases/download/release-3.5.0/s3ql-3.5.0.tar.bz2 \ 
    && mkdir -p /usr/src/s3ql \
    && tar -x -C /usr/src/s3ql --strip 1 -f s3ql.tar.bz2 \
    && rm s3ql.tar.bz2 \
    && python -m venv /.local \
    && source /.local/bin/activate \
    && apk add --no-cache --virtual .build-deps \
         build-base curl libressl-dev libffi-dev sqlite-dev fuse3-dev \
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
         pytest_trio \
         Sphinx \
    && true 
RUN    set -ex \
    && cd /usr/src/s3ql \
    && source /.local/bin/activate \
    && python setup.py build_ext --inplace \
    && python setup.py install \
    && rm -rf /usr/src/s3ql \
    && apk del .build-deps \
    && mount.s3ql --version  \
    && true

ENV PATH=/usr/local/.venv/bin:$PATH
CMD ["/bin/sh"]

FROM python:3-alpine
WORKDIR /src
RUN    apk upgrade --no-cache --available \
    && apk add --no-cache psmisc libressl libffi sqlite fuse3 \
    && apk add --no-cache --virtual .build-deps \
         build-base curl libressl-dev libffi-dev sqlite-dev fuse3-dev \
    && curl -OL https://github.com/s3ql/s3ql/releases/download/release-3.5.0/s3ql-3.5.0.tar.bz2 \ 
    && tar -xv --strip 1 -f s3ql-3.5.0.tar.bz2 \
    && python -m venv /.local \
    && source /.local/bin/activate \
    && pip install --upgrade pip wheel \
    && pip install --upgrade \
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
         sphinx \
    && true 
RUN    python -m venv /.local  \
    && source /.local/bin/activate \
    && python setup.py build_ext --inplace \
    && apk del .build-deps \
    && python setup.py install \
    && true

CMD ["/bin/sh"]

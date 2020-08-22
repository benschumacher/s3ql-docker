FROM python:3-alpine

WORKDIR /src
RUN    apk upgrade --available \
    && apk add build-base curl libressl-dev libffi-dev sqlite-dev psmisc \
         fuse3-dev \
    && curl -OL https://github.com/s3ql/s3ql/releases/download/release-3.5.0/s3ql-3.5.0.tar.bz2 \ 
    && tar -xvf s3ql-3.5.0.tar.bz2 \
    && true
RUN    python -m venv /build \
    && source /build/bin/activate \
    && pip install wheel \
    && pip install \
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
RUN    cd /src/s3ql-3.5.0 \
    && source /build/bin/activate \
    && python setup.py build_ext --inplace \
    && python setup.py install

CMD ["/bin/sh"]

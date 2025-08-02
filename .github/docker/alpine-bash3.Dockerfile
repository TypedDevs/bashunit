FROM frolvlad/alpine-glibc

# Install build tools and dependencies
RUN apk add --no-cache build-base wget git make \
    && wget https://ftp.gnu.org/gnu/bash/bash-3.0.tar.gz \
    && tar -xzf bash-3.0.tar.gz \
    && cd bash-3.0 \
    && ./configure --prefix=/usr \
    && make \
    && make install \
    && /usr/bin/bash --version \
    && cd .. \
    && rm -rf bash-3.0 bash-3.0.tar.gz \
    && apk del build-base wget

WORKDIR /project
CMD ["/usr/bin/bash"]

FROM alpine:3.19

# Install build tools and dependencies
RUN apk add --no-cache build-base wget git make \
    && wget https://ftp.gnu.org/gnu/bash/bash-3.0.tar.gz \
    && tar -xzf bash-3.0.tar.gz \
    && cd bash-3.0 \
    && ./configure --prefix=/usr \
    && make \
    && make install \
    && cd .. \
    && rm -rf bash-3.0 bash-3.0.tar.gz \
    && apk del build-base wget

WORKDIR /project
CMD ["/bin/bash"]

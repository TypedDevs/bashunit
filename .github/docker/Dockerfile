# Stage 1: Build Bash 3.0 on Ubuntu
FROM ubuntu:20.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        ca-certificates && \
    wget https://ftp.gnu.org/gnu/bash/bash-3.0.tar.gz && \
    tar -xzf bash-3.0.tar.gz && \
    cd bash-3.0 && \
    ./configure --prefix=/bash3 --build=x86_64-unknown-linux-gnu && \
    make && make install && \
    cd .. && \
    rm -rf bash-3.0*

# Stage 2: Minimal Alpine with Bash 3.0
FROM alpine:3.18

# Copy compiled Bash 3.0 from the builder
COPY --from=builder /bash3 /bash3

# Create the canonical /usr/bin/bash symlink
RUN ln -sf /bash3/bin/bash /usr/bin/bash

# Optional: Test version
RUN /usr/bin/bash --version

WORKDIR /project
CMD ["/usr/bin/bash"]

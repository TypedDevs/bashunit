FROM ubuntu:20.04

# Install build tools
RUN apt-get update && \
    apt-get install -y build-essential wget && \
    wget https://ftp.gnu.org/gnu/bash/bash-3.0.tar.gz && \
    tar -xzf bash-3.0.tar.gz && \
    cd bash-3.0 && \
    ./configure --prefix=/opt/bash-3.0 && \
    make && make install && \
    ln -s /opt/bash-3.0/bin/bash /usr/bin/bash3 && \
    cd .. && rm -rf bash-3.0*

CMD ["/usr/bin/bash3"]

# docker build -f alpine-bash3.Dockerfile -t chemaclass/bash-3.0:alpine-glibc .

FROM ubuntu:24.04

RUN apt-get update && \
    apt-get -y install sudo curl git python3-pip unzip && \
    apt-get -y install software-properties-common ansible-core && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m lmm-test && echo "lmm-test:lmm-test" | chpasswd && adduser lmm-test sudo \
    && echo 'lmm-test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

ENV PATH="${PATH}:/home/lmm-test/.local/bin"

RUN install -g lmm-test -o lmm-test -d /opt/lmm /home/lmm-test/.local /home/lmm-test/.local/bin /home/lmm-test/.local/share /home/lmm-test/.local/share/applications

USER lmm-test
ENV USER=lmm-test
WORKDIR /opt/lmm

CMD ./test.sh

FROM ubuntu:22.04

RUN apt-get update && \
    apt-get -y install sudo curl git python3-pip unzip \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m lmm-test && echo "lmm-test:lmm-test" | chpasswd && adduser lmm-test sudo \
    && echo 'lmm-test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN pip3 install ansible
ENV PATH="${PATH}:/home/lmm-test/.local/bin"

RUN install -g lmm-test -o lmm-test -d /opt/lmm /home/lmm-test/.local /home/lmm-test/.local/bin /home/lmm-test/.local/share /home/lmm-test/.local/share/applications

COPY ./test/test.sh ./lmm.sh /opt/lmm/
COPY ./roles /opt/lmm/roles

USER lmm-test
ENV USER=lmm-test
WORKDIR /opt/lmm

RUN ./lmm.sh version

CMD ./test.sh

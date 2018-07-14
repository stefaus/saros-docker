# Docker File for saros-eclipse
FROM ubuntu:16.04
LABEL maintainer="Stefan Moll <stefan@stefaus.de>"

# install packages

# your username and ids to remain file rights
ARG USERNAME
ARG USERID

# group id should be fine...
ARG GROUPID=1000

RUN useradd -m $USERNAME && \
    echo "$USERNAME:$USERNAME" | chpasswd && \
    usermod --shell /bin/bash $USERNAME && \
    usermod  --uid $USERID $USERNAME && \
    groupmod --gid $GROUPID $USERNAME

RUN apt-get update -o Acquire::ForceIPv4=true && apt-get install -o Acquire::ForceIPv4=true -y iproute2 iputils-ping libxext-dev \
                      libxrender-dev libxtst-dev libgtk2.0-0 iperf3 \
                   && apt-get clean \
                   && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER $USERNAME

CMD ["bash"]


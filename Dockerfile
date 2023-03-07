FROM ubuntu:jammy

ARG TARGETARCH arm64
ENV ARCH=${TARGETARCH}

ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    autoconf \
    bc \
    bison \
    build-essential \
    cpio \
    debhelper \
    dkms \
    fakeroot \
    flex \
    gawk \
    git \
    kernel-wedge \
    kmod \
    libelf-dev \
    libiberty-dev \
    libncurses-dev \
    libpci-dev \
    libssl-dev \
    libudev-dev \
    llvm \
    openssl \
    pahole \
    python3 \
    rsync \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m admin

USER admin

WORKDIR /home/admin

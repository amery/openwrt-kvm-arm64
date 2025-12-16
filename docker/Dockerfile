FROM quay.io/amery/docker-ubuntu-builder:24.04

# OpenWrt build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libncurses-dev \
    python3-dev \
    python3-pyelftools \
    rsync \
    swig \
    unzip \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM debian:sid-slim
#FROM --platform=linux/amd64 debian:sid-slim

ARG ZIG_VERSION=0.14.1

RUN DEBIAN_FRONTEND="noninteractive" apt-get update -y && apt-get -y install tzdata

RUN apt-get install -y \
    build-essential \
    tar \
    curl \
    libwayland-dev \
    libglx-dev \
    libx11-dev \
    libxcursor-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxinerama-dev \
    libxrandr-dev \
    libxrender-dev \
    libegl-dev \
    libxkbcommon-dev \
    libwayland-client0 \
    libc6-dev
RUN apt-get clean


# Install Zig
WORKDIR /
RUN curl "https://ziglang.org/download/${ZIG_VERSION}/zig-$(uname -m)-linux-${ZIG_VERSION}.tar.xz" -O
RUN tar xf zig-$(uname -m)-linux-${ZIG_VERSION}.tar.xz
RUN mv zig-$(uname -m)-linux-${ZIG_VERSION} zig
ENV PATH="$PATH:/zig"


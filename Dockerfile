# Copyright © SixtyFPS GmbH <info@slint.dev>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-Slint-Royalty-free-1.1 OR LicenseRef-Slint-commercial

# This docker file builds the Rust binaries for the robot demos and packages them into a Torizon container

ARG TOOLCHAIN_ARCH=arm64
ARG IMAGE_ARCH=linux/arm64
ARG BASE_NAME=wayland-base
FROM torizon/debian-cross-toolchain-$TOOLCHAIN_ARCH:3-bookworm AS build
ARG TOOLCHAIN_ARCH
ARG RUST_TOOLCHAIN_ARCH=aarch64-unknown-linux-gnu

# Install Rust
ENV RUSTUP_HOME=/rust
ENV CARGO_HOME=/cargo
ENV PATH=/cargo/bin:/rust/bin:$PATH

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
RUN rustup target add $RUST_TOOLCHAIN_ARCH

ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
ENV CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc

# Install Slint build dependencies (libxcb, etc.)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes --allow-change-held-packages pkg-config libfontconfig1-dev:$TOOLCHAIN_ARCH libxcb1-dev:$TOOLCHAIN_ARCH libxcb-render0-dev:$TOOLCHAIN_ARCH libxcb-shape0-dev:$TOOLCHAIN_ARCH libxcb-xfixes0-dev:$TOOLCHAIN_ARCH libxkbcommon-dev:$TOOLCHAIN_ARCH libinput-dev:$TOOLCHAIN_ARCH libudev-dev:$TOOLCHAIN_ARCH libgbm-dev:$TOOLCHAIN_ARCH libdrm2:$TOOLCHAIN_ARCH libdrm2- libdrm-amdgpu1- python3 clang libstdc++-11-dev:$TOOLCHAIN_ARCH && \
    rm -rf /var/lib/apt/lists/*

# Don't require font-config when the compiler runs
ENV RUST_FONTCONFIG_DLOPEN=on
ENV PKG_CONFIG_ALLOW_CROSS=1

# Build Demo
COPY . /demo
WORKDIR /demo
RUN mkdir binary && \
    cargo build --release --target $RUST_TOOLCHAIN_ARCH --features slint/renderer-skia,slint/backend-linuxkms-noseat || exit 1; \
    cp target/$RUST_TOOLCHAIN_ARCH/release/robo-face ./binary/;

# Create container for target
FROM --platform=$IMAGE_ARCH torizon/$BASE_NAME:3

LABEL org.opencontainers.image.source=https://github.com/slint-ui/slint
LABEL org.opencontainers.image.description="Container image providing Slint Robot Demo for use on Torizon. Run with docker run  --user=torizon -v /run/udev:/run/udev -v /dev:/dev -v /tmp:/tmp --device-cgroup-rule='c 199:* rmw' --device-cgroup-rule='c 226:* rmw' --device-cgroup-rule='c 13:* rmw' --device-cgroup-rule='c 4:* rmw'"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install libfontconfig1 libxkbcommon0 libinput10 fonts-noto-core fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji fonts-noto-ui-core fonts-noto-ui-extra \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /demo/binary/* /usr/bin/

ENV SLINT_FULLSCREEN=1
ENV SLINT_BACKEND=winit-skia

CMD /usr/bin/robo-face

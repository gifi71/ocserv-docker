ARG S6_OVERLAY_VERSION=3.2.1.0
ARG OCSERV_VERSION=1.3.0
ARG OCSERV_EXPORTER_VERSION=0.2.1

FROM debian:bookworm-slim AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

FROM base AS s6-builder
ARG S6_OVERLAY_VERSION
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -x \
 && apt-get update \
 && apt-get upgrade -y -qq \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    wget ca-certificates xz-utils

WORKDIR /s6

RUN --mount=type=tmpfs,target=/tmp \
 set -xue \
 && cd /tmp \
 && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
 && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz \
 && tar -C /s6 -Jxpf ./s6-overlay-noarch.tar.xz \
 && tar -C /s6 -Jxpf ./s6-overlay-x86_64.tar.xz

COPY ./rootfs/ /s6/

FROM base AS ocserv-exporter-builder
ARG OCSERV_EXPORTER_VERSION
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -x \
 && apt-get update \
 && apt-get upgrade -y -qq \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    wget ca-certificates

WORKDIR /ocserv-exporter

RUN --mount=type=tmpfs,target=/tmp \
 set -xue \
 && cd /tmp \
 && wget https://github.com/criteo/ocserv-exporter/releases/download/v${OCSERV_EXPORTER_VERSION}/ocserv-exporter_${OCSERV_EXPORTER_VERSION}_linux_amd64.tar.gz \
 && tar -C /ocserv-exporter -xvf ./ocserv-exporter_${OCSERV_EXPORTER_VERSION}_linux_amd64.tar.gz

FROM base AS builder
ARG OCSERV_VERSION

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -x \
 && apt-get update \
 && apt-get upgrade -y -qq \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    build-essential pkg-config wget ca-certificates \
    libgnutls28-dev libev-dev libreadline-dev libpam0g-dev liblz4-dev \
    libseccomp-dev libnl-route-3-dev libkrb5-dev libradcli-dev \
    libcurl4-gnutls-dev libcjose-dev libjansson-dev liboath-dev \
    libprotobuf-c-dev libtalloc-dev libhttp-parser-dev protobuf-c-compiler gperf ipcalc-ng gpg gpg-agent

WORKDIR /tmp

RUN --mount=type=tmpfs,target=/tmp \
    set -x \
 && mkdir -p /opt/ocserv \
 && wget https://ocserv.openconnect-vpn.net/assets/keys/96865171.asc \
 && wget https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz \
 && wget https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz.sig \
 && gpg --no-default-keyring --keyring ${PWD}/keyring.gpg --import 96865171.asc \
 && gpg -v --status-fd 1 --no-default-keyring --keyring ${PWD}/keyring.gpg --verify ocserv-${OCSERV_VERSION}.tar.xz.sig 2>&1 | grep "VALIDSIG" \
 && tar xf ocserv-${OCSERV_VERSION}.tar.xz \
 && cd ocserv-${OCSERV_VERSION} \
 && ./configure --prefix=/opt/ocserv \
 && make -j"$(nproc)" \
 && make install

FROM base AS final

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -x \
 && apt-get update \
 && apt-get upgrade -y -qq \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    libgnutls30 libev4 libpam0g libtalloc2 libradcli4 liboath0 \
    libprotobuf-c1 libgssapi-krb5-2 libk5crypto3 libkrb5-3 \
    libcom-err2 libkeyutils1 libidn2-0 libp11-kit0 libnettle8 \
    libhogweed6 libgmp10 libtasn1-6 libffi8 libcap-ng0 libcrypt1 \
    libunistring2 libaudit1 libreadline8 libnl-3-200 libnl-route-3-200 \
    iproute2 iptables bash \
 && apt purge --yes --auto-remove

ENV S6_LOGGING=0
COPY --link --from=s6-builder /s6 /
COPY --link --from=ocserv-exporter-builder /ocserv-exporter /opt/ocserv-exporter/
COPY --link --from=builder /opt/ocserv /opt/ocserv

WORKDIR /etc/ocserv

EXPOSE 443/tcp
EXPOSE 443/udp

ENTRYPOINT ["/init"]

ARG S6_OVERLAY_VERSION=3.2.1.0
ARG OCSERV_VERSION=1.4.0
ARG OCSERV_EXPORTER_VERSION=0.2.1

FROM debian:bookworm-slim AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

FROM base AS s6-builder
ARG S6_OVERLAY_VERSION
ARG TARGETARCH

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
 && case "$TARGETARCH" in \
      amd64) S6_ARCH="x86_64" ;; \
      arm64) S6_ARCH="aarch64" ;; \
      arm)   S6_ARCH="arm" ;; \
      *)     S6_ARCH="$TARGETARCH" ;; \
    esac \
 && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
 && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz.sha256 \
 && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz \
 && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz.sha256 \
 && sha256sum -c s6-overlay-noarch.tar.xz.sha256 \
 && sha256sum -c s6-overlay-${S6_ARCH}.tar.xz.sha256 \
 && tar -C /s6 -Jxpf ./s6-overlay-noarch.tar.xz \
 && tar -C /s6 -Jxpf ./s6-overlay-${S6_ARCH}.tar.xz

COPY ./rootfs/ /s6/

FROM base AS ocserv-exporter-builder
ARG OCSERV_EXPORTER_VERSION
ARG TARGETARCH

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
 && wget https://github.com/criteo/ocserv-exporter/releases/download/v${OCSERV_EXPORTER_VERSION}/ocserv-exporter_${OCSERV_EXPORTER_VERSION}_linux_${TARGETARCH}.tar.gz \
 && tar -C /ocserv-exporter -xvf ./ocserv-exporter_${OCSERV_EXPORTER_VERSION}_linux_${TARGETARCH}.tar.gz

FROM base AS ocserv-builder
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
    libprotobuf-c-dev libtalloc-dev libhttp-parser-dev \
    protobuf-c-compiler gperf ipcalc-ng gpg gpg-agent

WORKDIR /tmp

RUN --mount=type=tmpfs,target=/tmp \
    set -x \
 && mkdir -p /opt/ocserv \
 && wget --no-check-certificate https://ocserv.openconnect-vpn.net/assets/keys/96865171.asc \
 && wget https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz \
 && wget https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz.sig \
 && gpg --no-default-keyring --keyring ${PWD}/keyring.gpg --import 96865171.asc \
 && gpg -v --status-fd 1 --no-default-keyring --keyring ${PWD}/keyring.gpg --verify ocserv-${OCSERV_VERSION}.tar.xz.sig 2>&1 | grep "^\[GNUPG:\] VALIDSIG" \
 && tar xf ocserv-${OCSERV_VERSION}.tar.xz \
 && cd ocserv-${OCSERV_VERSION} \
 && ./configure --prefix=/opt/ocserv \
 && make -j"$(nproc)" \
 && make install

FROM base AS final
ENV S6_LOGGING=0

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
    iproute2 iptables less curl bash \
 && apt purge --yes --auto-remove

COPY --link --from=s6-builder /s6 /
COPY --link --from=ocserv-exporter-builder /ocserv-exporter /opt/ocserv-exporter/
COPY --link --from=ocserv-builder /opt/ocserv /opt/ocserv

WORKDIR /etc/ocserv

EXPOSE 443/tcp
EXPOSE 443/udp
EXPOSE 8000/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/init"]

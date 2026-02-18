ARG S6_OVERLAY_VERSION=3.2.2.0
ARG OCSERV_VERSION=1.4.0
ARG OCSERV_EXPORTER_VERSION=0.2.2

# pin digest for reproducible builds; update periodically
FROM debian:bookworm-slim@sha256:98f4b71de414932439ac6ac690d7060df1f27161073c5036a7553723881bffbe AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

FROM base AS downloader
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    wget ca-certificates

FROM downloader AS s6-builder
ARG S6_OVERLAY_VERSION
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -ex \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    xz-utils

WORKDIR /s6

# hadolint ignore=DL3003
RUN --mount=type=tmpfs,target=/tmp \
    set -xue \
 && cd /tmp \
 && case "$TARGETARCH" in \
      amd64) S6_ARCH="x86_64" ;; \
      arm64) S6_ARCH="aarch64" ;; \
      arm)   S6_ARCH="arm" ;; \
      *)     S6_ARCH="$TARGETARCH" ;; \
    esac \
 && wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
 && wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz.sha256" \
 && wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
 && wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz.sha256" \
 && sha256sum -c s6-overlay-noarch.tar.xz.sha256 \
 && sha256sum -c "s6-overlay-${S6_ARCH}.tar.xz.sha256" \
 && tar -C /s6 -Jxpf ./s6-overlay-noarch.tar.xz \
 && tar -C /s6 -Jxpf "./s6-overlay-${S6_ARCH}.tar.xz"

COPY ./rootfs/ /s6/

FROM downloader AS ocserv-exporter-builder
ARG OCSERV_EXPORTER_VERSION
ARG TARGETARCH

WORKDIR /ocserv-exporter

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3003
RUN --mount=type=tmpfs,target=/tmp \
    set -xue \
 && cd /tmp \
 && wget -q "https://github.com/criteo/ocserv-exporter/releases/download/v${OCSERV_EXPORTER_VERSION}/ocserv-exporter_${OCSERV_EXPORTER_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && case "$TARGETARCH" in \
      amd64) CHECKSUM="7fdacde71dcf6e9f022c3fa55d7f7d4450dd7fbc3c94cfb5ce8d3fc0c717de5a" ;; \
      arm64) CHECKSUM="62080f698dfd15fd7ad9f0789c0514e01920415a2ce3e40b721edcf6ac03b16c" ;; \
      *)     echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && echo "${CHECKSUM}  ocserv-exporter_${OCSERV_EXPORTER_VERSION}_linux_${TARGETARCH}.tar.gz" | sha256sum -c \
 && tar -C /ocserv-exporter -xvf "./ocserv-exporter_${OCSERV_EXPORTER_VERSION}_linux_${TARGETARCH}.tar.gz"

FROM downloader AS ocserv-builder
ARG OCSERV_VERSION

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    build-essential pkg-config \
    libgnutls28-dev libev-dev libreadline-dev libpam0g-dev liblz4-dev \
    libseccomp-dev libnl-route-3-dev libkrb5-dev libradcli-dev \
    libcurl4-gnutls-dev libcjose-dev libjansson-dev liboath-dev libssl-dev \
    libprotobuf-c-dev libtalloc-dev \
    protobuf-c-compiler gperf ipcalc-ng gpg gpg-agent

COPY ./keys/96865171.asc /usr/local/share/96865171.asc

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3003
RUN --mount=type=tmpfs,target=/tmp \
    set -ex \
 && cd /tmp \
 && mkdir -p /opt/ocserv \
 && wget -q "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz" \
 && wget -q "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz.sig" \
 && gpg --no-default-keyring --keyring "${PWD}/keyring.gpg" --import /usr/local/share/96865171.asc \
 && gpg --no-default-keyring --keyring "${PWD}/keyring.gpg" \
        --status-file gpg-status.txt \
        --verify "ocserv-${OCSERV_VERSION}.tar.xz.sig" "ocserv-${OCSERV_VERSION}.tar.xz" \
 && grep -q "^\[GNUPG:\] VALIDSIG 1F42418905D8206AA754CCDC29EE58B996865171" gpg-status.txt \
 && tar xf "ocserv-${OCSERV_VERSION}.tar.xz" \
 && cd "ocserv-${OCSERV_VERSION}" \
 && ./configure --prefix=/opt/ocserv --enable-oidc-auth \
 && make -j"$(nproc)" \
 && make install

FROM base AS final
ENV S6_LOGGING=0 \
    PATH="/opt/ocserv/bin:/opt/ocserv/sbin:/opt/ocserv-exporter:${PATH}"

RUN useradd --system --no-create-home ocserv

# Only direct runtime deps; transitive libs (libnettle, libgmp, etc.) are pulled by apt automatically
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/var/cache/debconf \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests \
    libgnutls30 libev4 libpam0g libtalloc2 libradcli4 liboath0 \
    libprotobuf-c1 libgssapi-krb5-2 libreadline8 \
    libnl-3-200 libnl-route-3-200 \
    iproute2 iptables bash

COPY --link --from=s6-builder /s6 /
COPY --link --from=ocserv-exporter-builder /ocserv-exporter /opt/ocserv-exporter/
COPY --link --from=ocserv-builder /opt/ocserv /opt/ocserv

# s6-overlay requires root for /init; ocserv drops privileges via its own config
WORKDIR /etc/ocserv

EXPOSE 443/tcp
EXPOSE 443/udp
EXPOSE 8000/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/init"]

<!-- markdownlint-disable MD033 -->

<h1 align="center">ocserv-docker</h1>

<p align="center">
  <a href="https://github.com/gifi71/ocserv-docker/actions/workflows/ci.yml">
    <img src="https://github.com/gifi71/ocserv-docker/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
  <a href="https://github.com/gifi71/ocserv-docker/actions/workflows/scheduled-scan.yml">
    <img src="https://github.com/gifi71/ocserv-docker/actions/workflows/scheduled-scan.yml/badge.svg" alt="VulnScan" />
  </a>
  <a href="https://github.com/gifi71/ocserv-docker/tags">
    <img src="https://img.shields.io/github/v/tag/gifi71/ocserv-docker" alt="tag" />
  </a>
  <a href="https://github.com/gifi71/ocserv-docker/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/gifi71/ocserv-docker" alt="license" />
  </a>
  <a href="https://github.com/gifi71/ocserv-docker/search?l=dockerfile">
    <img src="https://img.shields.io/github/languages/top/gifi71/ocserv-docker" alt="language" />
  </a>
  <a href="https://github.com/gifi71/ocserv-docker/commits/main">
    <img src="https://img.shields.io/github/last-commit/gifi71/ocserv-docker" alt="last commit" />
  </a>
  <a href="https://github.com/gifi71/ocserv-docker/stargazers">
    <img src="https://img.shields.io/github/stars/gifi71/ocserv-docker" alt="stars" />
  </a>
</p>

<!-- markdownlint-enable MD033 -->

Production-ready [ocserv](https://gitlab.com/openconnect/ocserv/) (OpenConnect VPN server) in Docker. Built from source with GPG verification, supervised by [s6-overlay](https://github.com/just-containers/s6-overlay), with optional Prometheus metrics via [ocserv-exporter](https://github.com/criteo/ocserv-exporter).

**Key highlights:**

- Multi-stage build on `debian:bookworm-slim` — minimal final image, no build toolchain
- Latest ocserv built from source with OIDC auth support (see [releases](https://github.com/gifi71/ocserv-docker/releases) for version)
- Multi-architecture support: `amd64`, `arm64`
- Optional Prometheus metrics via [ocserv-exporter](https://github.com/criteo/ocserv-exporter)
- Idempotent iptables setup with clean teardown on shutdown

---

## Quick Start

```bash
git clone https://github.com/gifi71/ocserv-docker.git && cd ocserv-docker

# Prepare your config
mkdir -p config
# Place your ocserv.conf, server-cert.pem, server-key.pem in config/

cp .env.example .env
# Edit .env — set VPN_NETWORK to match your ocserv.conf ipv4-network

docker compose up -d
```

Or with `docker run`:

```bash
docker run -d \
  --name ocserv \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --network host \
  --env-file .env \
  -v ./config:/etc/ocserv \
  -v ./config/ocserv.conf:/etc/ocserv/ocserv.conf:ro \
  --security-opt no-new-privileges \
  ghcr.io/gifi71/ocserv-docker:latest
```

---

## Requirements

| Requirement | Why |
| --- | --- |
| Docker with BuildKit | Multi-stage build, cache mounts |
| `--cap-add NET_ADMIN` | iptables rules and TUN device creation |
| `--device /dev/net/tun` | Kernel interface for VPN tunnels |
| `net.ipv4.ip_forward=1` | Route traffic between VPN clients and the network |

Enable IP forwarding on the host (required for host mode; in bridge mode it is set automatically via `--sysctl`):

```bash
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-vpn.conf
sysctl -p /etc/sysctl.d/99-vpn.conf
```

Optional — improve TCP performance with BBR:

```bash
cat >> /etc/sysctl.d/99-vpn.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
sysctl -p /etc/sysctl.d/99-vpn.conf
```

---

## Configuration

### ocserv.conf

This project **does not ship** a default config. Create your own based on the upstream example:

- [ocserv sample.config](https://gitlab.com/openconnect/ocserv/-/blob/master/doc/sample.config)
- [ocserv manual](https://ocserv.openconnect-vpn.net/ocserv.8.html)
- [Configuration recipes](https://ocserv.openconnect-vpn.net/recipes.html)

**Required settings** for this container:

```conf
# Healthcheck and exporter depend on occtl
use-occtl = true

# The image ships a dedicated system user
run-as-user = ocserv
run-as-group = ocserv

# TLS — mount your certs into /etc/ocserv
server-cert = /etc/ocserv/server-cert.pem
server-key = /etc/ocserv/server-key.pem
```

### TLS Certificates

Use any method you prefer: `certtool`, `openssl`, ACME (certbot, acme.sh), etc. Mount the resulting cert and key into `config/`.

### Environment Variables

```bash
cp .env.example .env
```

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `VPN_NETWORK` | **yes** | — | NAT MASQUERADE CIDR, must match `ipv4-network` in ocserv.conf |
| `EXPORTER_ENABLED` | no | `0` | `1` to enable Prometheus exporter |
| `EXPORTER_INTERVAL` | no | `30s` | Delay between occtl scrapes |
| `EXPORTER_BIND` | no | `127.0.0.1:8000` | Exporter HTTP listen address |

---

## Usage

### Docker Compose

```bash
docker compose up -d        # start
docker compose logs -f       # logs
docker compose down          # stop
```

### Host vs Bridge Mode

**Host mode** (default) — the container shares the host network stack. VPN clients get TUN interfaces visible on the host. The listening ports depend on your `ocserv.conf` and must be free on the host.

**Bridge mode** — isolated network namespace, only forwarded ports are accessible. Edit `docker-compose.yml`: comment out `network_mode: host`, uncomment the `ports`/`sysctls` section.

Bridge mode via `docker run`:

```bash
docker run -d \
  --name ocserv \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --sysctl net.ipv4.ip_forward=1 \
  -p 443:443/tcp \
  -p 443:443/udp \
  --env-file .env \
  -v ./config:/etc/ocserv \
  -v ./config/ocserv.conf:/etc/ocserv/ocserv.conf:ro \
  --security-opt no-new-privileges \
  ghcr.io/gifi71/ocserv-docker:latest
```

---

## Building from Source

```bash
make build            # local build for current arch
make build-multiarch  # multi-platform build + push
make test             # build + run integration tests
make lint             # run all linters (hadolint, shellcheck, yamllint)
```

---

## Contributing

Contributions are welcome — open an [issue](https://github.com/gifi71/ocserv-docker/issues) or submit a PR.

Setup:

```bash
# Install pre-commit using your preferred method (pipx, pip, brew, OS package manager, etc.)
pre-commit install
```

The project uses [Conventional Commits](https://www.conventionalcommits.org/) and enforces it via pre-commit hook.

Linters: hadolint, shellcheck, yamllint.

---

## License

This repository (Dockerfile, scripts, configuration) is licensed under [MIT](LICENSE).

It includes [ocserv](https://gitlab.com/openconnect/ocserv/), which is licensed under [GNU GPLv2](https://www.gnu.org/licenses/gpl-2.0.html). The two are independent works (aggregation per GPL terms).

---

![info](https://repobeats.axiom.co/api/embed/087b5f74d9fa0d9fb879eaceb890b74c8c1b12ca.svg)

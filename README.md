<!-- markdownlint-disable MD033 -->

<h1 align="center">ocserv-docker</h1>

<p align="center">
  <a href="https://github.com/gifi71/ocserv-docker/actions/workflows/docker-publish.yml">
    <img src="https://github.com/gifi71/ocserv-docker/actions/workflows/docker-publish.yml/badge.svg" alt="build" />
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

A containerized [ocserv](https://gitlab.com/openconnect/ocserv/) (OpenConnect VPN server), built from source with GPG signature verification. Uses [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision and optionally exports Prometheus metrics via [ocserv-exporter](https://github.com/criteo/ocserv-exporter).

---

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running](#running)
- [Network Modes](#network-modes)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- Lightweight image based on `debian:bookworm-slim`
- Multi-stage Docker build with optimized final image size
- `ocserv` v1.4.0 built from source with upstream GPG signature verification
- Multi-architecture support (amd64, arm64)
- s6-overlay for process supervision and service orchestration
- Optional Prometheus metrics via `ocserv-exporter`
- Healthcheck script for `ocserv` and `ocserv-exporter`
- GitHub Actions CI for build and image signing (cosign)
- Licensed under GPLv3

---

## Project Structure

```plain
ocserv-docker/
├── .github/workflows/
│   └── docker-publish.yml     # CI for Docker image publishing
├── keys/
│   └── 96865171.asc           # ocserv GPG signing key
├── rootfs/
│   ├── usr/local/bin/         # Scripts (healthcheck)
│   └── etc/s6-overlay/        # s6 service definitions
├── .dockerignore
├── .env.example               # Environment variables template for Compose
├── .pre-commit-config.yaml
├── docker-compose.yml
├── Dockerfile
├── LICENSE
├── Makefile
└── README.md
```

---

## Installation

### 1. Install Docker

```bash
curl -sSL https://get.docker.com | sh
```

### 2. Clone the Repository

```bash
git clone https://github.com/gifi71/ocserv-docker.git /opt/ocserv-docker
cd /opt/ocserv-docker
```

---

## Configuration

### 3. Create ocserv Configuration

This project does **not** ship a default `ocserv.conf`. You must create your own configuration before starting the container.

Create the config directory and your configuration file:

```bash
mkdir -p config
nano config/ocserv.conf
```

Refer to the official ocserv documentation for configuration options:
- [ocserv manual](https://ocserv.openconnect-vpn.net/ocserv.8.html)
- [ocserv configuration recipes](https://ocserv.openconnect-vpn.net/recipes.html)
- [Example config from ocserv source](https://gitlab.com/openconnect/ocserv/-/blob/master/doc/sample.config)

**Required settings for this container to work correctly:**

```conf
# Enable occtl (required for healthcheck and metrics export)
use-occtl = true

# Drop privileges (the image ships a dedicated ocserv system user)
run-as-user = ocserv
run-as-group = ocserv

# Your TLS certificate and key
server-cert = /etc/ocserv/server-cert.pem
server-key = /etc/ocserv/server-key.pem
```

### Generate TLS Certificates

Using `certtool` (from `gnutls-bin` package):

```bash
# Generate CA key and certificate
certtool --generate-privkey --outfile ca-key.pem
certtool --generate-self-signed --load-privkey ca-key.pem --outfile ca-cert.pem

# Generate server key and certificate
certtool --generate-privkey --outfile config/server-key.pem
certtool --generate-certificate \
  --load-privkey config/server-key.pem \
  --load-ca-certificate ca-cert.pem \
  --load-ca-privkey ca-key.pem \
  --outfile config/server-cert.pem
```

Or use an ACME client (e.g., certbot, acme.sh) for certificates from a public CA.

### 4. Configure Host Networking

When using the default `network_mode: host`, enable IP forwarding on the host:

```bash
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-vpn.conf
sysctl -p /etc/sysctl.d/99-vpn.conf
```

Optional TCP optimizations:

```conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

### 5. Configure Environment Variables

```bash
cp .env.example .env
nano .env
```

| Variable            | Required | Description                                         | Default           |
| ------------------- | -------- | --------------------------------------------------- | ----------------- |
| `VPN_NETWORK`       | **yes**  | NAT MASQUERADE CIDR (must match ocserv ipv4-network)| —                 |
| `EXPORTER_ENABLED`  | no       | Enable `ocserv-exporter` for Prometheus             | `0`               |
| `EXPORTER_INTERVAL` | no       | Scrape interval for exporter                        | `30s`             |
| `EXPORTER_BIND`     | no       | Exporter listen address                             | `127.0.0.1:8000`  |

---

## Running

### Using Docker Compose

```bash
cp .env.example .env   # edit .env with your values
docker compose up -d
```

View logs:

```bash
docker compose logs -f ocserv
```

### Without Docker Compose (host network mode)

```bash
docker run -d \
  --name ocserv \
  --restart unless-stopped \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --network host \
  --env-file .env \
  -v "$(pwd)/config:/etc/ocserv:ro" \
  --security-opt no-new-privileges \
  ghcr.io/gifi71/ocserv-docker:latest
```

### Building Locally

```bash
make oci-image
```

---

## Network Modes

### Host Mode (default)

The container shares the host's network stack. Each VPN client gets its own tun device visible on the host. This allows direct routing between the host and VPN clients.

Requirements:
- `net.ipv4.ip_forward=1` must be set on the host
- Ports 443/tcp and 443/udp must be free on the host

### Bridge Mode

The container runs in an isolated network namespace. The host cannot directly reach VPN clients — only port 443 is forwarded.

To switch, edit `docker-compose.yml`: comment out `network_mode: host` and uncomment the `ports`/`sysctls` section at the bottom of the file.

Or via `docker run`:

```bash
docker run -d \
  --name ocserv \
  --restart unless-stopped \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --sysctl net.ipv4.ip_forward=1 \
  -p 443:443/tcp \
  -p 443:443/udp \
  --env-file .env \
  -v "$(pwd)/config:/etc/ocserv:ro" \
  --security-opt no-new-privileges \
  ghcr.io/gifi71/ocserv-docker:latest
```

---

## Roadmap

- [x] Multi-stage build
- [x] Published to GHCR
- [x] s6-overlay supervision
- [x] ocserv-exporter integration
- [x] Healthcheck
- [x] Multi-architecture support
- [ ] CI tests for image validation

---

## Contributing

Contributions, issues and feature requests are welcome.
Check the [issues page](https://github.com/gifi71/ocserv-docker/issues) or submit a pull request.

To set up pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

---

## License

This project includes `ocserv`, licensed under [GNU GPLv2](https://www.gnu.org/licenses/gpl-2.0.html). The Dockerfile, scripts, and configuration in this repository are independent works (aggregation, not derivative) and may be licensed separately.

---

![info](https://repobeats.axiom.co/api/embed/087b5f74d9fa0d9fb879eaceb890b74c8c1b12ca.svg)

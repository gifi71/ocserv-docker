<!-- markdownlint-disable MD033 -->

<h1 align="center">🛡️ ocserv-docker</h1>

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

A containerized version of [`ocserv`](https://gitlab.com/openconnect/ocserv/) [(OpenConnect VPN server)](https://ocserv.openconnect-vpn.net/), built from source for security, flexibility, and minimal overhead.
This project provides an easy-to-deploy VPN server with support for port forwarding to VPN clients, basic NAT out of the box, and optional Prometheus metrics export via [`ocserv-exporter`](https://github.com/criteo/ocserv-exporter) for real-time monitoring and alerting.

---

## 📚 Table of Contents

- [✨ Features](#-features)
- [📁 Project Structure](#-project-structure)
- [📦 Installation](#-installation)
- [⚙️ Configuration](#️-configuration)
- [🚀 Running the Container](#-running-the-container)
- [🧭 Roadmap](#-roadmap)
- [🙋 Contributing](#-contributing)
- [💬 Support](#-support)
- [📜 License](#-license)
- [📈 Repository Insights](#-repository-insights)

---

## ✨ Features

- 🐳 **Fully containerized** via Docker & Compose
- ✅ **Lightweight image** built from `debian:bookworm-slim`
- 📦 **Multi-stage Docker build** with optimized final image size
- 🔒 Builds **latest `ocserv` v1.3.0** from source with upstream GPG signature verification
- ⚙️ **Includes default `ocserv.conf`** for quick setup and customization
- 🔁 Uses **s6-overlay** for process supervision and service orchestration
- 🌐 Supports dynamic **TCP/UDP port forwarding** to VPN clients
- 📊 Optional **Prometheus metrics export** via `ocserv-exporter`
- 💡 **Custom healthcheck script** validates both `ocserv` and `ocserv-exporter`
- 🧪 **Integrated GitHub Actions CI** for build and image integrity testing
- 📜 Licensed under **GPLv3**

---

## 📁 Project Structure

```plain
ocserv-docker/
├── .github/workflows/
│   └── docker-publish.yml     # CI for Docker image publishing
├── config/
│   └── ocserv.conf            # ocserv default config
├── rootfs/
│   ├── usr/local/bin/         # Scripts (e.g. healthcheck)
│   └── etc/s6-overlay/        # s6 service definitions
├── .dockerignore              # Files to exclude from Docker build
├── .env                       # Environment variables for Compose
├── docker-compose.yml         # Local dev/test setup
├── Dockerfile                 # Docker image build instructions
├── LICENSE                    # Project license (GPLv3)
├── Makefile                   # Build commands
└── README.md                  # Project documentation
```

---

## 📦 Installation

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

## ⚙️ Configuration

### 3. Edit ocserv Configuration

Customize it to fit your network and authentication setup. The default config is located at:

```plain
config/ocserv.conf
```

**Important:**
> ⚠️ Make sure the following setting is present and enabled in your `ocserv.conf`:

```conf
use-occtl = true
```

This setting enables the `occtl` command interface, which is **required** for the custom healthcheck script to verify `ocserv` status and for the `ocserv-exporter` to collect Prometheus metrics. Without it, both health monitoring and metrics export will not function correctly.

### 4. Edit `.env` (optional, all values can be commented out)

| Variable            | Description                                                       | Default        |
| ------------------- | ----------------------------------------------------------------- | -------------- |
| `PORTS`             | Space-separated list of port forwards in `<host>:<client>:<port>` | Not set        |
| `EXPORTER_ENABLED`  | Enable `ocserv-exporter` for Prometheus metrics                   | `0`            |
| `EXPORTER_INTERVAL` | Scrape interval for exporter                                      | `30s`          |
| `EXPORTER_BIND`     | Exporter listen address                                           | `0.0.0.0:8000` |

**Example:**

```env
PORTS="80:10.10.0.2:80 25565:10.10.0.3:25565"
EXPORTER_ENABLED=1
EXPORTER_INTERVAL=30s
EXPORTER_BIND=0.0.0.0:8000
```

This will forward traffic on ports `80` and `25565` from the container to the specified VPN clients and serve prometheus metric (see [`ocserv-exporter`](https://github.com/criteo/ocserv-exporter) for details) at `http://0.0.0.0:8000/metrics`.

### 5. Edit `docker-compose.yml` (optional)

You can customize basic settings without breaking functionality, such as:

- **Ports:** Change or add host ports to avoid conflicts or expose different VPN ports.
- **Volumes:** Modify the config folder path if your `ocserv.conf` or other files are stored elsewhere.
- **Container name:** Rename the container if you run multiple instances.
- **Logging options:** Adjust log file size or rotation limits if needed.

### 6. Optimize Host Networking (optional)

To improve TCP performance, especially when using TCP VPN connections, you can enable the following settings by editing `/etc/sysctl.conf`:

```conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

Apply the changes with:

```bash
sysctl -p
```

These settings optimize packet scheduling and enable the BBR TCP congestion control algorithm, which can significantly enhance TCP throughput and reduce latency. This optimization is particularly useful if your VPN clients mainly use TCP connections.

---

## 🚀 Running the Container

### Using Docker Compose

Start the VPN server:

```bash
docker compose up -d
```

View container logs:

```bash
docker compose logs -f ocserv
```

### Without Docker Compose

You can also run the container directly with `docker run`:

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
  -v "$(pwd)/config:/etc/ocserv" \
  --security-opt no-new-privileges \
  ghcr.io/gifi71/ocserv-docker:latest
```

### Building the Image Yourself

You can build the Docker image locally using the provided Makefile target:

```bash
make oci-image
```

This runs:

```bash
docker buildx build --progress=plain --pull -t ghcr.io/gifi71/ocserv-docker:latest .
```

which builds the image with detailed output and tags it with `ghcr.io/gifi71/ocserv-docker:latest`.

---

## 🧭 Roadmap

- [x] Multi-stage build (430MB -> 113MB)
- [x] Published to GHCR
- [x] `s6-overlay` supervision
- [x] `ocserv-exporter` integration
- [x] Extended healthcheck
- [ ] CI tests for image validation

---

## 🙋 Contributing

Contributions, issues and feature requests are welcome!  
Feel free to check the [issues page](https://github.com/gifi71/ocserv-docker/issues) or submit a pull request.

---

## 💬 Support

If you find this project useful, feel free to star it 🌟 and share it.  
For questions or help, open an [issue](https://github.com/gifi71/ocserv-docker/issues).

---

## 📜 License

This project includes `ocserv`, licensed under [GNU GPLv3](https://www.gnu.org/licenses/gpl-3.0.html). All derivative works must also be distributed under GPLv3.

---

## 📈 Repository Insights

![info](https://repobeats.axiom.co/api/embed/087b5f74d9fa0d9fb879eaceb890b74c8c1b12ca.svg)

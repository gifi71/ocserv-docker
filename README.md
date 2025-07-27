# 🛡️ ocserv-docker

A containerized version of [ocserv (OpenConnect VPN server)](http://www.infradead.org/ocserv/), built from source for security, flexibility, and minimal overhead.  
This project provides an easy-to-deploy VPN server with support for port forwarding and basic NAT out of the box.

---

## ✨ Features

- ✅ Lightweight image built from **Debian slim**
- 🔒 Compiles latest **ocserv v1.3.0** from source
- 🌐 Supports dynamic **TCP/UDP port forwarding** to VPN clients
- ⚙️ Includes a **default `ocserv.conf`** for quick setup
- 🐳 Fully containerized via **Docker & Compose**
- 📜 Licensed under **GPLv3**

---

## 📁 Project Structure

```plain
ocserv-docker/
├── config/                # Contains ocserv.conf (default server config)
│   └── ocserv.conf
├── docker-compose.yml     # Compose setup for the container
├── Dockerfile             # Builds ocserv from source
├── entrypoint.sh          # Entrypoint script (port forwarding + server start)
├── LICENSE                # GNU GPLv3 license
└── README.md              # Project documentation
````

---

## 📦 Installation

### 1. Install Docker

```bash
apt-get update && apt-get upgrade -y
curl -sSL https://get.docker.com | sh
```

### 2. Clone the Repository

```bash
git clone https://github.com/gifi71/ocserv-docker.git /opt/ocserv-docker
cd /opt/ocserv-docker
```

### 3. Optimize Host Networking (optional)

Edit `/etc/sysctl.conf`:

```conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

Apply changes:

```bash
sysctl -p
```

---

## ⚙️ Configuration

### 4. Edit ocserv Configuration

The default config is located at:

```plain
config/ocserv.conf
```

**Important:**
Customize it to fit your network and authentication setup.
Make sure the following setting is present and enabled in your `ocserv.conf`:

```conf
use-occtl = true
```

### 5. Edit `.env` (optional, all values can be commented out)

To forward specific ports from the container to VPN clients, define the `PORTS` environment variable.

**Format:**

```env
# (optional) firewall ports map, default: not set
PORTS="<host_port>:<client_ip>:<client_port> ..."

## (optional) 1 - enable ocserv-exporter, default: 0
EXPORTER_ENABLED=0

# (optional) default ocserv-exporter delay between occtl scrape, default: 30s
EXPORTER_INTERVAL=30s

# (optional) ocserv-exporter prometheus HTTP listen IP and port, default: 0.0.0.0:8000
EXPORTER_BIND=0.0.0.0:8000
```

**Example:**

```env
PORTS="80:10.10.0.2:80 443:10.10.0.2:443 25565:10.10.0.3:25565"
EXPORTER_ENABLED=1
EXPORTER_INTERVAL=30s
EXPORTER_BIND=0.0.0.0:8000
```

This will forward traffic on ports `80`, `443`, and `25565` from the host to the specified VPN clients and serve prometheus metric (see [criteo/ocserv-exporter](https://github.com/criteo/ocserv-exporter) for details) at `http://0.0.0.0:8000/metrics`.

### 6. Edit `docker-compose.yml` (optional)

Adjust ports, volumes, or container settings if needed.

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

---

## 🧱 TODO

- [x] Implement a multi-stage Docker build to reduce image size (`430MB` -> `113MB`)
- [x] Publish image to GitHub Container Registry (`ghcr.io/gifi71/ocserv-docker`)
- [x] Improve multi-stage Docker build to reduce image size (`113MB` -> `95MB`)
- [x] Transitioned to using s6 overlay for process supervision and service management
- [x] Added ocserv-exporter to provide Prometheus metrics for monitoring
- [x] Updated healthcheck to cover both ocserv service and ocserv-exporter functionality
- [ ] Covered the build process with automated tests in GitHub Workflow to ensure image integrity and functionality

---

## 📜 License

This project includes `ocserv`, licensed under [GNU GPLv3](https://www.gnu.org/licenses/gpl-3.0.html). All derivative works must also be distributed under GPLv3.

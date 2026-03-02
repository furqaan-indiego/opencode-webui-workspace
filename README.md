# OpenCode WebUI Workspace

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opencode-webui-workspace?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

A containerized development environment running OpenCode WebUI with comprehensive tooling support. This Docker image includes Python, Node.js, Bun, and essential development tools, all running under a non-root `opencode` user with sudo privileges.

## Features

- **OpenCode WebUI** (v1.1.25) - AI-powered code editor
- **Python 3.13.11** with `python` alias
- **Node.js 24.13.0** with npm 11.6.2
- **Bun 1.3.6** - Fast JavaScript runtime
- **uv 0.9.26** - Python package manager
- **GitHub CLI** - Official GitHub command-line tool
- **Tailscale** - Secure networking
- **Non-root user** (`opencode`) with passwordless sudo access
- **Pre-configured workspace** at `/home/opencode/workspace`

## Quick Start

Default usage is `docker run` (not Docker Compose).

### Basic Usage

```bash
# Run the OpenCode WebUI
docker run -p 4096:4096 opencode-webui-workspace:latest

# Access at http://localhost:4096
```

### Interactive Shell

```bash
docker run -it --rm opencode-webui-workspace:latest bash
```

### With Environment Variables

```bash
# Create .env file from template
cp .env.example .env
# Edit .env with your secure password

# Run with environment variables
docker run -p 4096:4096 --env-file .env opencode-webui-workspace:latest
```

## Configuration

### Environment Variables

Create a `.env` file (copy from `.env.example`):

```env
OPENCODE_SERVER_USERNAME=opencode
OPENCODE_SERVER_PASSWORD=your-secure-password-here
OPENCODE_PORT=4096
OPENCODE_HOSTNAME=0.0.0.0
```

- **OPENCODE_SERVER_USERNAME**: Default login username (default: `opencode`)
- **OPENCODE_SERVER_PASSWORD**: Secure password for the server (required for authentication)
- **OPENCODE_PORT**: Port to listen on (default: 4096)
- **OPENCODE_HOSTNAME**: Hostname/IP to bind to (default: 0.0.0.0)

### Tailscale Setup

To connect your container to your Tailscale network:

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Click **Add device** → **Linux server**
3. Enable the following options:
   - **Ephemeral** - Container will be removed from tailnet when stopped
   - **Reusable** - Allows multiple containers to use the same key
4. Click **Generate install script**
5. Copy the auth key (starts with `tskey-auth-`)
6. Set it as the `TAILSCALE_AUTH_KEY` environment variable in Railway

```env
TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxxxxx
```

## Volume Mounting

Mount a single data directory to persist all your work, configurations, and credentials:

```bash
docker run -p 4096:4096 \
  -v $(pwd)/data:/data \
  opencode-webui-workspace:latest
```

The `data` directory will contain:
- `workspace/` - Your project files
- `opencode-local/` - OpenCode API keys and auth tokens
- `opencode-config/` - OpenCode configuration files

### Optional: Docker Compose

Run with:
```bash
docker-compose up -d
```

The `./data` directory will be created on your host machine on first run with all subdirectories.

## Advanced Usage

### Build Locally

```bash
docker build -t opencode-webui-workspace:latest .
```

### Run with Custom Port

```bash
docker run -p 8080:4096 opencode-webui-workspace:latest
```

Access at `http://localhost:8080`

### Override Command

Run an interactive shell instead of the OpenCode WebUI:

```bash
docker run -it --rm opencode-webui-workspace:latest bash
```

Run Python directly:

```bash
docker run -it --rm opencode-webui-workspace:latest python -c "print('Hello from Python 3.13')"
```

### Development Workflow

```bash
# Mount data volume and run interactive shell
docker run -it --rm \
  -v $(pwd)/data:/data \
  opencode-webui-workspace:latest bash

# Inside container, all your tools are available:
python --version      # Python 3.13.11
node --version        # v24.13.0
bun --version         # 1.3.6
uv --version          # 0.9.26
gh --version          # GitHub CLI
```

## User & Permissions

The container runs as the `opencode` user (UID: varies) with:
- Full access to `/home/opencode/workspace`
- Passwordless sudo privileges for system administration
- Shell: `/bin/bash`

This ensures security while allowing necessary system operations.

## File Structure

The container uses a single `/data` volume for all persistent data, with symlinks to standard locations:

```
/data/
├── workspace/              # Your project files (→ /home/opencode/workspace)
├── opencode-local/         # API keys & auth (→ /root/.local/share/opencode)
└── opencode-config/        # Config files (→ /root/.config/opencode)
```

This structure allows Railway and other platforms to mount a single volume while keeping everything persistent.

## Publishing Images

The repository includes a GitHub Actions workflow (`.github/workflows/publish.yml`) that automatically:
- Publishes to GitHub Container Registry (GHCR)
- Supports multiple platforms (linux/amd64, linux/arm64)
- Tags images with git refs and semver tags

### Automatic Publishing

Images are automatically published on:
- Push to `main` branch (tagged as `latest`)
- Push of version tags (v1.0.0, v2.0.0, etc.)
- Manual workflow dispatch from Actions tab

No additional secrets needed - uses `GITHUB_TOKEN` automatically!

## Requirements

- Docker 20.10+
- 4GB+ available disk space for image
- ~500MB for runtime data

## License

OpenCode and included tools follow their respective licenses.

## Support

For issues with:
- **OpenCode**: https://github.com/opencodeinc/opencode
- **This Docker setup**: Check Docker logs with `docker logs <container-id>`

## Tips & Tricks

### Keep container running in background

```bash
docker run -d -p 4096:4096 --name opencode opencode-webui-workspace:latest
```

View logs:
```bash
docker logs -f opencode
```

Stop:
```bash
docker stop opencode
```

### Use with VS Code Dev Containers

Install the "Dev Containers" extension and configure `.devcontainer/devcontainer.json` to use this image.

### Resource Limits

```bash
docker run -p 4096:4096 \
  --memory=4g \
  --cpus=2 \
  opencode-webui-workspace:latest
```

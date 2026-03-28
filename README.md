# Cubic Odyssey Dedicated Server - Docker

Runs the Cubic Odyssey Dedicated Server on Linux via SteamCMD + Wine + Xvfb.

## Prerequisites

- Docker and Docker Compose
- A Steam account that has claimed the free **Cubic Odyssey Dedicated Server** tool
  from the [Steam store](https://store.steampowered.com/app/3858450/Cubic_Odyssey_Dedicated_Server/)
- **Recommended:** Use a dedicated Steam account with Steam Guard disabled.
  Anonymous login does not work for this app.

## Quick Start

1. Clone or copy this directory to your server
2. Create a `.env` file from the example:

```bash
cp .env.example .env
# Edit .env with your Steam credentials
```

3. Build and run:

```bash
docker compose up -d --build
```

4. Check the server log file for the lobby code (e.g. `DS-ABCDEF`):

```bash
docker compose exec cubic-odyssey cat /root/server_files/server/logs/$(ls -t /root/server_files/server/logs/ | head -1)
```

5. Connect in-game using the lobby code

## Portainer

This repo can be deployed directly as a Portainer stack:

1. **Stacks > Add stack > Repository**
2. **Repository URL:** your GitHub repo URL
3. **Branch:** `main`
4. Set `STEAM_USER` and `STEAM_PASS` in the **Environment variables** section

## Configuration

Server settings are controlled via environment variables in `docker-compose.yml`.
On first run, these generate a `server_config.txt` in the `server_files/config/` directory.

To use a custom config, edit `server_files/config/server_config.txt` directly.
**Note:** Some config changes may require a server reinstall — delete the
`server_files/server/` directory and restart the container.

## Volumes

| Host Path          | Container Path          | Purpose                              |
|--------------------|-------------------------|--------------------------------------|
| `./server_files`   | `/root/server_files`    | Game binary, saves, and config       |
| `./steam_cache`    | `/root/Steam`           | Steam session (avoids repeated auth) |

## Ports

The server uses UDP ports 27001-27015 by default. Forward these on your router
if you want external players to connect.

For simpler networking, switch to `network_mode: host` in the compose file.

## Updating

With `UPDATE_ON_START=true` (default), the server checks for updates via SteamCMD
every time the container starts. To update manually:

```bash
docker compose restart
```

## Logs

The server writes its own log files to `server_files/server/logs/`. Docker
container logs will show SteamCMD and startup output, but the game server
itself writes to disk. Look for the `Lobby Key: DS-XXXXXX` line in the
latest log file to find your connection code.

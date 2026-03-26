# Cubic Odyssey Dedicated Server - Docker

Runs the Cubic Odyssey Dedicated Server on Linux via SteamCMD + Wine + Xvfb.

## Prerequisites

- Docker and Docker Compose
- A Steam account that has claimed the free **Cubic Odyssey Dedicated Server** tool
  from the [Steam store](https://store.steampowered.com/app/3858450/Cubic_Odyssey_Dedicated_Server/)

## Quick Start

1. Clone or copy this directory to your server
2. Edit `docker-compose.yml` — set `STEAM_USER` and `STEAM_PASS`
3. Build and run:

```bash
docker compose up -d --build
```

4. Check the logs for the lobby code (e.g. `DS-ABCDEF`):

```bash
docker compose logs -f
```

5. Connect in-game using the lobby code

## Configuration

Server settings are controlled via environment variables in `docker-compose.yml`.
On first run, these generate a `server_config.txt` in the `server_files/config/` directory.

To use a custom config, edit `server_files/config/server_config.txt` directly.
**Note:** Some config changes may require a server reinstall — delete the
`server_files/server/` directory and restart the container.

## Volumes

| Host Path          | Container Path                  | Purpose                          |
|--------------------|---------------------------------|----------------------------------|
| `./server_files`   | `/home/cubic/server_files`      | Game binary + SteamCMD downloads |
| `./persistent_data`| `/home/cubic/persistent_data`   | World saves (survives rebuilds)  |

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

## Steam Guard

If your account has Steam Guard enabled, the first login will require a code.
Set `STEAM_AUTH` to the code and start the container. After the first successful
login, SteamCMD caches the session in the container. If using 2FA, consider
creating a dedicated Steam account for hosting.

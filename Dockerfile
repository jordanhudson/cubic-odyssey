FROM debian:bookworm-slim

LABEL maintainer="cubic-odyssey-docker"
LABEL description="Cubic Odyssey Dedicated Server via SteamCMD + Wine"

ENV DEBIAN_FRONTEND=noninteractive

# ── Install dependencies ─────────────────────────────────────────────
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        lib32gcc-s1 \
        lib32stdc++6 \
        wine \
        wine32 \
        wine64 \
        xvfb \
        xauth \
        winbind \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# ── Install SteamCMD ─────────────────────────────────────────────────
RUN mkdir -p /root/steamcmd && \
    curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar -xz -C /root/steamcmd

# ── Create directories for server files and persistent data ──────────
RUN mkdir -p /root/server_files

# ── Copy entrypoint script ───────────────────────────────────────────
COPY entrypoint.sh /root/entrypoint.sh
RUN chmod +x /root/entrypoint.sh

# ── Default environment variables ────────────────────────────────────
ENV STEAM_USER="anonymous"
ENV STEAM_PASS=""
ENV STEAM_AUTH=""
ENV APP_ID="3858450"
ENV SERVER_NAME="Cubic Odyssey Docker Server"
ENV SERVER_PASSWORD=""
ENV MAX_PLAYERS="10"
ENV GAME_PORT="27001"
ENV MAX_PORT="27015"
ENV GAMEMODE="adventure"
ENV GALAXY_SEED="0"
ENV ALLOW_RELAYING="FALSE"
ENV PRIVATE_SERVER="FALSE"
ENV WINEDEBUG="-all"
ENV DISPLAY=":99"
ENV UPDATE_ON_START="true"

EXPOSE 27001-27015/udp

ENTRYPOINT ["/root/entrypoint.sh"]

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

# ── Create unprivileged user ─────────────────────────────────────────
RUN useradd -m -s /bin/bash cubic
USER cubic
WORKDIR /home/cubic

# ── Install SteamCMD ─────────────────────────────────────────────────
RUN mkdir -p /home/cubic/steamcmd && \
    curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar -xz -C /home/cubic/steamcmd

# ── Create directories for server files and persistent data ──────────
RUN mkdir -p /home/cubic/server_files /home/cubic/persistent_data

# ── Copy entrypoint script ───────────────────────────────────────────
USER root
COPY --chown=cubic:cubic entrypoint.sh /home/cubic/entrypoint.sh
COPY --chown=cubic:cubic entrypoint-root.sh /home/cubic/entrypoint-root.sh
RUN chmod +x /home/cubic/entrypoint.sh /home/cubic/entrypoint-root.sh

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

ENTRYPOINT ["/home/cubic/entrypoint-root.sh"]

#!/bin/bash
set -e

SERVER_DIR="/home/cubic/server_files"
DATA_DIR="/home/cubic/persistent_data"
STEAMCMD="/home/cubic/steamcmd/steamcmd.sh"
CONFIG_FILE="${SERVER_DIR}/config/server_config.txt"
SERVER_EXE="${SERVER_DIR}/server/CubicOdysseyServer.exe"

echo "============================================"
echo "  Cubic Odyssey Dedicated Server (Docker)"
echo "============================================"

# ── Install / Update server files via SteamCMD ──────────────────────
if [ "${UPDATE_ON_START}" = "true" ] || [ ! -f "${SERVER_EXE}" ]; then
    echo ""
    echo ">> Updating Cubic Odyssey Dedicated Server (AppID ${APP_ID})..."
    echo ""

    # Determine Steam login
    if [ -z "${STEAM_USER}" ] || [ "${STEAM_USER}" = "anonymous" ]; then
        echo ">> Using anonymous login"
        STEAM_LOGIN="+login anonymous"
    else
        echo ">> Logging in as ${STEAM_USER}"
        STEAM_LOGIN="+login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH}"
    fi

    ${STEAMCMD} \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir "${SERVER_DIR}" \
        ${STEAM_LOGIN} \
        +app_license_request ${APP_ID} \
        +app_update ${APP_ID} validate \
        +quit

    # Set up Steam SDK libraries (some servers need these)
    mkdir -p "${SERVER_DIR}/.steam/sdk32" "${SERVER_DIR}/.steam/sdk64"
    cp -f /home/cubic/steamcmd/linux32/steamclient.so "${SERVER_DIR}/.steam/sdk32/" 2>/dev/null || true
    cp -f /home/cubic/steamcmd/linux64/steamclient.so "${SERVER_DIR}/.steam/sdk64/" 2>/dev/null || true

    echo ""
    echo ">> Update complete."
else
    echo ">> Skipping update (UPDATE_ON_START=false and server exists)"
fi

# ── Verify the server binary exists ──────────────────────────────────
if [ ! -f "${SERVER_EXE}" ]; then
    echo ""
    echo "ERROR: ${SERVER_EXE} not found after install."
    echo "This game requires a Steam account that OWNS the Cubic Odyssey"
    echo "Dedicated Server tool (free). Anonymous login may not work."
    echo "Set STEAM_USER and STEAM_PASS environment variables."
    exit 1
fi

# ── Generate server_config.txt if it doesn't exist ───────────────────
mkdir -p "${SERVER_DIR}/config"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo ">> Generating default server_config.txt"
    cat > "${CONFIG_FILE}" <<EOF
GameParams {
    m_server ServerParams {
        startingPort ${GAME_PORT}
        endingPort ${MAX_PORT}
        serverName "${SERVER_NAME}"
        serverPassword "${SERVER_PASSWORD}"
        maxPlayers ${MAX_PLAYERS}
        galaxySeed ${GALAXY_SEED}
        allowRelaying ${ALLOW_RELAYING}
        privateServer ${PRIVATE_SERVER}
        enableCrashDumps FALSE
        enableLogging TRUE
    }
}
EOF
    echo ">> Config written to ${CONFIG_FILE}"
else
    echo ">> Using existing server_config.txt"
fi

# ── Symlink persistent data (world saves) ────────────────────────────
# The server stores saves alongside the binary; we link to persistent_data
# so the volume mount preserves them across container rebuilds.
if [ -d "${DATA_DIR}" ]; then
    # Link the Saved directory if the server uses one
    for subdir in Saved saves SaveGames; do
        if [ -d "${SERVER_DIR}/server/${subdir}" ] && [ ! -L "${SERVER_DIR}/server/${subdir}" ]; then
            echo ">> Moving existing ${subdir} to persistent_data"
            mv "${SERVER_DIR}/server/${subdir}" "${DATA_DIR}/${subdir}"
            ln -sf "${DATA_DIR}/${subdir}" "${SERVER_DIR}/server/${subdir}"
        fi
    done
fi

# ── Initialize Wine prefix (suppress first-run noise) ────────────────
echo ">> Initializing Wine prefix..."
export WINEPREFIX="/home/cubic/.wine"
wineboot --init 2>/dev/null || true

# ── Start Xvfb (virtual framebuffer for headless Wine) ───────────────
echo ">> Starting Xvfb on display ${DISPLAY}"
Xvfb ${DISPLAY} -screen 0 1024x768x16 -nolisten tcp &
XVFB_PID=$!
sleep 2

# Verify Xvfb started
if ! kill -0 ${XVFB_PID} 2>/dev/null; then
    echo "ERROR: Xvfb failed to start. Trying alternative..."
    # Try without -nolisten
    Xvfb ${DISPLAY} -screen 0 1024x768x16 &
    XVFB_PID=$!
    sleep 2
    if ! kill -0 ${XVFB_PID} 2>/dev/null; then
        echo "ERROR: Xvfb still failed. Cannot run headless Wine."
        exit 1
    fi
fi

echo ">> Xvfb running (PID ${XVFB_PID})"

# ── Handle shutdown gracefully ───────────────────────────────────────
cleanup() {
    echo ""
    echo ">> Shutting down server..."
    kill ${SERVER_PID} 2>/dev/null || true
    wait ${SERVER_PID} 2>/dev/null || true
    kill ${XVFB_PID} 2>/dev/null || true
    echo ">> Server stopped."
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── Launch the server ────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Server: ${SERVER_NAME}"
echo "  Port:   ${GAME_PORT}-${MAX_PORT}/udp"
echo "  Players: ${MAX_PLAYERS}"
echo "  Mode:   ${GAMEMODE}"
echo "  Seed:   ${GALAXY_SEED}"
echo "============================================"
echo ""
echo ">> Launching CubicOdysseyServer.exe via Wine..."

cd "${SERVER_DIR}"
wine ./server/CubicOdysseyServer.exe \
    -Port=${GAME_PORT} \
    -MaxPort=${MAX_PORT} \
    -Password="${SERVER_PASSWORD}" \
    -Gamemode=${GAMEMODE} \
    -MaxNumPlayers=${MAX_PLAYERS} &

SERVER_PID=$!
echo ">> Server running (PID ${SERVER_PID})"
echo ">> Connect with the lobby code shown above (e.g. DS-XXXXXX)"

# Wait for server process
wait ${SERVER_PID}
echo ">> Server process exited."
cleanup

#!/bin/bash
set -e

SERVER_DIR="/root/server_files"
DATA_DIR="/root/persistent_data"
STEAMCMD="/root/steamcmd/steamcmd.sh"
CONFIG_FILE="${SERVER_DIR}/config/server_config.txt"
SERVER_EXE=""

echo "============================================"
echo "  Cubic Odyssey Dedicated Server (Docker)"
echo "============================================"

# ── Install / Update server files via SteamCMD ──────────────────────
EXISTING_EXE=$(find "${SERVER_DIR}" -iname "CubicOdysseyServer.exe" -type f 2>/dev/null | head -1)
if [ "${UPDATE_ON_START}" = "true" ] || [ -z "${EXISTING_EXE}" ]; then
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

    if ! ${STEAMCMD} \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir "${SERVER_DIR}" \
        ${STEAM_LOGIN} \
        +app_license_request ${APP_ID} \
        +app_update ${APP_ID} validate \
        +quit; then
        echo ""
        echo "ERROR: SteamCMD failed. Sleeping 5 minutes to avoid rate limiting..."
        sleep 300
        exit 1
    fi

    # Set up Steam SDK libraries (some servers need these)
    mkdir -p "${SERVER_DIR}/.steam/sdk32" "${SERVER_DIR}/.steam/sdk64" 2>/dev/null || true
    cp -f /root/steamcmd/linux32/steamclient.so "${SERVER_DIR}/.steam/sdk32/" 2>/dev/null || true
    cp -f /root/steamcmd/linux64/steamclient.so "${SERVER_DIR}/.steam/sdk64/" 2>/dev/null || true

    echo ""
    echo ">> Update complete."
else
    echo ">> Skipping update (UPDATE_ON_START=false and server exists)"
fi

# ── Find the server binary ──────────────────────────────────────────
SERVER_EXE=$(find "${SERVER_DIR}" -iname "CubicOdysseyServer.exe" -type f 2>/dev/null | head -1)
if [ -z "${SERVER_EXE}" ]; then
    echo ""
    echo "ERROR: CubicOdysseyServer.exe not found anywhere in ${SERVER_DIR}"
    echo "Listing all .exe files found:"
    find "${SERVER_DIR}" -iname "*.exe" -type f 2>/dev/null
    echo ""
    echo "This game requires a Steam account that OWNS the Cubic Odyssey"
    echo "Dedicated Server tool (free). Anonymous login may not work."
    echo "Set STEAM_USER and STEAM_PASS environment variables."
    echo ""
    echo ">> Sleeping 5 minutes before exit to avoid rate-limiting Steam..."
    sleep 300
    exit 1
fi
SERVER_EXE_DIR=$(dirname "${SERVER_EXE}")
echo ">> Found server binary: ${SERVER_EXE}"

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
        if [ -d "${SERVER_EXE_DIR}/${subdir}" ] && [ ! -L "${SERVER_EXE_DIR}/${subdir}" ]; then
            echo ">> Moving existing ${subdir} to persistent_data"
            mv "${SERVER_EXE_DIR}/${subdir}" "${DATA_DIR}/${subdir}"
            ln -sf "${DATA_DIR}/${subdir}" "${SERVER_EXE_DIR}/${subdir}"
        fi
    done
fi

# ── Initialize Wine prefix (suppress first-run noise) ────────────────
echo ">> Initializing Wine prefix..."
export WINEPREFIX="/root/.wine"
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

cd "${SERVER_EXE_DIR}"
wine "${SERVER_EXE}" \
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

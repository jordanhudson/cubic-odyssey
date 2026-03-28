#!/bin/bash
set -e

SERVER_DIR="/root/server_files"
SERVER_EXE="${SERVER_DIR}/server/CubicOdysseyServer.exe"
STEAMCMD="/root/steamcmd/steamcmd.sh"
CONFIG_FILE="${SERVER_DIR}/config/server_config.txt"

# ── Install / Update via SteamCMD ────────────────────────────────────
if [ "${UPDATE_ON_START}" = "true" ] || [ ! -f "${SERVER_EXE}" ]; then
    echo ">> Updating Cubic Odyssey Dedicated Server (AppID ${APP_ID})..."
    if ! ${STEAMCMD} \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir "${SERVER_DIR}" \
        +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} \
        +app_license_request ${APP_ID} \
        +app_update ${APP_ID} validate \
        +quit; then
        echo "ERROR: SteamCMD failed. Sleeping 5 minutes to avoid rate limiting..."
        sleep 300
        exit 1
    fi
fi

if [ ! -f "${SERVER_EXE}" ]; then
    echo "ERROR: ${SERVER_EXE} not found. Does your Steam account own the dedicated server tool?"
    sleep 300
    exit 1
fi

# ── Generate config if missing ───────────────────────────────────────
mkdir -p "${SERVER_DIR}/config"
if [ ! -f "${CONFIG_FILE}" ]; then
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
    echo ">> Generated ${CONFIG_FILE}"
fi

# ── Start Xvfb + Wine ────────────────────────────────────────────────
export WINEPREFIX="/root/.wine"
Xvfb ${DISPLAY} -screen 0 1024x768x16 -nolisten tcp &
XVFB_PID=$!
sleep 1
wineboot --init 2>/dev/null || true

# ── Graceful shutdown ────────────────────────────────────────────────
cleanup() {
    echo ">> Shutting down..."
    kill ${SERVER_PID} 2>/dev/null || true
    wait ${SERVER_PID} 2>/dev/null || true
    kill ${XVFB_PID} 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── Launch ───────────────────────────────────────────────────────────
echo ">> Starting ${SERVER_NAME} (${GAME_PORT}-${MAX_PORT}/udp, ${MAX_PLAYERS} players, ${GAMEMODE})"
echo ">> Lobby code will appear in: ${SERVER_DIR}/server/logs/"

cd "${SERVER_DIR}/server"
wine "${SERVER_EXE}" \
    -log \
    -Port=${GAME_PORT} \
    -MaxPort=${MAX_PORT} \
    -Password="${SERVER_PASSWORD}" \
    -Gamemode=${GAMEMODE} \
    -MaxNumPlayers=${MAX_PLAYERS} 2>&1 | grep --line-buffered -v '^[#[:space:]]*$' &

SERVER_PID=$!

# ── Watch for lobby code in log files ────────────────────────────────
(
    sleep 10
    LOG_DIR="${SERVER_DIR}/server/logs"
    for i in $(seq 1 30); do
        LATEST=$(ls -t "${LOG_DIR}"/*.txt 2>/dev/null | head -1)
        if [ -n "${LATEST}" ]; then
            LOBBY=$(grep -o 'Lobby Key: DS-[A-Z0-9]*' "${LATEST}" 2>/dev/null | head -1)
            if [ -n "${LOBBY}" ]; then
                echo ""
                echo "========================================="
                echo "  ${LOBBY}"
                echo "========================================="
                echo ""
                break
            fi
        fi
        sleep 5
    done
) &

wait ${SERVER_PID}
cleanup

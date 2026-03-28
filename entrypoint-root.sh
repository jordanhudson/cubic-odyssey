#!/bin/bash
# Runs as root to fix volume permissions, then drops to cubic user
chown -R cubic:cubic /home/cubic/server_files /home/cubic/persistent_data /home/cubic/Steam 2>/dev/null || true
exec su -s /bin/bash cubic -c "/home/cubic/entrypoint.sh"

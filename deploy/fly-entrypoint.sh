#!/bin/sh
set -eu
umask 077

: "${APP_KEY:?Set APP_KEY using fly secrets}"
: "${SECRET_KEY_BASE:?Set SECRET_KEY_BASE using fly secrets}"
: "${ADMIN_PASSWORD:?Set ADMIN_PASSWORD using fly secrets}"
if [ "${#APP_KEY}" -lt 32 ] || [ "${#SECRET_KEY_BASE}" -lt 32 ] || [ "${#ADMIN_PASSWORD}" -lt 12 ]; then
  echo 'Use signing secrets of at least 32 characters and an admin password of at least 12 characters.' >&2
  exit 64
fi

if [ -z "${APP_URL:-}" ]; then
  : "${FLY_APP_NAME:?Set APP_URL for local containers}"
  APP_URL="https://${FLY_APP_NAME}.fly.dev"
fi
export APP_URL
: "${DB_DATABASE:=/data/sourcecat.sqlite}"
: "${CACHE_PATH:=/data/cache}"
export DB_DATABASE CACHE_PATH

# Never silently place production SQLite data on Fly's ephemeral root disk.
if [ -n "${FLY_APP_NAME:-}" ]; then
  if ! awk '$2 == "/data" { found=1 } END { exit !found }' /proc/mounts; then
    echo 'Mount the sourcecat_data Fly volume at /data before starting.' >&2
    exit 64
  fi
fi
case "$DB_DATABASE" in /data/*) ;; *) echo 'DB_DATABASE must be inside /data.' >&2; exit 64 ;; esac
case "$CACHE_PATH" in /data/*) ;; *) echo 'CACHE_PATH must be inside /data.' >&2; exit 64 ;; esac

mkdir -p "$(dirname "$DB_DATABASE")" "$CACHE_PATH"
sqlite3 "$DB_DATABASE" < /app/sessions.sql
sqlite3 "$DB_DATABASE" 'PRAGMA journal_mode=WAL;' > /dev/null
chown -R webapp:webapp /data
chmod 700 /data
chmod 600 "$DB_DATABASE"

# Explicit shell invocation supports shipment scripts with license headers.
exec su-exec webapp:webapp /bin/sh /app/entrypoint.sh "$@"

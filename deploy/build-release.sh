#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
gleam deps download
npm ci
./glimr build
npm run build
gleam export erlang-shipment
release=build/erlang-shipment
cp -R config "$release/"
# Glimr resolves the Vite manifest and assets from the working directory.
mkdir -p "$release/priv/static"
cp -R priv/static/. "$release/priv/static/"
rm -f "$release/priv/static/hot"
cp src/database/main/_migrations/20260312201116_create_session_table.sql "$release/sessions.sql"
printf 'Release ready: %s\n' "$release"

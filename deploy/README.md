# One VPS + Caddy + SQLite

Use an Ubuntu VPS in Singapore. Start with 1–2 GB RAM. Build on the VPS so the SQLite native library matches its OS and architecture. Install Erlang/OTP, Gleam, Node.js/npm, build-essential, sqlite3 and Caddy. Use compatible Erlang and Gleam versions (this project was built locally with OTP 29 and Gleam 1.18.1).

## Build

Copy the project source to the VPS, excluding `.env`, node_modules, build and local database files. In the project directory:

```sh
./deploy/build-release.sh
```

The output is `build/erlang-shipment`. It includes compiled Erlang dependencies, configuration, frontend assets and the session schema. Node and Gleam are only needed for builds; Erlang is needed at runtime. Never copy the development `.env` into a release.

## Install the first release

Run from the project directory on the VPS:

```sh
sudo useradd --system --home-dir /var/lib/glimr --shell /usr/sbin/nologin glimr
sudo install -d -m 0755 /opt/glimr/releases
sudo install -d -m 0700 /etc/glimr
sudo install -d -o glimr -g glimr -m 0700 /var/lib/glimr /var/lib/glimr/cache
release_id=$(date -u +%Y%m%dT%H%M%S)
sudo cp -R build/erlang-shipment "/opt/glimr/releases/$release_id"
sudo ln -s "/opt/glimr/releases/$release_id" /opt/glimr/current
sudo install -m 0600 deploy/production.env.example /etc/glimr/production.env
sudoedit /etc/glimr/production.env
```

Replace the example domain and all secret placeholders. Generate each secret separately with `openssl rand -hex 32`. Keep these values stable across deployments. Set a strong admin password. Do not set `DEV_PROXY_PORT`.

Before the first start, initialize sessions:

```sh
sudo -u glimr sqlite3 /var/lib/glimr/blog.sqlite < /opt/glimr/current/sessions.sql
```

The app creates its content tables and starter content on first boot. To preserve existing local posts instead, take a consistent local snapshot with `sqlite3 src/database/main/data.db ".backup '/tmp/blog.sqlite'"`, transfer that snapshot to the VPS, install it as `/var/lib/glimr/blog.sqlite` owned by `glimr`, then run the session initialization command. Do this before starting the service; do not overwrite a live production database.

```sh
sudo install -m 0644 deploy/glimr.service /etc/systemd/system/glimr.service
sudo systemctl daemon-reload
sudo systemctl enable --now glimr
curl -I http://127.0.0.1:8000
sudo journalctl -u glimr -n 50 --no-pager
```

## Domain and HTTPS

Point your domain's A record to the VPS IP. Only add an AAAA record if IPv6 is configured. Edit `deploy/Caddyfile` with the same domain used in `APP_URL`, then:

```sh
sudo install -m 0644 deploy/Caddyfile /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl enable --now caddy
sudo systemctl reload caddy
```

Allow TCP 80 and 443 in the server/provider firewall, retaining SSH access. Port 8000 stays on localhost. Visit `https://your-domain/` and `/admin`; check thumbnails, articles, videos, login and saving a draft.

## Updates and rollback

Build the updated source using the build script. Copy its shipment to a new timestamped release directory as above. Switch the symlink atomically, then restart:

```sh
sudo ln -s "/opt/glimr/releases/$release_id" /opt/glimr/next
sudo mv -Tf /opt/glimr/next /opt/glimr/current
sudo systemctl restart glimr
sudo journalctl -u glimr -n 50 --no-pager
```

Set `release_id` to the directory just installed. To roll back code, switch to the previous release the same way. SQLite and cache remain in `/var/lib/glimr`; secrets remain in `/etc/glimr`. Back up before future schema changes; a code rollback does not reverse database changes.

## Backups

Install and run the supplied online SQLite backup script:

```sh
sudo install -m 0755 deploy/backup.sh /usr/local/sbin/glimr-backup
sudo /usr/local/sbin/glimr-backup
```

Schedule it daily using your VPS backup scheduler or a systemd timer, copy snapshots off the VPS, and periodically test restoration. The script retains all snapshots; manage retention according to your available disk space. Restore while `glimr` is stopped and ensure the restored file is owned by `glimr`. Save production secrets securely alongside your recovery instructions.

Official deployment reference: https://gleam.run/deployment/linux-server/

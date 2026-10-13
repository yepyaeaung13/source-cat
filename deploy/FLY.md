# SourceCat on Fly.io

This setup uses one Machine in Singapore (`sin`), 512 MB RAM, a 1 GB persistent
volume, and Fly's HTTPS proxy. It runs the compiled Erlang shipment, not the
development watcher. Node.js and Gleam are build dependencies only. No Caddy
or PostgreSQL is needed.

## First deployment

Install [flyctl](https://docs.fly.io/flyctl/install/) and sign in:

```sh
fly auth login
```

From the project root, replace `YOUR_UNIQUE_APP_NAME` with an available name.
`sourcecat` may already be taken. Launch creates an app in your selected Fly
organization but does not deploy it yet:

```sh
fly launch --copy-config --no-deploy --no-db --ha=false --name YOUR_UNIQUE_APP_NAME --region sin
```

Confirm `fly.toml` contains your chosen app name and still has the `/data` mount,
port 8000, and health check. Keep all subsequent commands in this directory.
Create the volume if `fly volumes list` shows none (do not create a duplicate):

```sh
fly volumes list
fly volumes create sourcecat_data --region sin --size 1 --snapshot-retention 14
```

The entrypoint derives `APP_URL=https://YOUR_UNIQUE_APP_NAME.fly.dev` from Fly's
runtime app name. For a custom domain, set `APP_URL` to its canonical HTTPS URL
and configure its Fly certificate/DNS before using it.

Generate signing keys and enter the Studio password without printing it or
putting secret values in command-line arguments:

```sh
python3 - <<'PY' | fly secrets import --stage
import getpass, secrets, sys
password = getpass.getpass('Choose a strong Studio password (12+ characters): ')
if len(password) < 12 or any(c in password for c in ['\n', '\r', '"']):
    sys.exit('Use at least 12 characters, without newlines or double quotes.')
print('APP_KEY=' + secrets.token_hex(32))
print('SECRET_KEY_BASE=' + secrets.token_hex(32))
print('ADMIN_PASSWORD="' + password + '"')
PY
```

Save the Studio password securely. Keep the signing secrets stable across
updates; generating new ones invalidates existing signed sessions.

```sh
fly config validate
fly deploy --ha=false
fly status
fly checks list
fly logs
fly open
```

Visit `/healthz`, `/admin`, `/community` and a post. Check Studio login, visitor
PIN login, comments and bookmarks. The entrypoint initializes the session schema
idempotently and enables SQLite WAL; the app initializes its other tables.
It refuses to start on Fly if `/data` is not a mounted volume.

## Updates

```sh
fly deploy --ha=false
```

Use one Machine with this plain SQLite setup. `--ha=false` prevents spare
Machines during deployment. Separate Fly volumes do not replicate data. Do not
increase the Machine count or add regions until database replication is added.
Single-Machine deployments can briefly interrupt service during updates, and a
host failure can cause downtime. There is no release command: temporary release
Machines cannot access this persistent volume.

## Back up and recover

Fly volume snapshots are configured daily with 14-day retention. Keep separate
SQLite backups outside Fly too; snapshots are not a substitute for tested
off-platform recovery.

Create a consistent online SQLite snapshot inside the running Machine:

```sh
fly ssh console -C "sqlite3 /data/sourcecat.sqlite \".backup '/data/sourcecat-backup.sqlite'\""
fly ssh sftp get /data/sourcecat-backup.sqlite ./sourcecat-backup.sqlite
```

Store downloaded backups securely: they include user accounts and sessions.
For restoration, stop the application writer, restore the snapshot into the
mounted volume, and restart the Machine. Never overwrite a live database.

To migrate local content, first make a consistent local backup with SQLite's
`.backup` command. Transfer it to the Fly volume before first production start
or during a maintenance stop; deploy does not copy your local database.

## Local container check

With Docker available:

```sh
docker build -t sourcecat:local .
docker volume create sourcecat-local-data
```

Use a private ignored env file containing the three secrets and
`APP_URL=http://localhost:8080`, then run:

```sh
docker run --rm --name sourcecat-local -p 127.0.0.1:8080:8000 --env-file .env.fly-local -v sourcecat-local-data:/data sourcecat:local
```

Open `http://localhost:8080/healthz`. Stop and restart the container with the
same named volume and verify saved content remains. The `.dockerignore`
excludes local secrets, SQLite databases, cache, screenshots and build output
from both local and remote build contexts.

## References

- [Gleam's Fly guide](https://gleam.run/deployment/fly/)
- [Fly app configuration](https://docs.fly.io/reference/configuration)
- [Fly volumes](https://docs.fly.io/volumes/overview)

#!/usr/bin/env bash
set -euo pipefail
# Run as root; SQLite's backup API creates a consistent snapshot while online.
backup_dir=/var/backups/glimr
install -d -m 0700 "$backup_dir"
backup_file="$backup_dir/blog-$(date -u +%Y%m%dT%H%M%S).sqlite"
umask 077
sqlite3 /var/lib/glimr/blog.sqlite ".backup '$backup_file'"
printf 'Backup saved: %s\n' "$backup_file"

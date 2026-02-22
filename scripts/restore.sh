#!/bin/bash
# Restore WordPress from backup
# Usage: ./restore.sh db_20260218_023000.sql.gz wp-content_20260218_023000.tar.gz

set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"
DB_CONTAINER="${DB_CONTAINER:-mariadb}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <db-backup.sql.gz> <wp-content-backup.tar.gz>"
  echo "Example: $0 db_20260218_023000.sql.gz wp-content_20260218_023000.tar.gz"
  exit 1
fi

DB_BACKUP="$1"
WP_BACKUP="$2"

echo "WARNING: This will REPLACE current WordPress data!"
read -p "Are you sure? Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Restore cancelled."
  exit 0
fi

echo "Stopping containers..."
docker compose stop wordpress

echo "Restoring database..."
gunzip < "$BACKUP_DIR/$DB_BACKUP" | docker exec -i "$DB_CONTAINER" mysql -u root -p"$DB_ROOT_PASSWORD" wordpress

echo "Restoring wp-content..."
docker run --rm -v wp-hugo-static_wp-html:/data -v "$BACKUP_DIR:/backup" alpine sh -c "rm -rf /data/* && tar xzf /backup/$WP_BACKUP -C /data"

echo "Starting containers..."
docker compose start wordpress

echo "Restore complete!"

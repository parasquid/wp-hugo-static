#!/bin/bash
# backup.sh - Backup WordPress database and wp-content
# Run this before WUD updates (2:30am, before 3:00am WUD check)

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
DB_CONTAINER="${DB_CONTAINER:-mariadb}"
DB_NAME="${DB_NAME:-wordpress}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..."

# Backup database
echo "[$(date)] Back up database..."
docker exec "$DB_CONTAINER" mysqldump -u root -p"$DB_ROOT_PASSWORD" "$DB_NAME" | gzip > "$BACKUP_DIR/db_$TIMESTAMP.sql.gz"

# Backup wp-content
echo "[$(date)] Back up wp-content..."
docker run --rm -v wp-hugo-static_wp-content:/data -v "$BACKUP_DIR:/backup" alpine tar czf "/backup/wp-content_$TIMESTAMP.tar.gz" -C /data .

# Clean old backups
echo "[$(date)] Cleaning backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "*.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Backup complete:"
ls -lh "$BACKUP_DIR"/*"$TIMESTAMP"*

# Sync System

Automated WordPress to Hugo synchronization using webhooks for instant updates.

## Overview

The sync system consists of three components:

1. **WordPress mu-plugin** (`scripts/mu-plugins/sync-webhook.php`) - Sends webhooks on post/page changes
2. **Sync server** (`scripts/sync-server.rb`) - Receives webhooks and triggers syncs
3. **Sync library** (`lib/sync.rb`) - Shared library for fetching and processing content

## Architecture

```
WordPress Post/Page Change
         │
         ▼
   sync-webhook.php (mu-plugin)
         │ HTTP POST
         ▼
   sync-server.rb (:4567)
         │
         ▼
   lib/sync.rb ──▶ Hugo content/posts/
                          content/pages/
```

## Components

### WordPress mu-plugin

Located at `scripts/mu-plugins/sync-webhook.php`, this mu-plugin hooks into WordPress events:
- `save_post` - Triggered when a post is saved
- `transition_post_status` - Triggered when post status changes

When triggered, it sends an HTTP POST to the webhook URL with payload:
```json
{
  "action": "create|update|delete",
  "post_id": 123,
  "post_type": "post|page"
}
```

**Environment variables:**
- `SYNC_WEBHOOK_URL` - URL of the sync server webhook endpoint

### Sync Server

Located at `scripts/sync-server.rb`, this is a WEBrick-based HTTP server that:
- Receives webhooks from WordPress
- Validates the webhook secret
- Calls the sync library to fetch/process content

**Endpoints:**
- `GET /health` - Health check (returns "OK")
- `POST /webhook` - Receives WordPress webhooks

**Environment variables:**
- `SYNC_SERVER_PORT` - Port to listen on (default: 4567)
- `SYNC_WEBHOOK_SECRET` - Secret for webhook authentication (optional)
- `WP_API_URL` - WordPress REST API URL
- `POSTS_OUTPUT_DIR` - Directory for posts (default: hugo-site/content/posts)
- `PAGES_OUTPUT_DIR` - Directory for pages (default: hugo-site/content/pages)
- `STATE_FILE` - File to store last sync timestamp

### Sync Library

Located at `lib/sync.rb`, this module provides:
- `fetch_posts(since:)` - Fetch posts from WordPress
- `fetch_pages(since:)` - Fetch pages from WordPress
- `process_post(post, archived:)` - Convert post to Markdown
- `process_page(page)` - Convert page to Markdown
- `sync_post(post_id)` - Sync single post by ID
- `sync_incremental` - Incremental sync since last sync
- `sync_all` - Full sync with deletion detection

## Usage

### Starting the sync system

```bash
# Start all services including sync-server
docker compose up -d wordpress db builder sync-server hugo
```

The sync-server will:
1. Listen for webhooks on port 4567
2. When a webhook is received, fetch the changed content from WordPress
3. Convert it to Markdown and save to Hugo content directory
4. Hugo will auto-rebuild due to the `-w` (watch) flag

### Manual sync

```bash
# Full sync (all posts and pages)
docker compose exec builder ruby scripts/sync.rb --full

# Incremental sync (since last sync)
docker compose exec builder ruby scripts/sync.rb

# Sync single post
docker compose exec builder ruby scripts/sync.rb --post-id=123
```

### Testing the webhook

```bash
# Send a test webhook
curl -X POST http://localhost:4567/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: your-secret" \
  -d '{"action": "test"}'
```

## Docker Compose Services

| Service | Port | Description |
|---------|------|-------------|
| wordpress | 8888 | WordPress CMS |
| sync-server | 4567 | Webhook receiver |
| hugo | 1313 | Hugo dev server |
| builder | - | Ruby/Hugo build container |

## State Management

The sync system tracks the last sync time in `hugo-site/.last-sync`:
```json
{
  "last_sync": "2024-01-15T10:00:00Z"
}
```

This enables incremental syncs - only fetching content modified since the last sync.

## Security

- Webhook secret validation is optional but recommended
- Set `SYNC_WEBHOOK_SECRET` environment variable to enable
- The secret is passed via the `X-Webhook-Secret` header

## Troubleshooting

### Webhooks not arriving

1. Check that the mu-plugin is installed:
   ```bash
   docker compose exec wordpress ls -la /var/www/html/wp-content/mu-plugins/
   ```

2. Check WordPress error logs:
   ```bash
   docker compose logs wordpress
   ```

3. Verify the webhook URL is set:
   ```bash
   docker compose exec wordpress env | grep SYNC_WEBHOOK
   ```

### Sync server not receiving webhooks

1. Check if sync-server is running:
   ```bash
   docker compose ps sync-server
   ```

2. Test health endpoint:
   ```bash
   curl http://localhost:4567/health
   ```

3. Check sync-server logs:
   ```bash
   docker compose logs sync-server
   ```

### Content not syncing correctly

1. Check the sync library is working:
   ```bash
   docker compose exec builder ruby scripts/sync.rb --full
   ```

2. Verify Hugo content directory:
   ```bash
   ls -la hugo-site/content/posts/
   ```

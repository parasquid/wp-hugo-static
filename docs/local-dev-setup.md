# Local Development Setup

This guide covers how to set up and run the wp-hugo-static project locally for development.

## Prerequisites

- Docker installed
- Docker Compose plugin installed (`docker compose`)
- At least 2GB free disk space

## Quick Start

### 1. Start Services

```bash
docker compose up -d wordpress db builder
```

- WordPress available at: **http://localhost:8888**
- Builder container has Ruby, Hugo, Go pre-installed
- All containers on same Docker network

### 2. First-Time WordPress Setup

If starting fresh:

```bash
# Install WP-CLI (one-time)
docker compose exec wordpress sh -c 'curl -sL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /tmp/wp && chmod +x /tmp/wp'

# Install WordPress (use Docker network hostname, not localhost)
docker compose exec wordpress php /tmp/wp core install \
  --url=http://wordpress \
  --title="Dev Site" \
  --admin_user=admin \
  --admin_password=admin123 \
  --admin_email=admin@example.com \
  --skip-email \
  --allow-root
```

Default credentials: `admin` / `admin123`

### 3. Install Ruby Gems (First Time)

```bash
docker compose exec -w /app/scripts builder bundle install
```

Gems are cached in a volume and persist between runs.

## Common Tasks

### Create Test Posts

```bash
# Create Archived category
docker compose exec wordpress php /tmp/wp term create category Archived --allow-root

# Create regular post
docker compose exec wordpress php /tmp/wp post create \
  --post_title="My Post" \
  --post_content="Post content here" \
  --post_status=publish \
  --allow-root

# Create archived post
docker compose exec wordpress php /tmp/wp post create \
  --post_title="Old Post" \
  --post_content="Archived content" \
  --post_status=publish \
  --categories=Archived \
  --allow-root
```

### Fetch Posts to Hugo

```bash
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin \
  -e WP_APPLICATION_PASSWORD=admin123 \
  builder ruby scripts/fetch-posts.rb
```

Posts are converted to Markdown and saved to `hugo-site/content/posts/`

### Build Static Site

```bash
docker compose exec builder hugo -s /app/hugo-site --minify
```

Output goes to `hugo-site/public/`

### Full Workflow

```bash
# 1. Start services
docker compose up -d wordpress db builder

# 2. Fetch posts from WordPress (use http://wordpress, NOT localhost)
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin \
  -e WP_APPLICATION_PASSWORD=admin123 \
  builder ruby scripts/fetch-posts.rb

# 3. Fetch comments from GitHub (requires GITHUB_TOKEN)
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e GITHUB_TOKEN=ghp_xxx \
  -e GITHUB_REPO=owner/repo \
  builder ruby scripts/fetch-comments.rb

# 4. Build Hugo site
docker compose exec builder hugo -s /app/hugo-site --minify
```

## Container Overview

| Container | Purpose | Access |
|-----------|---------|--------|
| `wordpress` | WordPress CMS | http://localhost:8888 |
| `mariadb` | WordPress database | Internal only |
| `wp-builder` | Build tools (Ruby, Hugo, Go) | Use `docker compose exec builder` |

## Important: Use Docker Hostname for Scripts

When running scripts inside the builder container, use `http://wordpress` (Docker network hostname), NOT `http://localhost:8888`:

```bash
# Correct (for scripts inside builder)
-e WP_API_URL=http://wordpress/wp-json/wp/v2

# Wrong (for scripts inside builder - will fail)
-e WP_API_URL=http://localhost:8888/wp-json/wp/v2
```

This is because the builder container is on the same Docker network as WordPress and can resolve the `wordpress` hostname.

From your host machine (browser), use **http://localhost:8888** to access WordPress.

## Accessing WordPress Remotely (Tailscale, VPN, etc.)

By default, WordPress redirects to `localhost:8888` which won't work on remote devices. To access WordPress via Tailscale or other remote connections:

### 1. Get Your Tailscale IP

```bash
tailscale ip -4
```

### 2. Update WordPress Site URLs

```bash
# Replace with your actual Tailscale IP
TAILSCALE_IP="100.x.x.x"

docker compose exec db mysql -u root -p"${DB_ROOT_PASSWORD}" wordpress -e \
  "UPDATE wp_options SET option_value='http://${TAILSCALE_IP}:8888' WHERE option_name IN ('siteurl', 'home');"
```

### 3. Access Remotely

On your remote device, go to:
```
http://<tailscale-ip>:8888
```

### Note on Dynamic IPs

If your Tailscale IP changes, you'll need to update the URLs again:

```bash
TAILSCALE_IP=$(tailscale ip -4)
docker compose exec db mysql -u root -p"${DB_ROOT_PASSWORD}" wordpress -e \
  "UPDATE wp_options SET option_value='http://${TAILSCALE_IP}:8888' WHERE option_name IN ('siteurl', 'home');"
```

To find your `DB_ROOT_PASSWORD`, check the `.env` file.

## Environment Variables

Set these when running scripts:

| Variable | Description | Example |
|----------|-------------|---------|
| `WP_API_URL` | WordPress API (use Docker hostname) | `http://wordpress/wp-json/wp/v2` |
| `WP_USERNAME` | WP admin username | `admin` |
| `WP_APPLICATION_PASSWORD` | WP app password | (see below) |
| `GITHUB_TOKEN` | GitHub PAT for Discussions | `ghp_xxx` |
| `GITHUB_REPO` | GitHub repo (owner/repo) | `parasquid/wp-hugo-static` |
| `DB_ROOT_PASSWORD` | MariaDB root password | (from `.env` file) |

### Getting WordPress Application Password

1. Go to http://localhost:8888/wp-admin
2. Users → Profile
3. Application Passwords → Add New
4. Name it (e.g., "dev") and copy the generated password

Use the password as `WP_APPLICATION_PASSWORD`.

## Troubleshooting

### "Connection refused" or "Name or service not known"

Make sure you're using `http://wordpress` (Docker hostname), not `http://localhost:8888` when running scripts inside the builder container.

### Gem installation fails

```bash
docker volume rm parabosscom_builder-vendor
docker compose exec -w /app/scripts builder bundle install
```

### Hugo build fails with module errors

```bash
docker compose exec builder rm -rf /tmp/hugo_cache
docker compose exec builder hugo -s /app/hugo-site --minify
```

### Reset Everything

```bash
# Stop and remove all containers
docker compose down

# Remove volumes (will lose WordPress data)
docker compose down -v

# Start fresh
docker compose up -d wordpress db builder

# Re-run WordPress setup (step 2 above)
```
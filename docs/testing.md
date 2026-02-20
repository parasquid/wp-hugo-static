# Testing Guide

This guide covers how to test the wp-hugo-static workflow, including the baked comments feature and archive behavior.

See [local-dev-setup.md](local-dev-setup.md) for full setup instructions.

## Testing the Baked Comments Feature

### Overview

The baked comments feature fetches GitHub Discussions comments at build time and bakes them into static HTML:

- **Active posts**: Show baked comments + Giscus widget for new comments
- **Archived posts**: Show baked comments only (read-only)

### Testing Steps

#### 1. Start Services

```bash
docker compose up -d wordpress db builder
```

#### 2. Create Test Content

```bash
# Create Archived category
docker compose exec wordpress php /tmp/wp term create category Archived --allow-root

# Create regular post
docker compose exec wordpress php /tmp/wp post create \
  --post_title="Regular Post" \
  --post_content="This is a regular post" \
  --post_status=publish \
  --allow-root

# Create archived post
docker compose exec wordpress php /tmp/wp post create \
  --post_title="Archived Post" \
  --post_content="This is an archived post" \
  --post_status=publish \
  --categories=Archived \
  --allow-root
```

#### 3. Import to Hugo

Use `http://wordpress` (Docker hostname), NOT `localhost`:

```bash
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin \
  -e WP_APPLICATION_PASSWORD=admin123 \
  builder ruby scripts/fetch-posts.rb
```

Check the frontmatter - archived posts should have `archived: true`

#### 4. Build and Verify

```bash
docker compose exec builder hugo -s /app/hugo-site --minify
```

Check `hugo-site/public/posts/` - archived post should have baked comments but NO Giscus widget.

## Seed Scripts

| Script | Purpose |
|--------|---------|
| `ensure-archived-category.rb` | Creates the Archived category |
| `seed-posts.rb` | Creates test posts in WordPress |
| `seed-discussions.rb` | Creates GitHub Discussions with comments |

Run them via:

```bash
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin \
  -e WP_APPLICATION_PASSWORD=admin123 \
  builder ruby scripts/seed-posts.rb
```

## Troubleshooting

### "Connection refused" or "Name or service not known"

Make sure you're using `http://wordpress` (Docker hostname), not `http://localhost:8888` when running scripts inside the builder container.

### WordPress Not Accessible

```bash
docker ps | grep wordpress
docker logs wordpress
```

### Build Issues

```bash
docker compose exec builder rm -rf /tmp/hugo_cache
docker compose exec builder hugo -s /app/hugo-site --minify
```
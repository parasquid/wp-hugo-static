# End-to-End Workflow Reference

Quick reference for running the complete WordPress → Hugo workflow.

## Prerequisites

```bash
docker compose up -d wordpress db builder
```

## Standard Workflow

### 1. Create Test Content (WP-CLI)

```bash
# Create category
docker compose exec wordpress php /tmp/wp term create category Archived --allow-root

# Create posts
docker compose exec wordpress php /tmp/wp post create \
  --post_title="Regular Post 1" \
  --post_content="<p>Content here</p>" \
  --post_status=publish \
  --allow-root

docker compose exec wordpress php /tmp/wp post create \
  --post_title="Archived Post" \
  --post_content="<p>Archived content</p>" \
  --post_status=publish \
  --categories=Archived \
  --allow-root
```

### 2. Fetch Posts

```bash
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e OUTPUT_DIR=/app/hugo-site/content/posts \
  builder ruby scripts/fetch-posts.rb
```

### 3. Fetch Images

```bash
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e SITE_URL=http://example.com \
  -w /app/scripts builder bundle exec ruby fetch-images.rb
```

### 4. Build Site

```bash
docker compose exec builder hugo -s /app/hugo-site --minify
```

### 5. Verify

```bash
ls hugo-site/public/posts/
ls hugo-site/public/images/
```

## Environment Variables

| Variable | Value | Required For |
|----------|-------|--------------|
| `WP_API_URL` | `http://wordpress/wp-json/wp/v2` | All scripts |
| `OUTPUT_DIR` | `/app/hugo-site/content/posts` | fetch-posts.rb |
| `SITE_URL` | Your site URL | fetch-images.rb (watermark) |

## File Paths (Inside Container)

| Location | Path |
|----------|------|
| Scripts | `/app/scripts/` |
| Hugo site | `/app/hugo-site/` |
| Posts output | `/app/hugo-site/content/posts/` |
| Images output | `/app/hugo-site/static/images/` |

## One-Line Test

```bash
docker compose exec wordpress php /tmp/wp post create --post_title="Test $(date +%s)" --post_content="<p>Test</p>" --post_status=publish --allow-root && \
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 -e OUTPUT_DIR=/app/hugo-site/content/posts builder ruby scripts/fetch-posts.rb && \
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 -e SITE_URL=http://example.com -w /app/scripts builder bundle exec ruby fetch-images.rb && \
docker compose exec builder hugo -s /app/hugo-site --minify
```

## Reset Commands

```bash
# Clear Hugo content
rm -rf hugo-site/content/posts/* hugo-site/static/images/content/*

# Clear Hugo cache
docker compose exec builder rm -rf /tmp/hugo_cache

# Rebuild
docker compose exec builder hugo -s /app/hugo-site --minify
```

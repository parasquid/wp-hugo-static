# End-to-End Workflow Reference

Quick reference for running the complete WordPress → Hugo workflow.

## Canonical Production Deploy

Use the local deploy wrapper for production deploys:

```bash
./scripts/deploy-local.sh
```

This command fetches WordPress content locally, builds Hugo, then deploys `hugo-site/public` to Cloudflare Pages.

## Prerequisites

```bash
docker compose up -d wordpress db builder
```

Required local tools:
- `docker`
- `wrangler`

Required environment variables:
- `WP_API_URL`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_PAGES_PROJECT`

Optional for baked comments:
- `GITHUB_TOKEN`
- `GITHUB_REPO`

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
  -e POSTS_OUTPUT_DIR=/app/hugo-site/content/posts \
  -e PAGES_OUTPUT_DIR=/app/hugo-site/content/pages \
  -e STATE_FILE=/app/hugo-site/.last-sync \
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

### 6. Deploy to Cloudflare Pages

```bash
wrangler pages deploy hugo-site/public --project-name "$CLOUDFLARE_PAGES_PROJECT"
```

## Environment Variables

| Variable | Value | Required For |
|----------|-------|--------------|
| `WP_API_URL` | `http://wordpress/wp-json/wp/v2` | All scripts |
| `POSTS_OUTPUT_DIR` | `/app/hugo-site/content/posts` | fetch-posts.rb |
| `PAGES_OUTPUT_DIR` | `/app/hugo-site/content/pages` | fetch-pages.rb |
| `STATE_FILE` | `/app/hugo-site/.last-sync` | incremental sync state |
| `SITE_URL` | Your site URL | fetch-images.rb (watermark) |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token | local deploy to Pages |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID | local deploy to Pages |
| `CLOUDFLARE_PAGES_PROJECT` | Cloudflare Pages project name | local deploy to Pages |
| `GITHUB_TOKEN` | GitHub PAT | optional comments fetch |
| `GITHUB_REPO` | GitHub repository (`owner/repo`) | optional comments fetch |

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
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 -e POSTS_OUTPUT_DIR=/app/hugo-site/content/posts -e PAGES_OUTPUT_DIR=/app/hugo-site/content/pages -e STATE_FILE=/app/hugo-site/.last-sync builder ruby scripts/fetch-posts.rb && \
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 -e SITE_URL=http://example.com -w /app/scripts builder bundle exec ruby fetch-images.rb && \
docker compose exec builder hugo -s /app/hugo-site --minify
```

## Production Runbook (Manual)

### Regular deploy

```bash
./scripts/deploy-local.sh
```

### Failure handling

```bash
# Re-run with shell tracing for diagnostics
bash -x ./scripts/deploy-local.sh

# If fetch/build fails, inspect service logs
docker compose logs --tail=200 builder wordpress
```

### Rollback

```bash
# Switch to known-good commit and redeploy
git checkout <known-good-commit>
./scripts/deploy-local.sh

# Return to working branch
git checkout -
```

## Reset Commands

```bash
# Clear Hugo content
rm -rf hugo-site/content/* hugo-site/static/images/content/*

# Clear Hugo cache
docker compose exec builder rm -rf /tmp/hugo_cache

# Rebuild
docker compose exec builder hugo -s /app/hugo-site --minify
```

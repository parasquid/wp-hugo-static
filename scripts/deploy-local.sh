#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
}

require_env() {
  local key="$1"
  if [[ -z "${!key:-}" ]]; then
    echo "Error: required environment variable is missing: $key" >&2
    exit 1
  fi
}

require_env WP_API_URL
require_env CLOUDFLARE_API_TOKEN
require_env CLOUDFLARE_ACCOUNT_ID
require_env CLOUDFLARE_PAGES_PROJECT

require_command docker
require_command wrangler

SITE_URL="${SITE_URL:-https://${CLOUDFLARE_PAGES_PROJECT}.pages.dev}"

echo "[deploy-local] Starting local WordPress -> Hugo -> Cloudflare Pages deploy"
echo "[deploy-local] Ensuring Docker services are running"
docker compose up -d wordpress db builder

echo "[deploy-local] Installing Ruby dependencies in builder"
docker compose exec -T -w /app/scripts builder bundle install

echo "[deploy-local] Fetching posts"
docker compose exec -T \
  -e WP_API_URL="$WP_API_URL" \
  -e POSTS_OUTPUT_DIR=/app/hugo-site/content/posts \
  -e PAGES_OUTPUT_DIR=/app/hugo-site/content/pages \
  -e STATE_FILE=/app/hugo-site/.last-sync \
  builder ruby scripts/fetch-posts.rb

echo "[deploy-local] Fetching pages"
docker compose exec -T \
  -e WP_API_URL="$WP_API_URL" \
  -e PAGES_OUTPUT_DIR=/app/hugo-site/content/pages \
  builder ruby scripts/fetch-pages.rb

echo "[deploy-local] Fetching images"
docker compose exec -T \
  -e WP_API_URL="$WP_API_URL" \
  -e SITE_URL="$SITE_URL" \
  -w /app/scripts \
  builder bundle exec ruby fetch-images.rb

if [[ -n "${GITHUB_TOKEN:-}" && -n "${GITHUB_REPO:-}" ]]; then
  echo "[deploy-local] Fetching comments"
  docker compose exec -T \
    -e WP_API_URL="$WP_API_URL" \
    -e GITHUB_TOKEN="$GITHUB_TOKEN" \
    -e GITHUB_REPO="$GITHUB_REPO" \
    builder ruby scripts/fetch-comments.rb
else
  echo "[deploy-local] Skipping comments fetch (set GITHUB_TOKEN and GITHUB_REPO to enable)"
fi

echo "[deploy-local] Building Hugo site"
docker compose exec -T builder hugo -s /app/hugo-site --minify

if [[ ! -d "hugo-site/public" ]]; then
  echo "Error: hugo-site/public was not generated" >&2
  exit 1
fi

echo "[deploy-local] Deploying hugo-site/public to Cloudflare Pages"
export CLOUDFLARE_API_TOKEN
export CLOUDFLARE_ACCOUNT_ID
wrangler pages deploy hugo-site/public --project-name "$CLOUDFLARE_PAGES_PROJECT"

echo "[deploy-local] Deploy complete"

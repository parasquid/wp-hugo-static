#!/bin/bash
# Run E2E tests - starts containers, runs tests, cleans up
# Usage: ./run-e2e-tests.sh

set -e

cd "$(dirname "$0")/.."

echo "Cleaning up previous test containers and data..."
docker compose -p test-e2e -f docker-compose.test.yml down -v --remove-orphans 2>/dev/null || true
rm -f hugo-site/content/posts/*.md
rm -rf hugo-site/public

echo "Starting test containers..."
docker compose -p test-e2e -f docker-compose.test.yml up -d

cleanup() {
    echo "Cleaning up..."
    docker compose -p test-e2e -f docker-compose.test.yml down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for WordPress to be ready..."
sleep 90

echo "Running E2E tests..."

# Run fetch-posts in builder container
echo "=== Fetching posts ==="
docker compose -p test-e2e exec -w /app/scripts -e WP_API_URL=http://test-wordpress/wp-json/wp/v2 -e WP_USERNAME= -e WP_APPLICATION_PASSWORD= builder ruby fetch-posts.rb

# Verify posts were fetched
POST_COUNT=$(ls -1 hugo-site/content/posts/*.md 2>/dev/null | wc -l)
if [ "$POST_COUNT" -eq 0 ]; then
    echo "FAIL: No posts fetched"
    exit 1
fi
echo "SUCCESS: Fetched $POST_COUNT posts"

# Run Hugo build in builder container
echo "=== Building Hugo site ==="
docker compose -p test-e2e exec -w /app builder hugo -s /app/hugo-site --minify

# Verify Hugo output
if [ ! -f hugo-site/public/index.html ]; then
    echo "FAIL: Hugo build failed - no index.html"
    exit 1
fi
echo "SUCCESS: Hugo build complete"

echo "=== All tests passed ==="

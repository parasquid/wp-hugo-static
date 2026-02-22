#!/bin/bash
set -e

echo "Starting WordPress seeding..."

wp post create \
    --post_type=post \
    --post_title='Regular Post 1' \
    --post_content='<p>This is Regular Post 1 for testing active comments.</p><p>It has the active comments widget enabled.</p><h2>Testing Active Comments</h2><p>We need to verify that comments are properly baked into the static HTML.</p>' \
    --post_status=publish \
    --allow-root

wp post create \
    --post_type=post \
    --post_title='Regular Post 2' \
    --post_content='<p>This is Regular Post 2 for testing active comments.</p><p>It also has the active comments widget enabled.</p><h2>Testing Multiple Posts</h2><p>We want to ensure multiple posts with comments work correctly.</p>' \
    --post_status=publish \
    --allow-root

if ! wp term get category archived --by=slug --allow-root 2>/dev/null; then
    wp term create category 'Archived' --allow-root
fi

ARCHIVED_TERM_ID=$(wp term get category archived --by=slug --field=term_id --allow-root)

wp post create \
    --post_type=post \
    --post_title='Archived Post' \
    --post_content='<p>This is an archived test post.</p><p>It should have baked comments but no Giscus widget.</p><h2>Archive Behavior</h2><p>Posts with the "Archived" category should display comments as static HTML only.</p>' \
    --post_status=publish \
    --post_category="${ARCHIVED_TERM_ID}" \
    --allow-root

wp user application-password create admin admin "Test App" "abcd 1234 efgh 5678" --allow-root 2>/dev/null || true

echo "Seeding complete!"

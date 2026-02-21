# WordPress CLI Reference Guide

Common WP-CLI patterns and gotchas for wp-hugo-static.

## Getting Category/Term ID

**Gotcha**: `wp term get category <name>` uses **slug** by default, not the term name.

```bash
# WRONG - won't work with "Archived" as name (uses slug by default)
wp term get category Archived --allow-root

# CORRECT - use --by=slug when searching by slug
wp term get category archived --by=slug --allow-root

# CORRECT - use --by=name when searching by display name  
wp term get category "Archived" --by=name --allow-root

# Get just the ID - use --field=term_id (valid fields from the term object)
wp term get category archived --by=slug --field=term_id --allow-root
```

## Creating Terms Conditionally

Always check if term exists before creating to avoid errors on re-runs:

```bash
# WRONG - fails on re-run if category exists
wp term create category 'Archived' --allow-root

# CORRECT - check first, then create
if ! wp term get category archived --by=slug --allow-root 2>/dev/null; then
    wp term create category 'Archived' --allow-root
fi
```

## WP-CLI in Docker

### Using wordpress:cli image

```bash
docker run --rm \
  --network wp-hugo-static_wp-network \
  -v wp-hugo-static_wp-html:/var/www/html \
  -e WORDPRESS_DB_HOST=db:3306 \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=${DB_PASSWORD} \
  -e WORDPRESS_DB_NAME=wordpress \
  wordpress:cli <command>
```

### Seeding in docker-compose

The seeder service mounts the WordPress volume and runs after WordPress is healthy:

```yaml
seeder:
  image: wordpress:cli
  depends_on:
    wordpress:
      condition: service_healthy
  environment:
    WORDPRESS_DB_HOST: db:3306
    WORDPRESS_DB_USER: wordpress
    WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
    WORDPRESS_DB_NAME: wordpress
  volumes:
    - wp-html:/var/www/html
```

## Common Commands

```bash
# List posts
wp post list --allow-root

# List categories  
wp term list category --allow-root

# Get post by ID
wp post get 1 --allow-root

# Check if WP is installed
wp core is-installed --allow-root
```

## Volume Mounts

**Important**: WordPress image uses anonymous volume for `/var/www/html`. To share between containers:

```yaml
# Use named volume for full WP installation
volumes:
  - wp-html:/var/www/html  # NOT wp-content:/var/www/html/wp-content
```

The `wp-content` volume mount only shares plugins/themes/uploads, not the core WP files.

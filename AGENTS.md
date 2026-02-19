# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-19
**Commit:** 552238b

## OVERVIEW

WordPress to Hugo static site converter with baked comments. WordPress content → Ruby scripts → Hugo → Cloudflare Pages.

## STRUCTURE

```
./
├── docker-compose.yml     # Docker services (WordPress, MariaDB, builder, WUD)
├── Dockerfile.builder    # Build container (Ruby, Hugo, Go)
├── .env.example          # Environment template
├── scripts/              # Ruby conversion scripts
├── hugo-site/           # Hugo static site source
├── .github/workflows/   # CI/CD (deploy.yml)
├── docs/                # User documentation
└── specs/               # Planning documents
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Docker infra | docker-compose.yml | WordPress, MariaDB, builder, WUD |
| Build container | Dockerfile.builder | Ruby 3.4, Hugo 0.131, Go 1.24 |
| WP→Hugo scripts | scripts/*.rb | fetch-posts, fetch-comments, seed-* |
| Hugo site | hugo-site/ | Stack theme, Hugo Modules |
| CI/CD | .github/workflows/deploy.yml | Cloudflare Pages |
| Docs | docs/*.md | local-dev-setup, testing, hybrid-content |

## CONVENTIONS

- Docker Compose: services on `wp-network` bridge
- Ruby scripts: require WordPress REST API + GitHub GraphQL
- Hugo: Stack theme via Hugo Modules (no git submodules)
- Posts: Markdown in hugo-site/content/posts/
- Archives: posts with "Archived" category get `archived: true` frontmatter

## ANTI-PATTERNS

- Don't run scripts directly on host - use `docker exec wp-builder`
- Don't use localhost for WP_API_URL in scripts - use Docker hostname `wordpress`
- Don't commit .env file (in .gitignore)

## COMMANDS

```bash
# Start services
docker compose up -d wordpress db builder

# Fetch posts
docker exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  wp-builder ruby scripts/fetch-posts.rb

# Build Hugo
docker exec wp-builder hugo -s /app/hugo-site --minify
```

## SCRIPTS

| Script | Purpose |
|--------|---------|
| fetch-posts.rb | Fetches WordPress posts → Hugo Markdown |
| fetch-pages.rb | Fetches WordPress pages → Hugo Markdown |
| fetch-comments.rb | Fetches GitHub Discussions → baked JSON |
| fetch-images.rb | Downloads images from WP to Hugo |
| seed-posts.rb | Creates test posts in WordPress |
| seed-discussions.rb | Creates test GitHub Discussions |
| ensure-archived-category.rb | Creates "Archived" category |

Run via:
```bash
docker exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  wp-builder ruby scripts/<script>.rb
```

## AGENT GUIDANCE

### NEVER Commit Without Explicit Permission

**CRITICAL:** Always ask the user for permission before committing and pushing changes. The user often catches issues the agent misses and wants to review changes before they are committed.

**Workflow:**
1. Make the changes
2. Show the user what changed (git diff)
3. Ask: "Should I commit and push these changes?"
4. Only commit after user confirms with "yes" or similar

### NOTES

- Builder container uses host network mode for localhost access
- WordPress runs on configurable port (default 8888)
- WUD auto-updates containers daily at 3am
- Baked comments: GitHub Discussions fetched at build time

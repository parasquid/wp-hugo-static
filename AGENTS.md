# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-19
**Commit:** 552238b

## SYSTEM PROMPT (for all future sessions)

**ALWAYS ask before committing:**
- After any code changes, ask "Should I commit these changes?"
- Wait for explicit "yes" before running `git commit`
- Wait for explicit "yes" before running `git push`
- Never commit or push automatically, even if changes seem correct

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

## CRITICAL: specs/ IS ALWAYS IMPORTANT

**Everything in `specs/` (including `specs/drafts/`) is always important.**

- Never delete or offer to delete files from `specs/`
- Never suggest cleaning up `specs/` as optional
- Always add `specs/` files to git when created
- This includes draft documents - they are intentionally in drafts/ but still valuable

## ANTI-PATTERNS

- Don't use `docker exec` - always use `docker compose exec` or `docker compose run`
- Don't use `docker run` - always use `docker compose run`
- Don't use localhost for WP_API_URL in scripts - use Docker hostname `wordpress`
- Don't commit .env file (in .gitignore)

## DOCKER COMMAND PATTERNS (Important!)

**ALWAYS use `docker compose` instead of `docker exec` or `docker run`.** The project uses Docker Compose for service orchestration.

### Running Ruby scripts with gems (e.g., fetch-images.rb)
After modifying Gemfile, you MUST rebuild the builder image:
```bash
# 1. Rebuild builder to include new dependencies
docker compose build builder

# 2. Install gems into vendor/bundle
docker compose run --rm -w /app/scripts builder bundle install

# 3. Run Ruby script with gems (use bundle exec!)
docker compose run --rm -w /app/scripts builder bundle exec ruby scripts/fetch-images.rb
```

### Running commands in running container
```bash
# WRONG - uses standalone docker
docker exec wp-builder ruby scripts/fetch-posts.rb

# CORRECT - uses docker compose
docker compose exec builder ruby scripts/fetch-posts.rb
```

### Common mistakes
- `docker exec wp-builder ruby ...` - bypasses Compose, may miss env vars
- `docker run wp-builder ruby ...` - creates new container, loses state
- Missing `bundle exec` - Ruby can't find gems
- Using `test-builder` image - always use `builder` service from docker-compose.yml

## COMMANDS

```bash
# Start services
docker compose up -d wordpress db builder

# Fetch posts (use docker compose exec, not docker exec)
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/fetch-posts.rb

# Build Hugo
docker compose exec builder hugo -s /app/hugo-site --minify
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
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/<script>.rb
```

## AGENT GUIDANCE

### NEVER Commit Without Explicit Permission (HARD RULE)

**THIS IS NOT OPTIONAL.** You broke this rule multiple times. Do not let it happen again.

**The workflow is:**
1. Make the changes
2. Show the user what changed (git diff --stat and/or git diff)
3. Ask DIRECTLY: "Should I commit these changes?"
4. **Wait for the user to say exactly "yes" or "commit"** - do NOT interpret other responses as permission
5. Commit
6. Ask DIRECTLY: "Should I push?" 
7. **Wait for the user to say exactly "yes" or "push"**
8. Push

**What counts as permission (and what does NOT):**

| ✅ Permission | ❌ NOT Permission |
|--------------|------------------|
| "yes, commit it" | "do it" |
| "yes, go ahead" | Any vague response |
| "yes please" | |
| "commit" | |
| "push" | |

**Consequences for breaking this rule:**
- This violates trust
- The user may catch bugs you missed
- The user may want to review changes before they become permanent
- You will be asked to add more guidance

**DO NOT:**
- Commit "just this small fix" without asking
- Assume "the user will say yes anyway"
- Skip asking because you're in a hurry
- Use commit messages like "minor fix" to bypass review
- Interpret any "yes" as commit permission unless it's DIRECTLY answering a commit question

### .sisyphus Directory Note

**IMPORTANT:** The `.sisyphus/` directory is **symlinked to `specs/`**. They are the same location.

- **Don't panic** if you see paths like `.sisyphus/plans/` or `specs/plans/` - they're identical
- **Don't try to fix** or reconcile the paths
- **Don't overthink** which one to use - both work
- The symlink exists for Oh My OpenCode compatibility while keeping the `specs/` convention

### RSpec-Given Syntax (CRITICAL)

**DO NOT use string descriptions with `And` or `Then` blocks in rspec-given.**

```ruby
# WRONG - This causes ArgumentError: wrong number of arguments
And('creates markdown files') do
  expect(files.count).to be > 0
end

# CORRECT - No string argument, just the block
And { expect(files.count).to be > 0 }

# CORRECT - Then without description
Then { expect(result).to be_success }
```

**Key differences from standard RSpec:**
- `it('description') { }` - RSpec way (OK)
- `Then('description') { }` - WRONG in rspec-given
- `Then { expectation }` - CORRECT rspec-given syntax
- `And('description') { }` - WRONG in rspec-given
- `And { expectation }` - CORRECT rspec-given syntax

**rspec-given keywords:**
- `Given(:var) { value }` - Setup variable
- `Given!(:var) { value }` - Setup with eager evaluation
- `When(:result) { action }` - Execute code under test
- `Then { expectation }` - Assert results (no string arg!)
- `And { expectation }` - Additional assertions (no string arg!)

### NOTES

- Builder container uses host network mode for localhost access
- WordPress runs on configurable port (default 8888)
- WUD auto-updates containers daily at 3am
- Baked comments: GitHub Discussions fetched at build time

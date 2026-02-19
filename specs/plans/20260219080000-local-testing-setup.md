# Local Testing Setup - Seed Scripts

## TL;DR

> Create seed scripts to automate testing the baked comments feature locally.
> 
> **Deliverables**:
> - scripts/seed-posts.rb - Seed WordPress with test posts (regular + archived)
> - scripts/seed-discussions.rb - Create GitHub Discussions with sample comments
> - Test verification script to confirm archived behavior works
> 
> **Reset**: docker compose down -v (drops volumes, fresh start)

---

## Context

### Problem
After implementing baked comments, how do we verify it works locally?
- Need test WordPress posts (regular + archived)
- Need sample GitHub Discussions with comments
- Need way to verify archived posts are handled correctly

### Solution
Create seed scripts that set up test data, then verify the feature works.

---

## Work Objectives

### Core Objective
Enable local testing of baked comments feature with reproducible test data.

### Concrete Deliverables
1. **scripts/seed-posts.rb** - Seed WordPress with:
   - 2 regular posts (for testing active comments)
   - 1 post with "Archived" category (for testing archived behavior)
   - **Create "Archived" category if not exists** in WordPress
   - **Idempotency**: Delete existing test posts first, then create fresh

2. **WordPress setup** - Ensure "Archived" category exists:
   - Add to WordPress container startup or add a setup script
   - When volumes are deleted and WP is fresh, Archived category is auto-created

3. **scripts/seed-discussions.rb** - Create GitHub Discussions:
   - Discussion for each regular post
   - Sample comments on discussions
   - No discussions for archived posts
   - **Skip if GITHUB_TOKEN or GITHUB_REPO not available** - inform user
   - **Idempotency**: Delete existing test posts first, then create fresh

3. **Verification** - Test that:
   - fetch-posts.rb skips archived posts (archived post NOT in hugo-site/content/posts/)
   - fetch-comments.rb skips archived posts (no JSON for archived)
   - Hugo output differs between archived vs active:
     - Archived page has `.baked-comments` but NO `.giscus`
     - Regular page has `.giscus` widget

### Reset Approach
- docker compose down -v (drops all volumes)
- Re-run seed scripts for fresh test data

### Definition of Done
- [x] WordPress "Archived" category auto-created on fresh setup (scripts/ensure-archived-category.rb)
- [x] seed-posts.rb creates test posts in WordPress
- [x] seed-discussions.rb creates sample discussions
- [x] Documentation (README + docs/testing.md)
- [ ] seed-discussions.rb creates sample discussions
- [ ] Archived post is skipped by fetch-posts.rb
- [ ] Archived post has no JSON from fetch-comments.rb
- [ ] Archived post has baked comments but NO Giscus in Hugo output
- [ ] Regular posts have Giscus in Hugo output

---

## Execution Strategy

### Tasks
1. ~~Add "Archived" category creation to WordPress setup~~ - Done: scripts/ensure-archived-category.rb created
2. ~~Create scripts/seed-posts.rb~~ - Done
3. ~~Create scripts/seed-discussions.rb (skip if env vars missing, inform user)~~ - Done
4. ~~Document testing workflow~~ - Done: README updated
5. ~~Create docs/testing.md with detailed testing instructions~~ - Done
3. Create scripts/seed-discussions.rb (skip if env vars missing, inform user)
4. Document testing workflow:
   - Update README.md with testing overview
   - Create docs/testing.md with detailed testing instructions

### Workflow
1. docker compose down -v (reset)
2. docker compose up -d wordpress (fresh WP with Archived category auto-created)
3. Run seed scripts
4. Run fetch scripts
5. Build Hugo
6. Verify archived vs active behavior

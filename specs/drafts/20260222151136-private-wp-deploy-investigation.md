# Draft: Deployment content generation note

## Requirements (confirmed)
- clarify in plan/docs that `hugo-site/content/` being gitignored does not block deployment
- document that CI regenerates content during workflow before Hugo build
- reassess architecture because user WordPress may be local/private and unreachable from GitHub-hosted Actions

## Technical Decisions
- source of truth for deployment behavior is `.github/workflows/deploy.yml`
- explanation should distinguish git tracking from runtime-generated CI artifacts
- if WordPress remains private-only, hosted Actions cannot fetch directly from `WP_API_URL`
- selected default architecture: local build + direct deploy (no hosted CI fetch from WordPress)
- remove current GitHub fetch/deploy workflow and update docs accordingly
- canonical deploy interface will be a single local script wrapper
- scope limited to production manual deploy (no preview flow)
- align image documentation to current implementation behavior

## Research Findings
- `.gitignore` includes `hugo-site/content/` (regenerated)
- deploy workflow runs `fetch-posts.rb`, `fetch-pages.rb`, `fetch-images.rb`, and `fetch-comments.rb` before `hugo --minify`
- deploy action uploads `hugo-site/public` to Cloudflare Pages
- `fetch-images.rb` currently converts to WebP and deletes originals; docs still mention AVIF/fallback (drift to resolve)
- image assets are generated under `hugo-site/static/images/` and included in `public/images/` at deploy
- Cloudflare Images free tier currently allows up to 5,000 unique transformations/month (official docs); storage in Cloudflare Images is paid-plan only
- GitHub Actions is free for public repos on standard runners; private repos use monthly minute quotas by plan

## Open Questions
- which plan file should receive this documentation task?
- what image behavior needs clarification in docs: deploy inclusion, optimization pipeline, or source-of-truth paths?
- stay with CI-generated local assets on Cloudflare Pages, or adopt Cloudflare Images as canonical image pipeline?
- if adopting Cloudflare Images, should we use transform-only (external storage) or full Images storage+delivery (paid)?
- which deployment architecture should be the default for private/local WordPress users?

## Interview Updates
- user requested to pause plan generation and clarify the image situation before proceeding
- user flagged core architecture risk: GitHub-hosted Actions likely cannot reach private/local WordPress
- user selected `Local build + direct deploy` as preferred architecture

## Scope Boundaries
- INCLUDE: plan update to add documentation task and acceptance criteria
- EXCLUDE: implementation/editing of docs right now

## Scope Boundaries (refined)
- INCLUDE: migration plan from hosted CI fetch to local direct deploy, script-wrapper deploy interface, docs updates, and verification commands
- EXCLUDE: preview deployment system, Cloudflare Images migration, sync-server redesign, and image pipeline feature additions

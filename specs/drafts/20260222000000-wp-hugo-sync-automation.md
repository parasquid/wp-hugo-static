# Draft: WordPress → Hugo Sync Automation (Webhook Edition)

## Requirements (from user)

### Core Goal
Automate WordPress → Hugo sync for local development with instant updates via webhooks.

### Current State
- `fetch-posts.rb` fetches ALL posts every time (slow with hundreds of posts)
- Manual step required after every post edit in WordPress
- Hugo's `-w` flag already watches Markdown files

### Proposed Solution
**Architecture: Shared Library + CLI + HTTP Server**

```
                    ┌─────────────────┐
                    │  WordPress      │
                    │  (webhook on    │
                    │   save_post)    │
                    └────────┬────────┘
                             │ HTTP POST
                             ▼
                    ┌─────────────────┐
                    │  sync-server    │ (HTTP server)
                    │  (WEBrick)     │
                    └────────┬────────┘
                             │ calls
                             ▼
                    ┌─────────────────┐
                    │    lib/sync    │ (shared library)
                    │  - fetch       │
                    │  - process      │
                    │  - detect del  │
                    └────────┬────────┘
                             │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
       posts/*.md      pages/*.md      .last-sync
```

### Components

**1. Shared Library (`lib/sync.rb`)**
- Functions: fetch_posts, fetch_pages, process_post
- State management: read/write .last-sync
- Deletion detection: compare WP IDs vs .md files
- Reusable by both CLI and server

**2. CLI Script (`scripts/sync.rb`)**
- Manual sync: `ruby scripts/sync.rb`
- Full sync: `ruby scripts/sync.rb --full`
- Uses lib/sync.rb

**3. HTTP Server (`scripts/sync-server.rb`)**
- WEBrick-based HTTP server
- Listens for POST /webhook from WordPress
- Calls lib/sync.rb on each webhook
- Runs as Docker service

**4. WordPress Plugin (`wp-content/plugins/sync-webhook/`)**
- Hooks: save_post, transition_post_status
- Sends HTTP POST to sync-server on changes
- Admin page: configure webhook URL
- Simple ~50 line PHP file

### Requirements
- Instant updates via webhooks (no polling)
- CLI fallback for manual/cron sync
- Shared library code between CLI and server
- Works with env vars: WP_API_URL, WP_USERNAME, WP_APPLICATION_PASSWORD
- Docker: sync-server as service

## Open Questions

- [x] State file location → hugo-site/.last-sync
- [x] Deletion handling → Yes - compare WP IDs vs .md filenames
- [x] Webhook approach → Yes - replace polling
- [x] Add tests? → Yes - RSpec

## Scope Boundaries
- IN: lib/sync.rb, scripts/sync.rb, scripts/sync-server.rb, WP plugin, docker-compose.yml
- OUT: Modifying fetch-posts.rb (keep as-is)
- OUT: Polling (replaced by webhooks)

---

## Important: When to Delete/Rewrite Plan Files

**ALWAYS ask before deleting or rewriting plan files.** Only do so with explicit permission.

**Good reasons to delete/rewrite:**
- User fundamentally changes the requirements (e.g., polling → webhooks)
- Architecture completely changes
- Scope expands/contracts significantly
- Original assumptions were wrong

**Do NOT delete/rewrite just because:**
- Minor details changed
- User answered more questions
- Some tasks added/removed
- Better understanding developed

In those cases, edit the existing file instead.

**This time:** User changed from polling to webhooks AND requested shared library architecture — this is a fundamental architecture change that required a complete rewrite, hence the deletion and rewrite was justified.

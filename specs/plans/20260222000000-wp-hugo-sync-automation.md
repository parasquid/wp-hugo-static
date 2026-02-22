# WordPress → Hugo Sync Automation (Webhook Edition)

## TL;DR

> **Quick Summary**: Automate WP→Hugo sync with shared library (`lib/sync.rb`) + CLI (`sync.rb`) + HTTP server (`sync-server.rb`) for instant webhook-based updates, plus a WordPress plugin to send webhooks.
> 
> **Deliverables**:
> - `lib/sync.rb` — Shared sync library (fetch, process, state management)
> - `scripts/sync.rb` — CLI script for manual/full sync
> - `scripts/sync-server.rb` — HTTP server for webhooks (WEBrick)
> - `wp-content/plugins/sync-webhook/` — WordPress plugin to send webhooks
> - `docker-compose.yml` — sync-server + hugo services
> - RSpec tests
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - multiple components can be built in parallel
> **Critical Path**: lib/sync → CLI/server → plugin → docker-compose → tests
> 
> **Usage**:
> ```bash
> docker compose up -d  # Starts WordPress, db, sync-server, and hugo automatically
> # Visit http://localhost:1313 for live Hugo preview
> # Edit a post in WordPress → instant update!
> ```

---

## Context

### Original Request
User wants to automate WordPress → Hugo sync for local development. Originally asked for polling, but prefers webhook approach for instant updates. Also wants to reorganize scripts with shared library code.

### Architecture: Shared Library + CLI + HTTP Server

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

### Key Decisions
- State file: `hugo-site/.last-sync` (JSON with last_sync timestamp)
- Deletion handling: Compare WP post IDs against .md filenames
- Webhook approach: Replace polling with instant HTTP POST from WordPress
- Docker: sync-server as service (auto-starts)
- Tests: RSpec following existing patterns

---

## Work Objectives

### Core Objective
Create a webhook-based sync system that updates Hugo instantly when WordPress posts change, with CLI fallback for manual operations.

### Concrete Deliverables
- `lib/sync.rb` — Shared sync library
- `scripts/sync.rb` — CLI script for manual sync
- `scripts/sync-server.rb` — HTTP server for webhooks
- `wp-content/plugins/sync-webhook/` — WordPress plugin
- `docker-compose.yml` — sync-server + hugo services
- RSpec tests

### Must Have
- Instant updates via webhooks (no polling)
- CLI fallback for manual/full sync
- Shared library code between CLI and server
- Deletion detection (deleted WP posts → deleted .md files)
- First-run full sync when .last-sync missing
- Hugo live preview server

### Must NOT Have (Guardrails)
- No modification to fetch-posts.rb (keep for manual full sync)
- No polling (replaced by webhooks)
- No external gems beyond WEBrick (Ruby stdlib)
- No structured logging (use puts like existing scripts)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (RSpec in scripts/)
- **Automated tests**: YES (tests-after)
- **Framework**: rspec + rspec-given
- **Test approach**: Unit tests for library, mock WP API

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation - can start immediately):
├── Task 1: lib/sync.rb — shared library
└── Task 2: WordPress plugin — webhook sender

Wave 2 (After Wave 1 - uses lib/sync):
├── Task 3: sync.rb CLI script (depends: 1)
├── Task 4: sync-server.rb HTTP server (depends: 1)
└── Task 5: sync-server tests (depends: 4)

Wave 3 (Integration):
├── Task 6: docker-compose.yml services (depends: 3, 4)
└── Task 7: Integration verification (depends: 5, 6)
```

---

## TODOs

- [ ] 1. Create lib/sync.rb — shared sync library

  **What to do**:
  - Create `lib/sync.rb` module
  - Functions: fetch_posts, fetch_pages, process_post, process_page
  - State management: read/write hugo-site/.last-sync
  - Deletion detection: fetch all WP post/page IDs, compare against .md filenames
  - Delete .md files for deleted WP posts/pages
  - Update .last-sync timestamp on successful completion
  - Error handling: don't update .last-sync if sync failed
  - Support --full flag for forced full sync

  **Must NOT do**:
  - No HTTP server code (belongs in sync-server.rb)
  - No CLI argument parsing (belongs in sync.rb)
  - No external gems

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core library with API integration
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 1)
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 3, 4
  - **Blocked By**: None

  **References**:
  - `scripts/fetch-posts.rb:76-103` - fetch_posts pattern
  - `scripts/fetch-pages.rb` - pages pattern

  **Acceptance Criteria**:
  - [ ] require_relative 'lib/sync' works
  - [ ] Sync.fetch_posts returns posts array
  - [ ] Sync.process_post writes .md file
  - [ ] .last-sync created/updated correctly

  **QA Scenarios**:
  
  Scenario: Library loads and provides functions
    Tool: Bash
    Preconditions: lib/sync.rb created
    Steps:
      1. ruby -Ilib -e "require 'sync'; puts Sync.methods - Object.methods"
    Expected Result: Methods listed (fetch_posts, process_post, etc.)
    Evidence: Output shows Sync module methods

  Scenario: Full sync creates .last-sync
    Tool: Bash
    Preconditions: No .last-sync exists
    Steps:
      1. ruby -Ilib scripts/sync.rb --full
      2. cat hugo-site/.last-sync
    Expected Result: Valid JSON with last_sync timestamp
    Evidence: File contains {"last_sync":"..."}

  ---

- [ ] 2. Create WordPress plugin — sync-webhook

  **What to do**:
  - Create directory: wp-content/plugins/sync-webhook/
  - Create main plugin file: sync-webhook.php (~50-80 lines)
  - Hooks:
    - save_post — fires when post is saved
    - transition_post_status — fires when status changes (publish, draft, etc.)
  - Send HTTP POST to configured webhook URL
  - Include post ID, post slug, action type (create/update/delete)
  - Admin settings page:
    - Text field for webhook URL
    - Optional secret token for security
    - "Test Webhook" button
  - Use wp_remote_post for HTTP (WordPress built-in)

  **Must NOT do**:
  - No complex database changes
  - No modifications to WordPress core
  - No external PHP libraries

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: WordPress plugin development
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 1)
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 7 (integration)
  - **Blocked By**: None

  **References**:
  - WordPress Plugin Handbook: https://developer.wordpress.org/plugins/
  - save_post hook: https://developer.wordpress.org/reference/hooks/save_post/
  - wp_remote_post: https://developer.wordpress.org/reference/functions/wp_remote_post/

  **Acceptance Criteria**:
  - [ ] Plugin appears in WordPress admin Plugins list
  - [ ] Settings page saves webhook URL
  - [ ] Webhook sent when post is saved

  **QA Scenarios**:
  
  Scenario: Plugin activates in WordPress
    Tool: Bash
    Preconditions: Plugin files created
    Steps:
      1. Activate plugin in WP Admin
      2. Check Plugins list
    Expected Result: "Sync Webhook" shows as active
    Evidence: Plugin status in WP Admin

  ---

- [ ] 3. Create scripts/sync.rb — CLI script

  **What to do**:
  - CLI script that uses lib/sync.rb
  - Arguments:
    - (none) — incremental sync since last sync
    - --full — force full sync
    - --post-id=N — sync single post by ID
  - Output: "Synced N posts, M pages" summary
  - Exit codes: 0 success, 1 error

  **Must NOT do**:
  - No HTTP server code
  - No duplication of lib/sync logic

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: CLI wrapper around library
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 6
  - **Blocked By**: Task 1

  **References**:
  - `lib/sync.rb` (Task 1)

  **Acceptance Criteria**:
  - [ ] ruby scripts/sync.rb works
  - [ ] ruby scripts/sync.rb --full works

  **QA Scenarios**:
  
  Scenario: CLI runs without errors
    Tool: Bash
    Preconditions: lib/sync.rb exists
    Steps:
      1. ruby scripts/sync.rb
    Expected Result: Completes without error
    Evidence: Exit code 0

  ---

- [ ] 4. Create scripts/sync-server.rb — HTTP server

  **What to do**:
  - WEBrick-based HTTP server (Ruby stdlib)
  - Listen on configurable port (default: 4567)
  - Endpoints:
    - GET /health — returns 200 OK (for Docker healthcheck)
    - POST /webhook — receives WordPress webhooks
  - On webhook received:
    - Parse payload (post_id, action, etc.)
    - Call Sync.sync_post(post_id) for single post
    - Or call Sync.sync_all for full sync
  - Support optional secret token verification
  - Log requests to stdout

  **Must NOT do**:
  - No external gems (use WEBrick from stdlib)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: HTTP server implementation
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 5, 6
  - **Blocked By**: Task 1

  **References**:
  - `lib/sync.rb` (Task 1)
  - WEBrick documentation

  **Acceptance Criteria**:
  - [ ] Server starts and listens on port
  - [ ] GET /health returns 200
  - [ ] POST /webhook triggers sync

  **QA Scenarios**:
  
  Scenario: Server starts and responds to health check
    Tool: Bash
    Preconditions: sync-server.rb created
    Steps:
      1. timeout 5 ruby scripts/sync-server.rb &
      2. sleep 2
      3. curl http://localhost:4567/health
    Expected Result: HTTP 200 response
    Evidence: curl output shows 200

  Scenario: Webhook triggers sync
    Tool: Bash
    Preconditions: Server running
    Steps:
      1. curl -X POST http://localhost:4567/webhook -d '{"post_id":1}'
    Expected Result: Sync triggered
    Evidence: Server logs show sync activity

  ---

- [ ] 5. Create tests for sync-server

  **What to do**:
  - Create spec/sync_server_spec.rb
  - Test health endpoint
  - Test webhook endpoint
  - Test secret token validation
  - Test error handling

  **Must NOT do**:
  - Integration tests with real WordPress

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Test file following patterns
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 7
  - **Blocked By**: Task 4

  **References**:
  - `scripts/spec/fetch_posts_spec.rb` - test patterns

  **Acceptance Criteria**:
  - [ ] bundle exec rspec spec/sync_server_spec.rb → PASS

  ---

- [ ] 6. Add sync-server and hugo to docker-compose.yml

  **What to do**:
  - Add 'sync-server' service:
    - Use builder image as base
    - Command: ruby scripts/sync-server.rb
    - ports: 4567:4567
    - depends_on: builder
    - restart: unless-stopped
  - Add 'hugo' service:
    - Use builder image as base
    - Command: hugo server -w --bind 0.0.0.0 --port 1313
    - depends_on: sync-server
    - ports: 1313:1313
    - restart: unless-stopped

  **Must NOT do**:
  - Modify existing services (wordpress, db)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Simple docker-compose addition
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 3, 4

  **References**:
  - `docker-compose.yml` - existing services

  **Acceptance Criteria**:
  - [ ] docker compose config valid
  - [ ] docker compose up -d sync-server starts
  - [ ] docker compose up -d hugo starts

  **QA Scenarios**:
  
  Scenario: Services start
    Tool: Bash
    Preconditions: docker-compose.yml updated
    Steps:
      1. docker compose config
      2. docker compose up -d sync-server hugo
      3. docker compose ps
    Expected Result: Both services show "Up"
    Evidence: docker compose ps output

  ---

- [ ] 7. Integration verification — full system test

  **What to do**:
  - Start all services (wordpress, db, sync-server, hugo)
  - Configure WordPress plugin with webhook URL
  - Create new post in WordPress admin
  - Verify webhook received by sync-server
  - Verify .md file created in hugo-site/
  - Verify Hugo rebuilt and shows new post
  - Edit existing post
  - Verify .md file updated
  - Delete post
  - Verify .md file deleted

  **Must NOT do**:
  - None - this is verification

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Full integration test
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final verification
  - **Blocks**: None
  - **Blocked By**: Tasks 5, 6

  **Acceptance Criteria**:
  - [ ] New WP post → .md created within seconds (webhook)
  - [ ] Edited WP post → .md updated
  - [ ] Deleted WP post → .md deleted
  - [ ] Hugo live preview shows changes

  **QA Scenarios**:
  
  Scenario: Full webhook workflow - create
    Tool: Bash
    Preconditions: All services running, plugin configured
    Steps:
      1. Create test post in WordPress admin
      2. Wait 5 seconds
      3. Check hugo-site/content/posts/ for new .md
    Expected Result: New .md file created
    Evidence: File exists

  Scenario: Full webhook workflow - update
    Tool: Bash
    Preconditions: Test post exists
    Steps:
      1. Edit post in WordPress admin
      2. Wait 5 seconds
      3. Check .md file timestamp updated
    Expected Result: .md file modified
    Evidence: Newer timestamp

  Scenario: Full webhook workflow - delete
    Tool: Bash
    Preconditions: Test post exists as .md
    Steps:
      1. Delete post in WordPress admin
      2. Wait 5 seconds
      3. Check hugo-site/content/posts/ - file gone
    Expected Result: .md file deleted
    Evidence: File no longer exists

---

- [ ] 8. Update AGENTS.md with plan file management and documentation guidance

  **What to do**:
  - Add section about when to delete/rewrite plan files:
    - ALWAYS ask before deleting or rewriting plan files
    - Good reasons: fundamental architecture changes, scope changes, wrong assumptions
    - NOT for: minor details, answered questions, task additions/removals
    - Ask permission and make a case for it
  - Add section about documentation:
    - Document as much as possible for both human use and agent use
    - Include usage examples, API references, architecture diagrams
    - Keep docs in docs/ directory
    - Update AGENTS.md when new patterns/conventions are established

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation update
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final documentation
  - **Blocks**: None
  - **Blocked By**: Task 7

  **References**:
  - `AGENTS.md` - existing project documentation
  - `docs/` - existing documentation

  **Acceptance Criteria**:
  - [ ] AGENTS.md updated with plan file management guidance
  - [ ] AGENTS.md updated with documentation guidance

---

- [ ] 9. Document the sync system

  **What to do**:
  - Create docs/sync-system.md with:
    - Architecture diagram
    - Component descriptions (lib/sync.rb, sync.rb, sync-server.rb, WP plugin)
    - Usage examples for CLI and webhook
    - Configuration options
    - Troubleshooting guide
  - Update docs/index.md if exists

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Technical documentation
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final documentation
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 2, 3, 4, 6

  **References**:
  - `docs/` - existing documentation structure

  **Acceptance Criteria**:
  - [ ] docs/sync-system.md created
  - [ ] Architecture and usage documented

---

## Final Verification Wave

- [ ] F1. **lib/sync.rb functional test** — Run sync, verify .last-sync
- [ ] F2. **sync-server.rb runs** — Server starts, webhook endpoint works
- [ ] F3. **WordPress plugin works** — Webhook sent on post save
- [ ] F4. **docker-compose.yml valid** — docker compose config passes
- [ ] F5. **All RSpec tests pass** — bundle exec rspec

---

## Commit Strategy

- **1**: `feat(scripts): add sync library and server` — lib/sync.rb, scripts/sync.rb, scripts/sync-server.rb
- **2**: `feat(plugin): add sync-webhook wordpress plugin` — wp-content/plugins/sync-webhook/
- **3**: `feat(docker): add sync-server and hugo services` — docker-compose.yml
- **4**: `test(scripts): add tests for sync components` — spec files

---

## Success Criteria

### Verification Commands
```bash
# Manual sync
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/sync.rb

# Full sync
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  builder ruby scripts/sync.rb --full

# Check state
cat hugo-site/.last-sync

# Test webhook manually
curl -X POST http://localhost:4567/webhook \
  -H "Content-Type: application/json" \
  -d '{"post_id": 1, "action": "update"}'

# Run tests
cd scripts && bundle exec rspec
```

### Final Checklist
- [ ] lib/sync.rb provides shared functionality
- [ ] CLI sync.rb works for manual sync
- [ ] HTTP sync-server receives webhooks
- [ ] WordPress plugin sends webhooks
- [ ] docker-compose.yml starts services automatically
- [ ] Hugo live preview at http://localhost:1313
- [ ] Instant updates when posts change (via webhook)
- [ ] All tests pass

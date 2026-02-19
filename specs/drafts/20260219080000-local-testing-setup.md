# Draft: Local Testing Setup

## Requirements (confirmed)
- **Core objective**: Enable local testing of baked comments feature
- **Reset approach**: Drop volumes (docker compose down -v) - fresh WordPress each time
- **GitHub seeding**: Script automates creating discussions via GitHub API

## Technical Decisions
- **Seed posts**: Ruby script using WordPress REST API
  - Uses WP_USERNAME + WP_APPLICATION_PASSWORD from .env
- **Seed discussions**: Ruby script using GitHub GraphQL API
  - Uses GITHUB_TOKEN, GITHUB_REPO from .env
  - Skip if GITHUB_TOKEN or GITHUB_REPO not available (inform user)
- **Test verification**: Run fetch scripts, build Hugo, check output differences
- **All config from .env** - Document required vars in .env.example

## Scope Boundaries
- INCLUDE: 
  - scripts/seed-posts.rb (create test posts in WordPress)
  - scripts/seed-discussions.rb (create test discussions in GitHub)
  - docs/testing.md (detailed testing instructions)
  - Update README.md with testing overview
- EXCLUDE:
  - CI/CD test automation (local dev only)
  - Unit tests

## Test Data Required
1. **WordPress Posts**:
   - 2 regular posts (for active comments)
   - 1 archived post (for archived behavior)
   
2. **GitHub Discussions**:
   - Discussions for regular posts only
   - Sample comments on each discussion
   - No discussions for archived posts

3. **WordPress Setup**:
   - "Archived" category auto-created on fresh setup (docker volume reset)

## Verification Checklist
- [ ] Regular posts have Giscus widget in Hugo output
- [ ] Archived posts have baked comments but NO Giscus
- [ ] fetch-posts.rb skips archived posts
- [ ] fetch-comments.rb skips archived posts

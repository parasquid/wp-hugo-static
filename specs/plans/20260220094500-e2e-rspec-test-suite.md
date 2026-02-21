# E2E RSpec Test Suite for wp-hugo-static

## TL;DR

> **Quick Summary**: Create a comprehensive RSpec test suite with rspec-given for end-to-end testing of the WordPress → Hugo static site pipeline, using Docker project namespacing for test isolation.
>
> **Deliverables**:
> - RSpec test infrastructure with rspec-given
> - Per-component specs (fetch_posts, fetch_images, hugo_build)
> - E2E integration spec for full pipeline
> - Test helper with Docker orchestration
> - Mock data fixtures for comments
> - Test runner script with cleanup
>
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Gemfile update → Test helper → Specs → Test runner

---

## Context

### Original Request
User wants to encode the end-to-end testing of the project into a test script, using RSpec with rspec-given, with comprehensive verification and test isolation from development environment.

### Interview Summary
**Key Discussions**:
- Script language: RSpec with rspec-given (structured testing, nice output)
- Comments testing: Mock baked comments (avoid GitHub API dependency)
- Test isolation: `COMPOSE_PROJECT_NAME=test-` namespace (no duplication)
- Test modes: Full integration + fetch-to-build (both for different use cases)
- RSpec structure: Per-component specs + e2e spec
- Cleanup: Full cleanup, idempotent, isolated from dev
- Verification: Comprehensive (files, frontmatter, archived flag, Hugo build)

**Technical Decisions**:
- Use existing scripts/Gemfile for dependencies
- Create spec/ directory under scripts/
- Mock comments via JSON fixture files
- Use environment variables for test configuration
- Support both CI (full) and local (fast) test modes

### Research Findings
- Existing Ruby scripts use net/http, json, fileutils, mini_magick, image_optim
- Docker Compose has builder, wordpress, db containers on wp-network
- Hugo output goes to hugo-site/public/
- Archived posts detected via WordPress category, get `archived: true` frontmatter
- Baked comments stored in hugo-site/data/comments/{slug}.json
- Images processed to WebP with optional watermark

---

## Work Objectives

### Core Objective
Create a comprehensive, maintainable test suite that validates the entire WordPress → Hugo pipeline with proper test isolation and both full integration and fast iterative modes.

### Concrete Deliverables
- `scripts/Gemfile` updated with rspec, rspec-given gems
- `scripts/spec/spec_helper.rb` - Test configuration and Docker orchestration
- `scripts/spec/support/docker_helper.rb` - Docker compose management with namespacing
- `scripts/spec/support/mock_data.rb` - Mock data generators
- `scripts/spec/fixtures/comments/*.json` - Mock comment fixtures
- `scripts/spec/fetch_posts_spec.rb` - Test fetch-posts.rb
- `scripts/spec/fetch_images_spec.rb` - Test fetch-images.rb
- `scripts/spec/hugo_build_spec.rb` - Test Hugo build output
- `scripts/spec/e2e_spec.rb` - Full pipeline integration test
- `scripts/bin/test` - Test runner script with cleanup

### Definition of Done
- [ ] `cd scripts && bundle exec rspec` runs all tests successfully
- [ ] Tests isolated from development environment (use test- namespace)
- [ ] Full integration test passes with clean WordPress instance
- [ ] Fast test mode works with pre-seeded WordPress
- [ ] Mock comments work without GITHUB_TOKEN
- [ ] Test runner provides clear pass/fail output

### Must Have
- RSpec with rspec-given for structured testing
- Project name namespacing for test isolation
- Per-component specs for fetch_posts, fetch_images, hugo_build
- E2E spec for full pipeline
- Mock baked comments (no GitHub API required)
- Comprehensive verification (files, frontmatter, archived flag, Hugo build)
- Idempotent tests (safe to run multiple times)

### Must NOT Have (Guardrails)
- Do NOT modify existing scripts/*.rb functionality
- Do NOT require real GITHUB_TOKEN for tests
- Do NOT run tests against development containers/volumes
- Do NOT commit test-generated content to git
- Do NOT add slow tests to default test run (use tags for slow tests)
- Do NOT duplicate docker-compose.yml configuration

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (creating new)
- **Automated tests**: YES (TDD approach - spec first)
- **Framework**: RSpec + rspec-given

### QA Policy
Every task includes agent-executed QA scenarios. Tests verify their own behavior by running RSpec.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation - sequential dependency):
├── Task 1: Update Gemfile with test dependencies [quick]
├── Task 2: Create spec directory structure [quick]
├── Task 3: Create spec_helper.rb with RSpec config [quick]
└── Task 4: Create Docker helper for test isolation [quick]

Wave 2 (Support utilities - parallel):
├── Task 5: Create mock data generators [quick]
├── Task 6: Create mock comment fixtures [quick]
├── Task 7: Create WordPress API mock helper [quick]
└── Task 8: Create Hugo output assertions helper [quick]

Wave 3 (Specs - parallel):
├── Task 9: Write fetch_posts_spec.rb [unspecified-high]
├── Task 10: Write fetch_images_spec.rb [unspecified-high]
├── Task 11: Write hugo_build_spec.rb [unspecified-high]
└── Task 12: Write e2e_spec.rb [deep]

Wave 4 (Runner and documentation):
├── Task 13: Create test runner script [quick]
├── Task 14: Add test documentation [writing]
└── Task 15: Verify full test suite runs [unspecified-high]
```

### Dependency Matrix
- **1**: — — 2, 3, 1
- **2**: 1 — 3, 4, 1
- **3**: 1, 2 — 5-12, 1
- **4**: 1, 2, 3 — 9-12, 1
- **5-8**: 3 — 9-12, 1
- **9-12**: 3, 4, 5-8 — 13, 14, 1
- **13**: 9-12 — 15, 1
- **14**: 9-12 — —
- **15**: 13 — —

### Agent Dispatch Summary
- **Wave 1**: 4 tasks → `quick` (Gemfile, directory, config, helper)
- **Wave 2**: 4 tasks → `quick` (mocks, fixtures, helpers)
- **Wave 3**: 4 tasks → `unspecified-high` x3, `deep` x1
- **Wave 4**: 3 tasks → `quick`, `writing`, `unspecified-high`

---

## TODOs

- [ ] 1. Update Gemfile with test dependencies

  **What to do**:
  - Add `rspec` and `rspec-given` gems to scripts/Gemfile
  - Add `simplecov` for test coverage (optional but recommended)
  - Run `bundle install` to install gems

  **Must NOT do**:
  - Do NOT remove or modify existing gem dependencies
  - Do NOT change Ruby version requirement

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple Gemfile modification, well-defined scope
  - **Skills**: []
    - No special skills needed for this task

  **Parallelization**:
  - **Can Run In Parallel**: NO (blocks other tasks)
  - **Parallel Group**: Wave 1 (sequential)
  - **Blocks**: Tasks 2-15
  - **Blocked By**: None

  **References**:
  - `scripts/Gemfile` - Current gem dependencies, add rspec here

  **Acceptance Criteria**:
  - [ ] scripts/Gemfile contains `gem 'rspec', '~> 3.12'`
  - [ ] scripts/Gemfile contains `gem 'rspec-given', '~> 0.2.0'`
  - [ ] `bundle install` succeeds in scripts/ directory

  **QA Scenarios**:
  ```
  Scenario: RSpec runs successfully
    Tool: Bash
    Preconditions: Fresh bundle install completed
    Steps:
      1. cd scripts && bundle exec rspec --version
    Expected Result: Outputs RSpec version (e.g., "3.12.x")
    Failure Indicators: "Could not find rspec" or command not found
    Evidence: .sisyphus/evidence/task-01-rspec-version.txt
  ```

  **Commit**: YES
  - Message: `test: add rspec and rspec-given to Gemfile`
  - Files: scripts/Gemfile, scripts/Gemfile.lock

- [ ] 2. Create spec directory structure

  **What to do**:
  - Create `scripts/spec/` directory
  - Create `scripts/spec/support/` for helper modules
  - Create `scripts/spec/fixtures/` for test data
  - Create `scripts/spec/fixtures/comments/` for mock comments
  - Create `.rspec` configuration file with defaults

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Directory creation, simple setup
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 1)
  - **Parallel Group**: Wave 1 (sequential after Task 1)
  - **Blocks**: Tasks 3-15
  - **Blocked By**: Task 1

  **References**:
  - Standard RSpec directory structure

  **Acceptance Criteria**:
  - [ ] `scripts/spec/` directory exists
  - [ ] `scripts/spec/support/` directory exists
  - [ ] `scripts/spec/fixtures/` directory exists
  - [ ] `scripts/spec/fixtures/comments/` directory exists
  - [ ] `.rspec` file exists with `--format documentation` and `--color`

  **QA Scenarios**:
  ```
  Scenario: Directory structure exists
    Tool: Bash
    Steps:
      1. ls -la scripts/spec/
      2. ls -la scripts/spec/support/
      3. ls -la scripts/spec/fixtures/
    Expected Result: All directories exist and are readable
    Evidence: .sisyphus/evidence/task-02-dirs.txt
  ```

  **Commit**: NO (groups with Task 4)

- [ ] 3. Create spec_helper.rb with RSpec configuration

  **What to do**:
  - Create `scripts/spec/spec_helper.rb`
  - Configure RSpec with rspec-given
  - Set up test environment variables
  - Configure simplecov if added
  - Require supporting files from support/

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Configuration file creation
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 2)
  - **Parallel Group**: Wave 1
  - **Blocks**: Tasks 5-15
  - **Blocked By**: Tasks 1-2

  **References**:
  - `scripts/Gemfile` - Gem versions to configure
  - rspec-given documentation for Given/Then syntax

  **Acceptance Criteria**:
  - [ ] `scripts/spec/spec_helper.rb` exists
  - [ ] Configures rspec-given with `require 'rspec/given'`
  - [ ] Sets default test environment variables
  - [ ] `bundle exec rspec` runs without errors (empty test suite)

  **QA Scenarios**:
  ```
  Scenario: Spec helper loads correctly
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec ruby -e "require_relative 'spec/spec_helper'"
    Expected Result: No errors, loads successfully
    Evidence: .sisyphus/evidence/task-03-spec-helper.txt
  ```

  **Commit**: NO (groups with Task 4)

- [ ] 4. Create Docker helper for test isolation

  **What to do**:
  - Create `scripts/spec/support/docker_helper.rb`
  - Implement `with_test_namespace` to set COMPOSE_PROJECT_NAME
  - Implement `start_test_containers` to bring up test environment
  - Implement `stop_test_containers` for cleanup
  - Implement `run_in_builder` to execute commands in builder container
  - Add test-specific volume handling

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Helper module with clear interface
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 3)
  - **Parallel Group**: Wave 1 (last in wave)
  - **Blocks**: Tasks 9-15
  - **Blocked By**: Tasks 1-3

  **References**:
  - `docker-compose.yml` - Container names, service definitions
  - `docs/local-dev-setup.md` - Docker command patterns
  - `AGENTS.md` - Docker command conventions (use `docker compose` not `docker exec`)

  **Acceptance Criteria**:
  - [ ] `scripts/spec/support/docker_helper.rb` exists
  - [ ] `with_test_namespace` method works correctly
  - [ ] `start_test_containers` brings up containers with test prefix
  - [ ] `stop_test_containers` removes test containers and volumes
  - [ ] `run_in_builder` executes commands in test builder container

  **QA Scenarios**:
  ```
  Scenario: Docker helper starts isolated containers
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec ruby -e "
          require_relative 'spec/support/docker_helper'
          include DockerHelper
          start_test_containers
          puts 'Containers started'
          stop_test_containers
          puts 'Containers stopped'
        "
    Expected Result: Containers start with test- prefix, then stop cleanly
    Evidence: .sisyphus/evidence/task-04-docker-helper.txt
  ```

  **Commit**: YES
  - Message: `test: add spec infrastructure and Docker helper`
  - Files: scripts/spec/spec_helper.rb, scripts/spec/support/docker_helper.rb, .rspec

- [ ] 5. Create mock data generators

  **What to do**:
  - Create `scripts/spec/support/mock_data.rb`
  - Implement `generate_mock_post` for WordPress post fixtures
  - Implement `generate_mock_comment` for comment fixtures
  - Implement `generate_mock_image_metadata` for image test data
  - Create deterministic test data with known values

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Utility module for test data generation
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6-8)
  - **Blocks**: Tasks 9-12
  - **Blocked By**: Task 3

  **References**:
  - `scripts/fetch-posts.rb` - Post structure and frontmatter format
  - `scripts/fetch-comments.rb` - Comment JSON structure
  - `hugo-site/content/posts/*.md` - Example post markdown files

  **Acceptance Criteria**:
  - [ ] `scripts/spec/support/mock_data.rb` exists
  - [ ] `generate_mock_post` creates valid post hash with title, content, slug, date
  - [ ] `generate_mock_comment` creates valid comment hash with author, body, createdAt
  - [ ] Data is deterministic (same input = same output)

  **QA Scenarios**:
  ```
  Scenario: Mock data generators work
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec ruby -e "
          require_relative 'spec/support/mock_data'
          post = MockData.generate_mock_post(title: 'Test', slug: 'test')
          puts post.inspect
        "
    Expected Result: Outputs hash with title: 'Test', slug: 'test'
    Evidence: .sisyphus/evidence/task-05-mock-data.txt
  ```

  **Commit**: NO (groups with Tasks 6-8)

- [ ] 6. Create mock comment fixtures

  **What to do**:
  - Create `scripts/spec/fixtures/comments/test-post-regular-1.json`
  - Create `scripts/spec/fixtures/comments/test-post-archived.json`
  - Include realistic comment data matching GitHub Discussions format
  - Include multiple comments per post for testing

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Static JSON fixture files
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 7-8)
  - **Blocks**: Tasks 9-12
  - **Blocked By**: Task 2

  **References**:
  - `scripts/fetch-comments.rb:144-155` - Comment structure format
  - `hugo-site/data/comments/` - Existing comment files (if any)

  **Acceptance Criteria**:
  - [ ] `scripts/spec/fixtures/comments/test-post-regular-1.json` exists
  - [ ] `scripts/spec/fixtures/comments/test-post-archived.json` exists
  - [ ] JSON is valid and matches expected structure
  - [ ] Each fixture has 2+ comments

  **QA Scenarios**:
  ```
  Scenario: Comment fixtures are valid JSON
    Tool: Bash
    Steps:
      1. cd scripts && ruby -rjson -e "
          JSON.parse(File.read('spec/fixtures/comments/test-post-regular-1.json'))
          puts 'Valid JSON'
        "
    Expected Result: Outputs "Valid JSON" without errors
    Evidence: .sisyphus/evidence/task-06-fixtures.txt
  ```

  **Commit**: NO (groups with Tasks 5, 7-8)

- [ ] 7. Create WordPress API mock helper

  **What to do**:
  - Create `scripts/spec/support/wp_api_mock.rb`
  - Implement methods to mock WordPress REST API responses
  - Support mocking posts, pages, categories, media endpoints
  - Allow tests to inject custom responses
  - Support both success and error responses

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Helper module for API mocking
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5-6, 8)
  - **Blocks**: Tasks 9-12
  - **Blocked By**: Task 3

  **References**:
  - `scripts/fetch-posts.rb` - API endpoint patterns
  - `scripts/seed-posts.rb:135-149` - API verification pattern
  - WordPress REST API documentation for response formats

  **Acceptance Criteria**:
  - [ ] `scripts/spec/support/wp_api_mock.rb` exists
  - [ ] Can mock GET /posts endpoint
  - [ ] Can mock GET /categories endpoint
  - [ ] Can mock error responses (404, 500)
  - [ ] Tests can inject custom mock data

  **QA Scenarios**:
  ```
  Scenario: WP API mock works
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec ruby -e "
          require_relative 'spec/support/wp_api_mock'
          mock = WpApiMock.new
          mock.stub_posts([{id: 1, title: {rendered: 'Test'}}])
          puts 'Mock configured'
        "
    Expected Result: Outputs "Mock configured" without errors
    Evidence: .sisyphus/evidence/task-07-wp-mock.txt
  ```

  **Commit**: NO (groups with Tasks 5-6, 8)

- [ ] 8. Create Hugo output assertions helper

  **What to do**:
  - Create `scripts/spec/support/hugo_assertions.rb`
  - Implement `assert_file_exists(path)` for output verification
  - Implement `assert_frontmatter(file, key, value)` for frontmatter checks
  - Implement `assert_archived_post(file)` for archived flag verification
  - Implement `assert_hugo_build_success(output_dir)` for build verification

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Test assertion helpers
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5-7)
  - **Blocks**: Tasks 9-12
  - **Blocked By**: Task 3

  **References**:
  - `scripts/fetch-posts.rb:94-109` - Frontmatter structure
  - `hugo-site/content/posts/*.md` - Example output files
  - `hugo-site/public/` - Expected build output location

  **Acceptance Criteria**:
  - [ ] `scripts/spec/support/hugo_assertions.rb` exists
  - [ ] `assert_file_exists` raises clear error if file missing
  - [ ] `assert_frontmatter` parses YAML frontmatter correctly
  - [ ] `assert_archived_post` checks for `archived: true`
  - [ ] `assert_hugo_build_success` verifies public/ directory exists

  **QA Scenarios**:
  ```
  Scenario: Hugo assertions work
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec ruby -e "
          require_relative 'spec/support/hugo_assertions'
          include HugoAssertions
          # Test with existing file
          assert_file_exists('Gemfile')
          puts 'Assertions work'
        "
    Expected Result: Outputs "Assertions work" without errors
    Evidence: .sisyphus/evidence/task-08-assertions.txt
  ```

  **Commit**: YES
  - Message: `test: add mock data and test helpers`
  - Files: scripts/spec/support/mock_data.rb, scripts/spec/fixtures/comments/*.json, scripts/spec/support/wp_api_mock.rb, scripts/spec/support/hugo_assertions.rb

- [ ] 9. Write fetch_posts_spec.rb

  **What to do**:
  - Create `scripts/spec/fetch_posts_spec.rb`
  - Test fetching posts from WordPress API
  - Test conversion to Hugo markdown format
  - Test archived category detection
  - Test frontmatter generation (title, date, slug, archived flag)
  - Test error handling (API errors, empty responses)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core component test, requires careful design
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 10-12)
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 3, 4, 5-8

  **References**:
  - `scripts/fetch-posts.rb` - Implementation to test
  - `scripts/spec/support/wp_api_mock.rb` - For mocking API
  - `scripts/spec/support/hugo_assertions.rb` - For verification
  - `hugo-site/content/posts/*.md` - Expected output format

  **Acceptance Criteria**:
  - [ ] `scripts/spec/fetch_posts_spec.rb` exists
  - [ ] Tests regular post fetching and conversion
  - [ ] Tests archived post detection (category check)
  - [ ] Tests frontmatter generation with correct fields
  - [ ] Tests error scenarios (API down, invalid response)
  - [ ] Uses rspec-given Given/When/Then structure

  **QA Scenarios**:
  ```
  Scenario: fetch_posts_spec runs
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec rspec spec/fetch_posts_spec.rb --format documentation
    Expected Result: All tests pass, output shows test names
    Evidence: .sisyphus/evidence/task-09-fetch-posts-spec.txt
  ```

  **Commit**: NO (groups with Tasks 10-12)

- [ ] 10. Write fetch_images_spec.rb

  **What to do**:
  - Create `scripts/spec/fetch_images_spec.rb`
  - Test image URL extraction from content
  - Test image downloading (mock HTTP)
  - Test image resizing logic
  - Test WebP conversion
  - Test watermark application (if applicable)
  - Test markdown path updates

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Image processing has multiple code paths
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 11-12)
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 3, 4, 5-8

  **References**:
  - `scripts/fetch-images.rb` - Implementation to test
  - `scripts/fetch-images.rb:25-33` - URL extraction patterns
  - `scripts/fetch-images.rb:51-73` - Resize logic
  - `scripts/fetch-images.rb:121-143` - WebP conversion

  **Acceptance Criteria**:
  - [ ] `scripts/spec/fetch_images_spec.rb` exists
  - [ ] Tests URL extraction from HTML and markdown
  - [ ] Tests skip conditions (SVG, animated GIF)
  - [ ] Tests image processing pipeline (mock ImageMagick)
  - [ ] Tests markdown file updates with new paths

  **QA Scenarios**:
  ```
  Scenario: fetch_images_spec runs
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec rspec spec/fetch_images_spec.rb --format documentation
    Expected Result: All tests pass
    Evidence: .sisyphus/evidence/task-10-fetch-images-spec.txt
  ```

  **Commit**: NO (groups with Tasks 9, 11-12)

- [ ] 11. Write hugo_build_spec.rb

  **What to do**:
  - Create `scripts/spec/hugo_build_spec.rb`
  - Test Hugo build command execution
  - Test output directory structure
  - Test post HTML generation
  - Test archived post handling (no Giscus widget)
  - Test baked comments inclusion

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Integration with Hugo build system
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9-10, 12)
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 3, 4, 5-8

  **References**:
  - `.github/workflows/deploy.yml:65-68` - Hugo build command
  - `hugo-site/public/` - Expected output structure
  - `hugo-site/hugo.toml` - Hugo configuration
  - `scripts/spec/fixtures/comments/` - Mock comments for baking

  **Acceptance Criteria**:
  - [ ] `scripts/spec/hugo_build_spec.rb` exists
  - [ ] Tests Hugo build succeeds
  - [ ] Tests output directory structure
  - [ ] Tests post HTML files exist
  - [ ] Tests archived posts have correct HTML structure

  **QA Scenarios**:
  ```
  Scenario: hugo_build_spec runs
    Tool: Bash
    Steps:
      1. cd scripts && bundle exec rspec spec/hugo_build_spec.rb --format documentation
    Expected Result: All tests pass
    Evidence: .sisyphus/evidence/task-11-hugo-build-spec.txt
  ```

  **Commit**: NO (groups with Tasks 9-10, 12)

- [ ] 12. Write e2e_spec.rb

  **What to do**:
  - Create `scripts/spec/e2e_spec.rb`
  - Test full pipeline: seed → fetch → build → verify
  - Use Docker helper for test isolation
  - Test with mock WordPress API or real local WordPress
  - Verify complete output: posts, images, comments
  - Include cleanup in after(:all) block

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex integration test requiring careful orchestration
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9-11)
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 3, 4, 5-8

  **References**:
  - `docs/testing.md` - Testing workflow
  - `scripts/spec/support/docker_helper.rb` - Container management
  - `scripts/seed-posts.rb` - Seeding logic
  - `scripts/fetch-posts.rb`, `scripts/fetch-images.rb`, `scripts/fetch-comments.rb` - Pipeline scripts

  **Acceptance Criteria**:
  - [ ] `scripts/spec/e2e_spec.rb` exists
  - [ ] Tests full pipeline from seed to build
  - [ ] Uses test namespace for isolation
  - [ ] Verifies output files exist and are correct
  - [ ] Cleans up after test run
  - [ ] Tagged as `:slow` for optional exclusion

  **QA Scenarios**:
  ```
  Scenario: e2e_spec runs with test isolation
    Tool: Bash
    Steps:
      1. COMPOSE_PROJECT_NAME=test- cd scripts && bundle exec rspec spec/e2e_spec.rb --tag slow --format documentation
    Expected Result: All tests pass, test-* containers created and removed
    Evidence: .sisyphus/evidence/task-12-e2e-spec.txt
  ```

  **Commit**: YES
  - Message: `test: add component and e2e specs`
  - Files: scripts/spec/fetch_posts_spec.rb, scripts/spec/fetch_images_spec.rb, scripts/spec/hugo_build_spec.rb, scripts/spec/e2e_spec.rb

- [ ] 13. Create test runner script

  **What to do**:
  - Create `scripts/bin/test` executable script
  - Support `--full` flag for complete integration test
  - Support `--fast` flag for component tests only (skip slow tests)
  - Set COMPOSE_PROJECT_NAME automatically
  - Handle cleanup on exit (trap signals)
  - Provide clear output with pass/fail summary

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Shell script with clear requirements
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on all specs)
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 9-12

  **References**:
  - `AGENTS.md` - Docker command patterns
  - `scripts/Gemfile` - For bundle exec commands

  **Acceptance Criteria**:
  - [ ] `scripts/bin/test` exists and is executable
  - [ ] `--full` runs all tests including slow e2e
  - [ ] `--fast` skips tests tagged with `:slow`
  - [ ] Sets `COMPOSE_PROJECT_NAME=test-` automatically
  - [ ] Cleans up containers on exit
  - [ ] Returns non-zero exit code on failure

  **QA Scenarios**:
  ```
  Scenario: Test runner executes fast tests
    Tool: Bash
    Steps:
      1. cd scripts && ./bin/test --fast
    Expected Result: Component tests run, e2e skipped, exit code 0
    Evidence: .sisyphus/evidence/task-13-test-runner.txt
  ```

  **Commit**: NO (groups with Tasks 14-15)

- [ ] 14. Add test documentation

  **What to do**:
  - Create `docs/testing-rspec.md` with usage instructions
  - Document test modes (full vs fast)
  - Document how to run individual specs
  - Document mock data and fixtures
  - Document test isolation approach
  - Update README.md to reference the new testing documentation

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation task
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 13, 15)
  - **Blocks**: None
  - **Blocked By**: Tasks 9-12

  **References**:
  - `docs/testing.md` - Existing testing documentation
  - `scripts/bin/test` - Test runner usage
  - `scripts/spec/` - Spec structure

  **Acceptance Criteria**:
  - [ ] `docs/testing-rspec.md` exists
  - [ ] Documents how to run tests
  - [ ] Documents test isolation
  - [ ] Documents mock data usage
  - [ ] README.md links to testing documentation

  **QA Scenarios**:
  ```
  Scenario: Documentation exists and is accurate
    Tool: Bash
    Steps:
      1. cat docs/testing-rspec.md | grep -c "bundle exec rspec"
    Expected Result: Count >= 1 (documentation contains RSpec commands)
    Evidence: .sisyphus/evidence/task-14-docs.txt
  ```

  **Commit**: NO (groups with Tasks 13, 15)

- [ ] 15. Verify full test suite runs

  **What to do**:
  - Run full test suite end-to-end
  - Verify all tests pass
  - Verify test isolation works
  - Verify cleanup happens correctly
  - Document any issues found and fix them

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Verification and debugging
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (final verification)
  - **Parallel Group**: Wave 4 (last task)
  - **Blocks**: None
  - **Blocked By**: Task 13

  **References**:
  - All previous tasks

  **Acceptance Criteria**:
  - [ ] `cd scripts && bundle exec rspec` passes all tests
  - [ ] Test isolation verified (no dev data affected)
  - [ ] Cleanup removes all test containers/volumes
  - [ ] Test coverage report generated (if simplecov)

  **QA Scenarios**:
  ```
  Scenario: Full test suite passes
    Tool: Bash
    Steps:
      1. cd scripts && COMPOSE_PROJECT_NAME=test- bundle exec rspec --format documentation
    Expected Result: All tests pass, summary shows X examples, 0 failures
    Evidence: .sisyphus/evidence/task-15-full-suite.txt
  ```

  **Commit**: YES
  - Message: `test: add test runner and documentation`
  - Files: scripts/bin/test, docs/testing-rspec.md, README.md

---

## Final Verification Wave (MANDATORY)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Verify all deliverables exist, Gemfile has rspec/rspec-given, spec directory created, all spec files present.

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `bundle exec rspec` — all tests pass. Check for proper RSpec conventions, no skipped tests without reason.

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start fresh test environment, run full test suite, verify isolated from dev, verify cleanup works.

- [ ] F4. **Scope Fidelity Check** — `deep`
  Verify no modification to existing scripts, proper test isolation, comprehensive coverage as requested.

---

## Commit Strategy

- **1**: `test: add rspec and rspec-given to Gemfile` — scripts/Gemfile, scripts/Gemfile.lock
- **2-4**: `test: add spec infrastructure and helpers` — scripts/spec/
- **5-8**: `test: add mock data and fixtures` — scripts/spec/support/, scripts/spec/fixtures/
- **9-12**: `test: add component and e2e specs` — scripts/spec/*_spec.rb
- **13-15**: `test: add test runner and documentation` — scripts/bin/test, docs/testing-rspec.md

---

## Success Criteria

### Verification Commands
```bash
# Run all tests
cd scripts && bundle exec rspec

# Run fast tests only (skip slow integration)
cd scripts && bundle exec rspec --tag ~slow

# Run with test namespace (isolated)
COMPOSE_PROJECT_NAME=test- scripts/bin/test

# Full integration test
scripts/bin/test --full
```

### Final Checklist
- [ ] All RSpec tests pass
- [ ] Test isolation works (COMPOSE_PROJECT_NAME)
- [ ] Mock comments work without GITHUB_TOKEN
- [ ] Full integration test passes
- [ ] Fast test mode works
- [ ] Cleanup removes all test data
- [ ] Documentation exists

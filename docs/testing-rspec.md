# RSpec Testing Guide

This document describes the RSpec test suite for wp-hugo-static.

## Prerequisites

The test suite runs inside the builder Docker container. Ensure Docker and Docker Compose are installed.

## Running Tests

### Quick Test (Component Tests Only)

Run fast unit tests without the slow E2E integration tests:

```bash
cd scripts
./bin/test --fast
```

Or directly with RSpec:

```bash
cd scripts
bundle exec rspec --tag ~slow
```

### Full Test Suite

Run all tests including the slow E2E integration tests:

```bash
cd scripts
./bin/test --full
```

Or directly with RSpec:

```bash
cd scripts
bundle exec rspec
```

### Running Individual Specs

```bash
cd scripts
bundle exec rspec spec/fetch_posts_spec.rb
bundle exec rspec spec/fetch_images_spec.rb
bundle exec rspec spec/hugo_build_spec.rb
bundle exec rspec spec/e2e_spec.rb
```

### Running with Docker Compose

```bash
docker compose run --rm -w /app/scripts builder bundle exec rspec --tag ~slow
```

## Test Architecture

### Directory Structure

```
scripts/spec/
├── spec_helper.rb           # RSpec configuration
├── support/
│   ├── docker_helper.rb     # Docker orchestration for test isolation
│   ├── mock_data.rb         # Test data generators
│   ├── wp_api_mock.rb       # WordPress API mock server
│   └── hugo_assertions.rb   # Custom assertions for Hugo output
├── fixtures/
│   └── comments/            # Mock comment JSON files
├── fetch_posts_spec.rb      # Tests for fetch-posts.rb
├── fetch_images_spec.rb     # Tests for fetch-images.rb
├── hugo_build_spec.rb       # Tests for Hugo build output
└── e2e_spec.rb              # Full pipeline integration tests
```

### Test Isolation

Tests use Docker Compose project namespacing (`COMPOSE_PROJECT_NAME=test-`) to isolate test containers and volumes from development environment.

The `DockerHelper` module provides:

- `start_test_containers` - Starts WordPress, MariaDB, and builder containers
- `stop_test_containers` - Removes containers and volumes
- `run_in_builder` - Executes commands in the test builder container

### Mock Data

The `MockData` module generates deterministic test data:

- `generate_mock_post` - WordPress post fixture
- `generate_archived_post` - Post with Archived category
- `generate_mock_comment` - Comment fixture
- `generate_mock_image_metadata` - Image metadata fixture

### Custom Assertions

The `HugoAssertions` module provides:

- `assert_file_exists(path)` - Verifies file exists
- `assert_frontmatter(file, key, value)` - Checks frontmatter field
- `assert_archived_post(file)` - Verifies `archived: true` in frontmatter
- `assert_hugo_build_success(output_dir)` - Verifies Hugo output structure
- `assert_post_html_exists(output_dir, slug)` - Verifies post HTML exists
- `assert_content_contains(filepath, text)` - Checks file content
- `assert_content_not_contains(filepath, text)` - Checks content absence

### rspec-given

Tests use `rspec-given` for structured BDD-style tests:

```ruby
describe 'feature' do
  Given(:input) { 'test' }
  When(:result) { process(input) }
  Then { result.should == 'expected' }
end
```

## Test Categories

### Component Tests (Fast)

- `fetch_posts_spec.rb` - WordPress API fetching, markdown conversion
- `fetch_images_spec.rb` - URL extraction, image processing logic
- `hugo_build_spec.rb` - Build output verification

### Integration Tests (Slow)

- `e2e_spec.rb` - Full pipeline: seed → fetch → build → verify

Tagged with `:slow`, excluded from default test run.

## Writing New Tests

1. Create spec file in `scripts/spec/`
2. Require spec_helper: `require_relative 'spec_helper'`
3. Include needed modules: `include HugoAssertions`
4. Use rspec-given syntax: `Given`, `When`, `Then`
5. Tag slow tests: `RSpec.describe 'Feature', :slow do`

## CI Integration

Tests run in GitHub Actions with:

```yaml
- name: Run tests
  run: |
    cd scripts
    bundle exec rspec --format documentation --tag ~slow
```

Full integration tests run on schedule or manual trigger.

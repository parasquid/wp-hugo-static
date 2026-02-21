# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'E2E Pipeline', :slow do
  include DockerHelper
  include HugoAssertions

  HUGO_SITE_PATH = File.expand_path('../../hugo-site', __dir__)
  POSTS_DIR = File.join(HUGO_SITE_PATH, 'content', 'posts')
  PUBLIC_DIR = File.join(HUGO_SITE_PATH, 'public')

  before(:all) do
    puts "\nStarting E2E pipeline test..."
    puts "This test uses isolated Docker containers (test- namespace)"
    start_test_containers
  end

  after(:all) do
    puts "\nCleaning up test containers..."
    stop_test_containers

    cleanup_hugo_content
  end

  describe 'WordPress seeding' do
    When(:result) { seed_test_posts }
    Then { expect(result).to be_success }
  end

  describe 'fetching posts from WordPress' do
    Given!(:posts_before) { count_markdown_files }

    When(:result) { fetch_posts }
    Then { expect(result).to be_success }

    And { expect(count_markdown_files).to be > posts_before }
    And { assert_file_exists(File.join(POSTS_DIR, 'test-post-regular-1.md')) }
    And { assert_file_exists(File.join(POSTS_DIR, 'test-post-regular-2.md')) }
    And { assert_file_exists(File.join(POSTS_DIR, 'test-post-archived.md')) }
  end

  describe 'markdown frontmatter for regular post' do
    Given(:regular_post) { File.join(POSTS_DIR, 'test-post-regular-1.md') }

    Then { assert_frontmatter(regular_post, 'title', 'Regular Post 1') }
    And { assert_frontmatter(regular_post, 'draft', false) }
    And { assert_not_archived_post(regular_post) }
  end

  describe 'markdown frontmatter for archived post' do
    Given(:archived_post) { File.join(POSTS_DIR, 'test-post-archived.md') }

    Then { assert_frontmatter(archived_post, 'title', 'Archived Post') }
    And { assert_archived_post(archived_post) }
  end

  describe 'Hugo build' do
    When(:result) { build_hugo }
    Then { expect(result).to be_success }
    And { assert_hugo_build_success(PUBLIC_DIR) }
  end

  describe 'Hugo output verification' do
    Then { assert_file_exists(File.join(PUBLIC_DIR, 'index.html')) }
    And { assert_post_html_exists(PUBLIC_DIR, 'test-post-regular-1') }
    And { assert_post_html_exists(PUBLIC_DIR, 'test-post-regular-2') }
    And { assert_post_html_exists(PUBLIC_DIR, 'test-post-archived') }
  end

  describe 'HTML content verification' do
    Given(:regular_html) { File.join(PUBLIC_DIR, 'posts', 'test-post-regular-1', 'index.html') }
    Given(:archived_html) { File.join(PUBLIC_DIR, 'posts', 'test-post-archived', 'index.html') }

    Then { assert_content_contains(regular_html, 'Regular Post 1') }
    And { assert_content_contains(archived_html, 'Archived Post') }
  end

  describe 'archived post HTML exists' do
    Given(:archived_html) { File.join(PUBLIC_DIR, 'posts', 'test-post-archived', 'index.html') }

    Then { assert_file_exists(archived_html) }
  end

  private

  def count_markdown_files
    return 0 unless Dir.exist?(POSTS_DIR)
    Dir.glob(File.join(POSTS_DIR, '*.md')).count
  end

  def cleanup_hugo_content
    FileUtils.rm_rf(File.join(POSTS_DIR, 'test-post-*.md'))
    FileUtils.rm_rf(PUBLIC_DIR)
  end
end

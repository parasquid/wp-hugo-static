# frozen_string_literal: true

require_relative 'spec_helper'
require 'securerandom'

RSpec.describe 'fetch-posts.rb' do
  include HugoAssertions

  let(:output_dir) { File.join(Dir.tmpdir, "hugo-posts-test-#{Process.pid}-#{SecureRandom.hex(4)}") }
  let(:mock_api) { WpApiMock.new }

  around do |example|
    keys = %w[POSTS_OUTPUT_DIR PAGES_OUTPUT_DIR STATE_FILE WP_API_URL]
    saved_env = keys.to_h { |key| [key, ENV[key]] }
    example.run
  ensure
    saved_env.each { |key, value| ENV[key] = value }
  end

  before do
    ENV['POSTS_OUTPUT_DIR'] = output_dir
    ENV['PAGES_OUTPUT_DIR'] = output_dir
    ENV['STATE_FILE'] = File.join(output_dir, '.last-sync')
    FileUtils.mkdir_p(output_dir)
  end

  after do
    mock_api.stop
    FileUtils.rm_rf(output_dir)
  end

  describe 'fetching posts from WordPress API' do
    Given(:posts) do
      [
        MockData.generate_mock_post,
        MockData.generate_mock_post('id' => 2, 'slug' => 'second-post', 'title' => { 'rendered' => 'Second Post' })
      ]
    end
    Given(:api_url) { mock_api.start }
    Given(:saved_wp_api_url) { ENV['WP_API_URL'] }

    before do
      mock_api.stub_posts(posts)
      ENV['WP_API_URL'] = api_url
    end

    after do
      ENV['WP_API_URL'] = saved_wp_api_url
    end

    When(:result) do
      require_relative '../../lib/sync'
      posts_returned = Sync.fetch_posts
      posts_returned.each { |post| Sync.process_post(post, archived: false) }
      posts_returned
    end

    Then { expect(result.length).to eq(2) }
    And { assert_file_exists(File.join(output_dir, 'test-post.md')) }
    And { assert_file_exists(File.join(output_dir, 'second-post.md')) }
  end

  describe 'archived post detection' do
    Given(:archived_category) { MockData.generate_mock_category }
    Given(:archived_post) { MockData.generate_archived_post }
    Given(:normal_post) { MockData.generate_mock_post('id' => 2, 'slug' => 'normal-post') }
    Given(:posts) { [archived_post, normal_post] }
    Given(:categories) { [archived_category] }
    Given(:api_url) { mock_api.start }
    Given(:saved_wp_api_url) { ENV['WP_API_URL'] }

    before do
      mock_api.stub_posts(posts)
      mock_api.stub_categories(categories)
      ENV['WP_API_URL'] = api_url
    end

    after do
      ENV['WP_API_URL'] = saved_wp_api_url
    end

    When do
      require_relative '../../lib/sync'
      posts_returned = Sync.fetch_posts
      posts_returned.each do |post|
        archived = Sync.post_archived?(post['id'])
        Sync.process_post(post, archived: archived)
      end
    end

    Then { assert_archived_post(File.join(output_dir, 'archived-post.md')) }
    And { assert_not_archived_post(File.join(output_dir, 'normal-post.md')) }
  end

  describe 'frontmatter generation' do
    Given(:post) do
      MockData.generate_mock_post(
        'date' => '2024-03-15T14:30:00',
        'slug' => 'my-awesome-post',
        'title' => { 'rendered' => 'My Awesome Post' },
        'categories' => [1, 2],
        'tags' => [3, 4, 5],
        'featured_media' => 123
      )
    end

    When(:frontmatter) do
      require_relative '../../lib/sync'
      Sync.create_post_frontmatter(post)
    end

    Then { expect(frontmatter['title']).to eq('My Awesome Post') }
    And { expect(frontmatter['slug']).to eq('my-awesome-post') }
    And { expect(frontmatter['draft']).to be false }
    And { expect(frontmatter['date']).to eq('2024-03-15T14:30:00Z') }
    And { expect(frontmatter['categories']).to eq([1, 2]) }
    And { expect(frontmatter['tags']).to eq([3, 4, 5]) }
    And { expect(frontmatter['featured_image']).to eq('/images/featured/my-awesome-post.jpg') }
  end

  describe 'frontmatter without optional fields' do
    Given(:post) do
      MockData.generate_mock_post(
        'categories' => [],
        'tags' => []
      ).tap { |p| p.delete('featured_media') }
    end

    When(:frontmatter) do
      require_relative '../../lib/sync'
      Sync.create_post_frontmatter(post)
    end

    Then { expect(frontmatter['title']).to eq('Test Post') }
    And { expect(frontmatter['slug']).to eq('test-post') }
    And { expect(frontmatter).not_to have_key('categories') }
    And { expect(frontmatter).not_to have_key('tags') }
    And { expect(frontmatter).not_to have_key('featured_image') }
  end

  describe 'HTML to Markdown conversion' do
    When(:markdown) do
      require_relative '../../lib/sync'
      Sync.html_to_markdown(html_input)
    end

    context 'with headings' do
      Given(:html_input) { '<h1>Main Title</h1><h2>Subtitle</h2><h3>Section</h3>' }

      Then { expect(markdown).to include('# Main Title') }
      And { expect(markdown).to include('## Subtitle') }
      And { expect(markdown).to include('### Section') }
    end

    context 'with paragraphs and links' do
      Given(:html_input) { '<p>This is a paragraph.</p><p><a href="https://example.com">Click here</a></p>' }

      Then { expect(markdown).to include('This is a paragraph.') }
      And { expect(markdown).to include('[Click here](https://example.com)') }
    end

    context 'with bold and italic' do
      Given(:html_input) { '<p><strong>bold text</strong> and <em>italic text</em></p>' }

      Then { expect(markdown).to include('**bold text**') }
      And { expect(markdown).to include('*italic text*') }
    end

    context 'with images' do
      Given(:html_input) { '<img src="https://example.com/image.jpg" alt="Example image">' }

      Then { expect(markdown).to include('![Example image](https://example.com/image.jpg)') }
    end

    context 'with nil input' do
      Given(:html_input) { nil }

      Then { expect(markdown).to eq('') }
    end

    context 'with empty string input' do
      Given(:html_input) { '' }

      Then { expect(markdown).to eq('') }
    end
  end

  describe 'filename cleaning' do
    # clean_filename was removed from lib/sync.rb - tests for this are now obsolete
    # Skipping this test block as the function no longer exists
  end

  describe 'error handling for API errors' do
    Given(:api_url) { 'http://localhost:9999/wp-json/wp/v2' }
    Given(:saved_wp_api_url) { ENV['WP_API_URL'] }

    before do
      ENV['WP_API_URL'] = api_url
    end

    after do
      ENV['WP_API_URL'] = saved_wp_api_url
    end

    When(:result) do
      require_relative '../../lib/sync'
      Sync.fetch_posts
    end

    Then { expect(result).to eq([]) }
  end

  describe 'processing post with archived flag' do
    Given(:post) { MockData.generate_mock_post('slug' => 'test-archived-flag') }

    When do
      require_relative '../../lib/sync'
      Sync.process_post(post, archived: true)
    end

    Then { assert_archived_post(File.join(output_dir, 'test-archived-flag.md')) }
  end

  describe 'processing post creates valid Hugo markdown file' do
    Given(:post) do
      MockData.generate_mock_post(
        'slug' => 'valid-markdown-test',
        'title' => { 'rendered' => 'Valid Markdown Test' },
        'content' => { 'rendered' => '<p>This is <strong>bold</strong> content.</p>' },
        'date' => '2024-06-20T09:00:00'
      )
    end

    When do
      require_relative '../../lib/sync'
      Sync.process_post(post, archived: false)
    end

    Given(:output_file) { File.join(output_dir, 'valid-markdown-test.md') }

    Then { assert_file_exists(output_file) }
    And { assert_frontmatter(output_file, 'title', 'Valid Markdown Test') }
    And { assert_frontmatter(output_file, 'slug', 'valid-markdown-test') }
    And { assert_frontmatter(output_file, 'draft', false) }
    And { assert_content_contains(output_file, '---') }
    And { assert_content_contains(output_file, '**bold**') }
  end

  describe 'empty response handling' do
    Given(:posts) { [] }
    Given(:api_url) { mock_api.start }
    Given(:saved_wp_api_url) { ENV['WP_API_URL'] }

    before do
      mock_api.stub_posts(posts)
      ENV['WP_API_URL'] = api_url
    end

    after do
      ENV['WP_API_URL'] = saved_wp_api_url
    end

    When(:result) do
      require_relative '../../lib/sync'
      Sync.fetch_posts
    end

    Then { expect(result).to eq([]) }
  end

  describe 'post_archived? with archived category' do
    Given(:archived_category) { MockData.generate_mock_category }
    Given(:archived_post) { MockData.generate_archived_post }
    Given(:categories) { [archived_category] }
    Given(:api_url) { mock_api.start }
    Given(:saved_wp_api_url) { ENV['WP_API_URL'] }

    before do
      mock_api.stub_posts([archived_post])
      mock_api.stub_categories(categories)
      ENV['WP_API_URL'] = api_url
    end

    after do
      ENV['WP_API_URL'] = saved_wp_api_url
    end

    When(:is_archived) do
      require_relative '../../lib/sync'
      Sync.post_archived?(archived_post['id'])
    end

    Then { expect(is_archived).to be true }
  end

  describe 'post_archived? without archived category' do
    Given(:normal_post) { MockData.generate_mock_post('categories' => [1]) }
    Given(:normal_category) { MockData.generate_mock_category('id' => 1, 'name' => 'News') }
    Given(:categories) { [normal_category] }
    Given(:api_url) { mock_api.start }
    Given(:saved_wp_api_url) { ENV['WP_API_URL'] }

    before do
      mock_api.stub_posts([normal_post])
      mock_api.stub_categories(categories)
      ENV['WP_API_URL'] = api_url
    end

    after do
      ENV['WP_API_URL'] = saved_wp_api_url
    end

    When(:is_archived) do
      require_relative '../../lib/sync'
      Sync.post_archived?(normal_post['id'])
    end

    Then { expect(is_archived).to be false }
  end
end

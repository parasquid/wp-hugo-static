# frozen_string_literal: true

require_relative 'spec_helper'
require 'securerandom'

RSpec.describe 'lib/sync.rb' do
  include HugoAssertions

  let(:output_dir) { File.join(Dir.tmpdir, "hugo-sync-test-#{Process.pid}-#{SecureRandom.hex(4)}") }
  let(:mock_api) { WpApiMock.new }

  around do |example|
    keys = %w[POSTS_OUTPUT_DIR PAGES_OUTPUT_DIR STATE_FILE WP_API_URL SYNC_SERVER_PORT SYNC_WEBHOOK_SECRET]
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

  describe 'Sync module loading' do
    When do
      require_relative '../../lib/sync'
    end

    Then { expect(Sync).to be_a(Module) }
    And { expect(Sync::Config).to be_a(Class) }
  end

  describe 'State file management' do
    Given(:saved_state_file) { ENV['STATE_FILE'] }
    Given(:state_file) { File.join(output_dir, '.last-sync') }

    after do
      ENV['STATE_FILE'] = saved_state_file
    end

    describe 'write_last_sync and read_last_sync' do
      When do
        require_relative '../../lib/sync'
        Sync.write_last_sync('2024-01-15T10:00:00Z')
      end

      Then { expect(File.exist?(state_file)).to be true }
      And { expect(Sync.read_last_sync).to eq('2024-01-15T10:00:00Z') }
    end

    describe 'read_last_sync with non-existent file' do
      When do
        require_relative '../../lib/sync'
      end

      Then { expect(Sync.read_last_sync).to be_nil }
    end

    describe 'read_last_sync with invalid JSON' do
      When do
        require_relative '../../lib/sync'
        File.write(state_file, 'not valid json')
      end

      Then { expect(Sync.read_last_sync).to be_nil }
    end
  end

  describe 'fetch_posts' do
    Given(:posts) do
      [
        MockData.generate_mock_post,
        MockData.generate_mock_post('id' => 2, 'slug' => 'another-post', 'title' => { 'rendered' => 'Another Post' })
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
      Sync.fetch_posts
    end

    Then { expect(result.length).to eq(2) }
    And { expect(result.first['slug']).to eq('test-post') }
    And { expect(result.last['slug']).to eq('another-post') }
  end

  describe 'fetch_posts with since filter' do
    Given(:posts) { [MockData.generate_mock_post] }
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
      Sync.fetch_posts(since: '2024-01-01T00:00:00Z')
    end

    Then { expect(result.length).to eq(1) }
  end

  describe 'fetch_pages' do
    Given(:pages) do
      [
        { 'id' => 10, 'slug' => 'page-one', 'title' => { 'rendered' => 'Page One' },
          'content' => { 'rendered' => '<p>One</p>' }, 'date' => '2024-01-15T10:00:00', 'status' => 'publish', 'parent' => 0 },
        { 'id' => 11, 'slug' => 'page-two', 'title' => { 'rendered' => 'Page Two' },
          'content' => { 'rendered' => '<p>Two</p>' }, 'date' => '2024-01-16T10:00:00', 'status' => 'publish', 'parent' => 0 }
      ]
    end
    Given(:api_url) { mock_api.start }

    before do
      mock_api.stub_pages(pages)
      ENV['WP_API_URL'] = api_url
    end

    When(:result) do
      require_relative '../../lib/sync'
      Sync.fetch_pages
    end

    Then { expect(result.length).to eq(2) }
    And { expect(result.map { |page| page['slug'] }).to contain_exactly('page-one', 'page-two') }
  end

  describe 'process_post' do
    Given(:post) { MockData.generate_mock_post('slug' => 'process-test-post') }

    When do
      require_relative '../../lib/sync'
      Sync.process_post(post, archived: false)
    end

    Then { assert_file_exists(File.join(output_dir, 'process-test-post.md')) }
    And { assert_frontmatter(File.join(output_dir, 'process-test-post.md'), 'title', 'Test Post') }
    And { assert_frontmatter(File.join(output_dir, 'process-test-post.md'), 'slug', 'process-test-post') }
  end

  describe 'process_post with archived flag' do
    Given(:post) { MockData.generate_mock_post('slug' => 'archived-test-post') }

    When do
      require_relative '../../lib/sync'
      Sync.process_post(post, archived: true)
    end

    Then { assert_archived_post(File.join(output_dir, 'archived-test-post.md')) }
  end

  describe 'process_page' do
    Given(:page) do
      { 'id' => 1, 'slug' => 'test-page', 'title' => { 'rendered' => 'Test Page' },
        'content' => { 'rendered' => '<p>Page content</p>' }, 'date' => '2024-01-15T10:00:00', 'status' => 'publish', 'parent' => 0 }
    end

    When do
      require_relative '../../lib/sync'
      Sync.process_page(page)
    end

    Then { assert_file_exists(File.join(output_dir, 'test-page.md')) }
    And { assert_frontmatter(File.join(output_dir, 'test-page.md'), 'title', 'Test Page') }
  end

  # describe 'existing_post_slugs' do
  # end

  # describe 'existing_page_slugs' do
  # end

  describe 'delete_post' do
    Given(:post_file) { File.join(output_dir, 'to-delete.md') }

    When do
      require_relative '../../lib/sync'
      File.write(post_file, "---\ntitle: To Delete\n---\n")
      Sync.delete_post('to-delete')
    end

    Then { expect(File.exist?(post_file)).to be false }
  end

  describe 'delete_post when file does not exist' do
    When(:result) do
      require_relative '../../lib/sync'
      Sync.delete_post('non-existent')
    end

    Then { expect(result).to be false }
  end

  describe 'html_to_markdown conversion' do
    When(:markdown) do
      require_relative '../../lib/sync'
      Sync.html_to_markdown(html_input)
    end

    context 'with basic HTML' do
      Given(:html_input) { '<h1>Title</h1><p>Paragraph with <strong>bold</strong> text.</p>' }

      Then { expect(markdown).to include('# Title') }
      And { expect(markdown).to include('**bold**') }
    end

    context 'with nil input' do
      Given(:html_input) { nil }

      Then { expect(markdown).to eq('') }
    end

    context 'with empty string' do
      Given(:html_input) { '' }

      Then { expect(markdown).to eq('') }
    end

    context 'with image and alt text' do
      Given(:html_input) { '<img src="https://example.com/image.jpg" alt="My Image">' }

      Then { expect(markdown).to include('![My Image](https://example.com/image.jpg)') }
    end
  end

  describe 'post_archived?' do
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

  describe 'post_archived? returns false for non-archived' do
    Given(:normal_post) { MockData.generate_mock_post('categories' => [1]) }
    Given(:categories) { [{ 'id' => 1, 'name' => 'News' }] }
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

  describe 'sync_post' do
    Given(:post) { MockData.generate_mock_post('id' => 42, 'slug' => 'sync-post-test', 'categories' => []) }
    Given(:api_url) { mock_api.start }

    before do
      mock_api.stub_posts([post])
      ENV['WP_API_URL'] = api_url
    end

    When(:result) do
      require_relative '../../lib/sync'
      Sync.sync_post(post['id'])
    end

    Then { expect(result).to eq(1) }
    And { assert_file_exists(File.join(output_dir, 'sync-post-test.md')) }
  end

  describe 'Config defaults' do
    it 'uses default WP_API_URL when ENV is not set' do
      ENV.delete('WP_API_URL')
      ENV.delete('POSTS_OUTPUT_DIR')
      ENV.delete('PAGES_OUTPUT_DIR')
      ENV.delete('STATE_FILE')
      require_relative '../../lib/sync'

      expect(Sync::Config.wp_api_url).to eq('https://your-domain.com/wp-json/wp/v2')
      expect(Sync::Config.posts_output_dir).to eq('hugo-site/content/posts')
      expect(Sync::Config.pages_output_dir).to eq('hugo-site/content/pages')
      expect(Sync::Config.state_file).to eq('hugo-site/.last-sync')
    end
  end
end

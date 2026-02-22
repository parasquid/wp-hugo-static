# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'E2E Pipeline', :slow do
  include DockerHelper
  include HugoAssertions

  HUGO_SITE_PATH = File.expand_path('../../hugo-site', __dir__)
  POSTS_DIR = File.join(HUGO_SITE_PATH, 'content', 'posts')
  PUBLIC_DIR = File.join(HUGO_SITE_PATH, 'public')

  describe 'fetching posts from WordPress' do
    Given!(:posts_before) { count_markdown_files }

    When(:result) { fetch_posts }
    Then { expect(result.success?).to be true }

    And { expect(count_markdown_files).to be > posts_before }
  end

  describe 'Hugo build' do
    When(:result) { build_hugo }
    Then { expect(result.success?).to be true }
  end

  private

  def count_markdown_files
    return 0 unless Dir.exist?(POSTS_DIR)
    Dir.glob(File.join(POSTS_DIR, '*.md')).count
  end
end

# frozen_string_literal: true

module MockData
  def self.generate_mock_post(overrides = {})
    {
      'id' => 1,
      'date' => '2024-01-15T10:30:00',
      'slug' => 'test-post',
      'status' => 'publish',
      'title' => { 'rendered' => 'Test Post' },
      'content' => { 'rendered' => '<p>This is test content.</p>' },
      'excerpt' => { 'rendered' => 'Test excerpt' },
      'categories' => [],
      'tags' => [],
      'featured_media' => 0
    }.merge(overrides)
  end

  def self.generate_archived_post(overrides = {})
    generate_mock_post(overrides.merge(
      'slug' => 'archived-post',
      'title' => { 'rendered' => 'Archived Post' },
      'categories' => [999]
    ))
  end

  def self.generate_mock_category(overrides = {})
    {
      'id' => 999,
      'name' => 'Archived',
      'slug' => 'archived'
    }.merge(overrides)
  end

  def self.generate_mock_comment(overrides = {})
    {
      'author' => 'testuser',
      'body' => 'This is a test comment.',
      'createdAt' => '2024-01-15T12:00:00Z',
      'url' => 'https://github.com/test/repo/discussions/1#discussioncomment-1'
    }.merge(overrides)
  end

  def self.generate_mock_comments(count: 2, post_slug: 'test-post')
    (1..count).map do |i|
      generate_mock_comment(
        'author' => "user#{i}",
        'body' => "Comment #{i} for #{post_slug}",
        'createdAt' => "2024-01-15T12:0#{i}:00Z"
      )
    end
  end

  def self.generate_mock_image_metadata(overrides = {})
    {
      'id' => 1,
      'source_url' => 'http://test-wordpress/wp-content/uploads/2024/01/test-image.jpg',
      'media_type' => 'image',
      'mime_type' => 'image/jpeg',
      'title' => { 'rendered' => 'Test Image' },
      'alt_text' => 'Test image alt text'
    }.merge(overrides)
  end

  def self.generate_expected_frontmatter(post)
    fm = {
      'title' => post.dig('title', 'rendered'),
      'date' => post['date'],
      'draft' => false,
      'slug' => post['slug']
    }
    fm['categories'] = post['categories'] if post['categories']&.any?
    fm['tags'] = post['tags'] if post['tags']&.any?
    fm
  end
end

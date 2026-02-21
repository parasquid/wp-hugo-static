# frozen_string_literal: true

require 'yaml'

module HugoAssertions
  def assert_file_exists(path)
    expect(File).to exist(path), "Expected file to exist: #{path}"
  end

  def assert_file_not_exists(path)
    expect(File).not_to exist(path), "Expected file NOT to exist: #{path}"
  end

  def assert_frontmatter(file_path, key, expected_value)
    assert_file_exists(file_path)
    content = File.read(file_path)
    frontmatter = parse_frontmatter(content)
    expect(frontmatter[key]).to eq(expected_value),
                                "Expected frontmatter[#{key}] to be #{expected_value.inspect}, got #{frontmatter[key].inspect}"
  end

  def assert_archived_post(file_path)
    assert_frontmatter(file_path, 'archived', true)
  end

  def assert_not_archived_post(file_path)
    content = File.read(file_path)
    frontmatter = parse_frontmatter(content)
    expect(frontmatter['archived']).to be_nil.or be_falsey
  end

  def assert_hugo_build_success(output_dir)
    assert_file_exists(output_dir)
    assert_file_exists(File.join(output_dir, 'index.html'))
    assert_file_exists(File.join(output_dir, 'posts'))
  end

  def assert_post_html_exists(output_dir, slug)
    post_dir = File.join(output_dir, 'posts', slug)
    assert_file_exists(post_dir)
    assert_file_exists(File.join(post_dir, 'index.html'))
  end

  def assert_content_contains(filepath, text)
    assert_file_exists(filepath)
    content = File.read(filepath)
    expect(content).to include(text), "Expected #{filepath} to contain #{text.inspect}"
  end

  def assert_content_not_contains(filepath, text)
    assert_file_exists(filepath)
    content = File.read(filepath)
    expect(content).not_to include(text), "Expected #{filepath} NOT to contain #{text.inspect}"
  end

  def parse_frontmatter(content)
    match = content.match(/^---\n(.*?)\n---/m)
    return {} unless match

    YAML.safe_load(match[1], permitted_classes: [Date, Time])
  end

  def get_frontmatter(file_path)
    content = File.read(file_path)
    parse_frontmatter(content)
  end
end

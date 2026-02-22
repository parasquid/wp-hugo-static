#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'fileutils'
require 'date'

# Sync module - shared library for WordPress to Hugo sync
module Sync
  # Configuration
  class Config
    def self.wp_api_url
      ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
    end

    def self.posts_output_dir
      ENV.fetch('POSTS_OUTPUT_DIR', 'hugo-site/content/posts')
    end

    def self.pages_output_dir
      ENV.fetch('PAGES_OUTPUT_DIR', 'hugo-site/content/pages')
    end

    def self.state_file
      ENV.fetch('STATE_FILE', 'hugo-site/.last-sync')
    end
  end

  # Read last sync timestamp from state file
  def self.read_last_sync
    state_file = Config.state_file
    return nil unless File.exist?(state_file)

    begin
      data = JSON.parse(File.read(state_file))
      data['last_sync']
    rescue JSON::ParserError, StandardError
      nil
    end
  end

  # Write last sync timestamp to state file
  def self.write_last_sync(timestamp)
    state_file = Config.state_file
    FileUtils.mkdir_p(File.dirname(state_file))

    data = if File.exist?(state_file)
             begin
               JSON.parse(File.read(state_file))
             rescue JSON::ParserError
               {}
             end
           else
             {}
           end

    data['last_sync'] = timestamp

    File.write(state_file, JSON.pretty_generate(data))
  end

  # Fetch all posts from WordPress, optionally filtered by modified date
  def self.fetch_posts(since: nil)
    posts = []
    page = 1

    loop do
      uri = URI("#{Config.wp_api_url}/posts?page=#{page}&per_page=100&status=publish")
      uri.query = [uri.query, "after=#{since}"].compact.join('&') if since

      begin
        response = Net::HTTP.get_response(uri)
      rescue StandardError => e
        puts "Error connecting to WordPress API: #{e.message}"
        break
      end

      if response.is_a?(Net::HTTPSuccess)
        batch = JSON.parse(response.body)
        break if batch.empty?
        posts.concat(batch)
        page += 1
        break if page > 10
      else
        puts "Error fetching posts: #{response.code}"
        break
      end
    end

    posts
  end

  # Fetch all pages from WordPress, optionally filtered by modified date
  def self.fetch_pages(since: nil)
    pages = []
    page = 1

    loop do
      uri = URI("#{Config.wp_api_url}/pages?page=#{page}&per_page=100&status=publish")
      uri.query = [uri.query, "after=#{since}"].compact.join('&') if since

      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        batch = JSON.parse(response.body)
        break if batch.empty?
        pages.concat(batch)
        page += 1
        break if page > 10
      else
        puts "Error fetching pages: #{response.code}"
        break
      end
    end

    pages
  end

  # Fetch post categories for a given post ID
  def self.fetch_post_categories(post_id)
    uri = URI("#{Config.wp_api_url}/posts/#{post_id}?_fields=categories")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data['categories'] || []
    else
      []
    end
  end

  # Fetch category name by ID
  def self.fetch_category_name(category_id)
    return nil if category_id.nil? || category_id == 0

    uri = URI("#{Config.wp_api_url}/categories/#{category_id}?_fields=name")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data['name']
    else
      nil
    end
  end

  # Check if post is archived
  def self.post_archived?(post_id)
    categories = fetch_post_categories(post_id)
    return false if categories.empty?

    categories.each do |cat_id|
      name = fetch_category_name(cat_id)
      return true if name && name.downcase == 'archived'
    end

    false
  end

  # Convert HTML to Markdown
  def self.html_to_markdown(html)
    return '' if html.nil? || html.empty?

    md = html.gsub(/<img[^>]+src=["']([^"']+)["'][^>]*alt=["']([^"']*)["'][^>]*>/, '![\2](\1)')
             .gsub(/<img[^>]+src=["']([^"']+)["'][^>]*>/, '![](\1)')
             .gsub(/<h1>(.*?)<\/h1>/, "# \\1\n\n")
             .gsub(/<h2>(.*?)<\/h2>/, "## \\1\n\n")
             .gsub(/<h3>(.*?)<\/h3>/, "### \\1\n\n")
             .gsub(/<p>(.*?)<\/p>/m, "\\1\n\n")
             .gsub(/<a href="(.*?)">(.*?)<\/a>/, '[\2](\1)')
             .gsub(/<(strong|b)>(.*?)<\/(strong|b)>/, '**\2**')
             .gsub(/<(em|i)>(.*?)<\/(em|i)>/, '*\2*')
             .gsub(/<br\s*\/?>/, "\n")
             .gsub(/<[^>]+>/, '')

    md.gsub(/\n{3,}/, "\n\n").strip
  end

  # Create frontmatter hash for a post
  def self.create_post_frontmatter(post)
    date = DateTime.parse(post['date'])

    fm = {
      'title' => post.dig('title', 'rendered'),
      'date' => date.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'draft' => false,
      'slug' => post['slug']
    }

    fm['categories'] = post['categories'] if post['categories'] && !post['categories'].empty?
    fm['tags'] = post['tags'] if post['tags'] && !post['tags'].empty?
    fm['featured_image'] = "/images/featured/#{post['slug']}.jpg" if post['featured_media']

    fm
  end

  # Create frontmatter hash for a page
  def self.create_page_frontmatter(page)
    date = DateTime.parse(page['date'])

    fm = {
      'title' => page.dig('title', 'rendered'),
      'date' => date.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'draft' => false,
      'slug' => page['slug']
    }

    fm['parent'] = page['parent'] if page['parent']
    fm['type'] = page['template'] if page['template']

    fm
  end

  # Write frontmatter and content to file
  def self.write_file(filepath, frontmatter, content)
    FileUtils.mkdir_p(File.dirname(filepath))

    File.open(filepath, 'w:UTF-8') do |f|
      f.puts '---'
      frontmatter.each do |key, value|
        if value.is_a?(Array)
          f.puts "#{key}:"
          value.each { |item| f.puts "  - #{item}" }
        else
          f.puts "#{key}: #{value.inspect}"
        end
      end
      f.puts '---'
      f.puts
      f.puts content
    end
  end

  # Process a single post
  def self.process_post(post, archived: false)
    frontmatter = create_post_frontmatter(post)
    content_html = post.dig('content', 'rendered')
    content_md = html_to_markdown(content_html)

    frontmatter['archived'] = true if archived

    filepath = File.join(Config.posts_output_dir, "#{post['slug']}.md")
    write_file(filepath, frontmatter, content_md)

    puts "Created/updated: #{filepath}"
    filepath
  end

  # Process a single page
  def self.process_page(page)
    frontmatter = create_page_frontmatter(page)
    content_md = html_to_markdown(page.dig('content', 'rendered'))

    filepath = File.join(Config.pages_output_dir, "#{page['slug']}.md")
    write_file(filepath, frontmatter, content_md)

    puts "Created/updated: #{filepath}"
    filepath
  end

  # Get all existing post slugs from Hugo content directory
  def self.existing_post_slugs
    posts_dir = Config.posts_output_dir
    return [] unless Dir.exist?(posts_dir)

    Dir.glob(File.join(posts_dir, '*.md')).map do |filepath|
      File.basename(filepath, '.md')
    end
  end

  # Get all existing page slugs from Hugo content directory
  def self.existing_page_slugs
    pages_dir = Config.pages_output_dir
    return [] unless Dir.exist?(pages_dir)

    Dir.glob(File.join(pages_dir, '*.md')).map do |filepath|
      File.basename(filepath, '.md')
    end
  end

  # Delete .md file for a post
  def self.delete_post(slug)
    filepath = File.join(Config.posts_output_dir, "#{slug}.md")
    if File.exist?(filepath)
      File.delete(filepath)
      puts "Deleted: #{filepath}"
      true
    else
      false
    end
  end

  # Delete .md file for a page
  def self.delete_page(slug)
    filepath = File.join(Config.pages_output_dir, "#{slug}.md")
    if File.exist?(filepath)
      File.delete(filepath)
      puts "Deleted: #{filepath}"
      true
    else
      false
    end
  end

  # Detect and delete orphaned posts (in Hugo but not in WordPress)
  def self.detect_deleted_posts
    wp_posts = fetch_posts
    wp_slugs = wp_posts.map { |p| p['slug'] }
    local_slugs = existing_post_slugs

    deleted = local_slugs - wp_slugs
    deleted.each { |slug| delete_post(slug) }

    deleted.length
  end

  # Detect and delete orphaned pages
  def self.detect_deleted_pages
    wp_pages = fetch_pages
    wp_slugs = wp_pages.map { |p| p['slug'] }
    local_slugs = existing_page_slugs

    deleted = local_slugs - wp_slugs
    deleted.each { |slug| delete_page(slug) }

    deleted.length
  end

  # Sync posts - returns count of synced posts
  def self.sync_posts(full: false)
    since = full ? nil : read_last_sync

    posts = fetch_posts(since: since)
    puts "Fetching posts#{since ? ' modified since ' + since : ''}..."

    processed = 0
    posts.each do |post|
      begin
        archived = post_archived?(post['id'])
        process_post(post, archived: archived)
        processed += 1
      rescue => e
        puts "Error processing post #{post['id']}: #{e.message}"
      end
    end

    processed
  end

  # Sync pages - returns count of synced pages
  def self.sync_pages(full: false)
    since = full ? nil : read_last_sync

    pages = fetch_pages(since: since)
    puts "Fetching pages#{since ? ' modified since ' + since : ''}..."

    processed = 0
    pages.each do |page|
      begin
        process_page(page)
        processed += 1
      rescue => e
        puts "Error processing page #{page['id']}: #{e.message}"
      end
    end

    processed
  end

  # Full sync - syncs all posts and pages, detects deletions
  def self.sync_all
    posts_count = sync_posts(full: true)
    pages_count = sync_pages(full: true)

    deleted_posts = detect_deleted_posts
    deleted_pages = detect_deleted_pages

    # Update last sync timestamp
    write_last_sync(Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))

    {
      posts: posts_count,
      pages: pages_count,
      deleted_posts: deleted_posts,
      deleted_pages: deleted_pages
    }
  end

  # Incremental sync - syncs modified posts/pages since last sync
  def self.sync_incremental
    last_sync = read_last_sync

    if last_sync.nil?
      puts "No previous sync found. Performing full sync..."
      return sync_all
    end

    posts_count = sync_posts(full: false)
    pages_count = sync_pages(full: false)

    deleted_posts = detect_deleted_posts
    deleted_pages = detect_deleted_pages

    # Update last sync timestamp
    write_last_sync(Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))

    {
      posts: posts_count,
      pages: pages_count,
      deleted_posts: deleted_posts,
      deleted_pages: deleted_pages
    }
  end

  # Sync a single post by ID
  def self.sync_post(post_id)
    uri = URI("#{Config.wp_api_url}/posts/#{post_id}")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      post = JSON.parse(response.body)
      archived = post_archived?(post['id'])
      process_post(post, archived: archived)
      1
    else
      puts "Error fetching post #{post_id}: #{response.code}"
      0
    end
  rescue => e
    puts "Error syncing post #{post_id}: #{e.message}"
    0
  end
end

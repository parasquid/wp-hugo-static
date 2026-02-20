#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'fileutils'
require 'date'

WP_API_URL = ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
OUTPUT_DIR = ENV.fetch('OUTPUT_DIR', 'hugo-site/content/posts')

def clean_filename(title)
  title.downcase.gsub(/[^\w\s-]/, '').gsub(/[-\s]+/, '-')[0, 50]
end

def html_to_markdown(html)
  return '' if html.nil? || html.empty?
  
  # Convert images to markdown format (will be processed by fetch-images.rb later)
  md = html.gsub(/<img[^>]+src=["']([^"']+)["'][^>]*alt=["']([^"']*)["'][^>]*>/, '![\\2](\\1)')
           .gsub(/<img[^>]+src=["']([^"']+)["'][^>]*>/, '![](\\1)')
           .gsub(/<h1>(.*?)<\/h1>/, "# \\1\n\n")
           .gsub(/<h2>(.*?)<\/h2>/, "## \\1\n\n")
           .gsub(/<h3>(.*?)<\/h3>/, "### \\1\n\n")
           .gsub(/<p>(.*?)<\/p>/m, "\\1\n\n")
           .gsub(/<a href="(.*?)">(.*?)<\/a>/, '[\\2](\\1)')
           .gsub(/<(strong|b)>(.*?)<\/(strong|b)>/, '**\\2**')
           .gsub(/<(em|i)>(.*?)<\/(em|i)>/, '*\\2*')
           .gsub(/<br\s*\/?>/, "\n")
           .gsub(/<[^>]+>/, '')
  
  md.gsub(/\n{3,}/, "\n\n").strip
end

def fetch_post_categories(post_id)
  uri = URI("#{WP_API_URL}/posts/#{post_id}?_fields=categories")
  response = Net::HTTP.get_response(uri)

  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    data['categories'] || []
  else
    []
  end
end

def fetch_category_name(category_id)
  return nil if category_id.nil? || category_id == 0

  uri = URI("#{WP_API_URL}/categories/#{category_id}?_fields=name")
  response = Net::HTTP.get_response(uri)

  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    data['name']
  else
    nil
  end
end

def post_archived?(post_id)
  categories = fetch_post_categories(post_id)
  return false if categories.empty?

  categories.each do |cat_id|
    name = fetch_category_name(cat_id)
    return true if name && name.downcase == 'archived'
  end

  false
end

def fetch_posts
  posts = []
  page = 1
  
  loop do
    uri = URI("#{WP_API_URL}/posts?page=#{page}&per_page=100&status=publish")
    response = Net::HTTP.get_response(uri)
    
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

def create_frontmatter(post)
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

def process_post(post, archived = false)
  frontmatter = create_frontmatter(post)
  content_html = post.dig('content', 'rendered')
  content_md = html_to_markdown(content_html)
  
  frontmatter['archived'] = true if archived
  
  filename = "#{post['slug']}.md"
  filepath = File.join(OUTPUT_DIR, filename)
  
  FileUtils.mkdir_p(OUTPUT_DIR)
  
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
    f.puts content_md
  end
  
  puts "Created: #{filepath}"
  filepath
end

def main
  puts "Fetching posts from WordPress..."
  posts = fetch_posts
  puts "Found #{posts.length} posts"

  processed = 0
  skipped_archived = 0

  posts.each do |post|
    begin
      archived = post_archived?(post['id'])
      
      if archived
        puts "Processing archived post: #{post['slug']}"
        skipped_archived += 1
      end

      process_post(post, archived)
      processed += 1
    rescue => e
      puts "Error processing post #{post['id']}: #{e.message}"
    end
  end

  puts "Done!"
  puts "Processed: #{processed}"
  puts "Skipped (archived): #{skipped_archived}"
end

main if __FILE__ == $0

#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'
require 'base64'

WP_API_URL = ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
WP_USERNAME = ENV.fetch('WP_USERNAME', nil)
WP_APPLICATION_PASSWORD = ENV.fetch('WP_APPLICATION_PASSWORD', nil)

SLUG_PREFIX = 'test-post'

def get_auth_header
  return nil unless WP_USERNAME && WP_APPLICATION_PASSWORD
  credentials = "#{WP_USERNAME}:#{WP_APPLICATION_PASSWORD}"
  encoded = Base64.strict_encode64(credentials)
  "Basic #{encoded}"
end

def http_get(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri)
  request['Content-Type'] = 'application/json'
  request['Authorization'] = get_auth_header if get_auth_header
  http.request(request)
end

def http_post(uri, body)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request['Authorization'] = get_auth_header if get_auth_header
  request.body = body.to_json
  http.request(request)
end

def http_delete(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Delete.new(uri)
  request['Content-Type'] = 'application/json'
  request['Authorization'] = get_auth_header if get_auth_header
  http.request(request)
end

def find_existing_test_posts
  uri = URI("#{WP_API_URL}?slug=#{SLUG_PREFIX}-regular-1,#{SLUG_PREFIX}-regular-2,#{SLUG_PREFIX}-archived&per_page=10")
  response = http_get(uri)
  
  if response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  else
    []
  end
end

def delete_post(post_id)
  uri = URI("#{WP_API_URL}/#{post_id}")
  response = http_delete(uri)
  
  if response.is_a?(Net::HTTPSuccess)
    puts "  Deleted post ID: #{post_id}"
    true
  else
    puts "  Failed to delete post ID #{post_id}: #{response.code}"
    false
  end
end

def cleanup_existing_test_posts
  puts "Checking for existing test posts..."
  existing_posts = find_existing_test_posts
  
  if existing_posts.empty?
    puts "  No existing test posts found."
    return
  end
  
  puts "  Found #{existing_posts.length} existing test post(s). Deleting..."
  existing_posts.each do |post|
    delete_post(post['id'])
  end
  puts "  Cleanup complete."
end

def find_or_create_category(name)
  uri = URI("#{WP_API_URL}/categories?search=#{URI.encode_www_form_component(name)}")
  response = http_get(uri)
  
  if response.is_a?(Net::HTTPSuccess)
    categories = JSON.parse(response.body)
    if categories.any?
      puts "Found existing category: #{name} (ID: #{categories.first['id']})"
      return categories.first['id']
    end
  end
  
  puts "Creating category: #{name}"
  create_uri = URI("#{WP_API_URL}/categories")
  response = http_post(create_uri, { name: name })
  
  if response.is_a?(Net::HTTPSuccess)
    category = JSON.parse(response.body)
    puts "Created category: #{name} (ID: #{category['id']})"
    category['id']
  else
    raise "Failed to create category: #{response.code} - #{response.body}"
  end
end

def create_post(title, slug, content, categories: [], status: 'publish')
  puts "Creating post: #{title}"
  uri = URI("#{WP_API_URL}/posts")
  payload = { 
    title: title, 
    content: content, 
    status: status, 
    categories: categories,
    slug: slug
  }
  
  response = http_post(uri, payload)
  
  if response.is_a?(Net::HTTPSuccess)
    post = JSON.parse(response.body)
    puts "  Created post ID: #{post['id']}, slug: #{post['slug']}"
    post['id']
  else
    raise "Failed to create post: #{response.code} - #{response.body}"
  end
end

def verify_api_accessible
  puts "Checking WordPress API at #{WP_API_URL}..."
  uri = URI("#{WP_API_URL}")
  response = http_get(uri)
  
  unless response.is_a?(Net::HTTPSuccess)
    puts "ERROR: Cannot connect to WordPress API"
    puts "Response: #{response.code} - #{response.body}"
    exit 1
  end
  
  wp_info = JSON.parse(response.body)
  puts "Connected to WordPress: #{wp_info.dig('name')}"
  puts
end

def seed_test_posts
  archived_category_id = find_or_create_category('Archived')
  puts

  puts "Creating regular posts (for testing active comments)..."
  puts
  
  post1_id = create_post(
    'Regular Post 1',
    'test-post-regular-1',
    '<p>This is Regular Post 1 for testing active comments.</p><p>It has the active comments widget enabled.</p><h2>Testing Active Comments</h2><p>We need to verify that comments are properly baked into the static HTML.</p>'
  )
  puts

  post2_id = create_post(
    'Regular Post 2',
    'test-post-regular-2',
    '<p>This is Regular Post 2 for testing active comments.</p><p>It also has the active comments widget enabled.</p><h2>Testing Multiple Posts</h2><p>We want to ensure multiple posts with comments work correctly.</p>'
  )
  puts

  puts "Creating archived post (for testing archived behavior)..."
  puts
  
  post3_id = create_post(
    'Archived Post',
    'test-post-archived',
    '<p>This is an archived test post.</p><p>It should have baked comments but no Giscus widget.</p><h2>Archive Behavior</h2><p>Posts with the "Archived" category should display comments as static HTML only.</p>',
    categories: [archived_category_id]
  )
  puts

  { post1_id: post1_id, post2_id: post2_id, post3_id: post3_id }
end

def print_summary(posts)
  puts "=" * 60
  puts "SEEDING COMPLETE"
  puts "=" * 60
  puts
  puts "Created posts:"
  puts "  1. Regular Post 1 (ID: #{posts[:post1_id]})"
  puts "  2. Regular Post 2 (ID: #{posts[:post2_id]})"
  puts "  3. Archived Post (ID: #{posts[:post3_id]}, category: Archived)"
  puts
  puts "To add test comments to these posts, use the WordPress admin"
  puts "or the fetch-comments.rb script."
end

def main
  puts "=" * 60
  puts "WordPress Test Posts Seeder"
  puts "=" * 60
  puts
  
  verify_api_accessible
  cleanup_existing_test_posts
  puts
  posts = seed_test_posts
  print_summary(posts)
end

main if __FILE__ == $0

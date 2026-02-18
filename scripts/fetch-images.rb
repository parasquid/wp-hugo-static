#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'fileutils'
require 'uri'

WP_API_URL = ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
OUTPUT_DIR = ENV.fetch('OUTPUT_DIR', 'hugo-site/static/images')

def extract_image_urls(content)
  urls = []
  content.scan(/<img[^>]+src=["']([^"']+)["']/) { |match| urls << match[0] }
  content.scan(/srcset=["']([^"']+)["']/) do |match|
    match[0].split(',').each { |src| urls << src.strip.split(' ').first }
  end
  urls.uniq
end

def download_image(url, output_path)
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  
  if response.is_a?(Net::HTTPSuccess)
    FileUtils.mkdir_p(File.dirname(output_path))
    File.binwrite(output_path, response.body)
    puts "Downloaded: #{output_path}"
    true
  else
    puts "Failed to download #{url}: #{response.code}"
    false
  end
rescue => e
  puts "Error downloading #{url}: #{e.message}"
  false
end

def process_content_images(content, post_slug)
  urls = extract_image_urls(content)
  mapping = {}
  
  urls.each do |url|
    filename = File.basename(URI(url).path)
    output_path = File.join(OUTPUT_DIR, 'content', post_slug, filename)
    
    if download_image(url, output_path)
      relative_path = output_path.sub(%r{^.*/static/}, '/')
      mapping[url] = relative_path
    end
  end
  
  mapping
end

def fetch_featured_image(media_id, post_slug)
  return nil unless media_id
  
  uri = URI("#{WP_API_URL}/media/#{media_id}")
  response = Net::HTTP.get_response(uri)
  
  if response.is_a?(Net::HTTPSuccess)
    media = JSON.parse(response.body)
    url = media.dig('source_url')
    return nil unless url
    
    filename = File.basename(URI(url).path)
    output_path = File.join(OUTPUT_DIR, 'featured', "#{post_slug}#{File.extname(filename)}")
    
    download_image(url, output_path) ? output_path.sub(%r{^.*/static/}, '/') : nil
  end
rescue => e
  puts "Error fetching featured image #{media_id}: #{e.message}"
  nil
end

def update_content_image_paths(content, mapping)
  mapping.each do |original_url, new_path|
    content = content.gsub(original_url, new_path)
  end
  content
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
      break
    end
  end
  
  posts
end

def main
  puts "Fetching posts and downloading images..."
  posts = fetch_posts
  
  posts.each do |post|
    slug = post['slug']
    content = post.dig('content', 'rendered')
    
    puts "\nProcessing: #{slug}"
    
    mapping = process_content_images(content, slug)
    featured = fetch_featured_image(post['featured_media'], slug)
    
    puts "  Content images: #{mapping.keys.length}"
    puts "  Featured image: #{featured ? 'yes' : 'no'}"
  end
  
  puts "\nDone!"
end

main if __FILE__ == $0

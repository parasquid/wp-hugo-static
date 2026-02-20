#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'fileutils'
require 'uri'
require 'mini_magick'
require 'image_optim'

WP_API_URL = ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
OUTPUT_DIR = ENV.fetch('OUTPUT_DIR', 'hugo-site/static/images')
SCRIPT_DIR = File.dirname(File.expand_path(__FILE__))
# Watermark always in static/images regardless of OUTPUT_DIR
WATERMARK_PATH = File.join(SCRIPT_DIR, '..', 'hugo-site', 'static', 'images', 'watermark.png')
POSTS_DIR = File.join(SCRIPT_DIR, '..', 'hugo-site', 'content', 'posts')

# Image processing configuration
MAX_LANDSCAPE_WIDTH = 1920
MAX_PORTRAIT_HEIGHT = 1200
WATERMARK_SIZE = 100
WATERMARK_OPACITY = 0.20
WATERMARK_TILES = 4
WATERMARK_JITTER = 20
WEBP_QUALITY = 80

def extract_image_urls(content)
  urls = []
  content.scan(/<img[^>]+src=["']([^"']+)["']/) { |match| urls << match[0] }
  content.scan(/!\[.*?\]\(([^)]+)\)/) { |match| urls << match[0] }
  content.scan(/srcset=["']([^"']+)["']/) do |match|
    match[0].split(',').each { |src| urls << src.strip.split(' ').first }
  end
  urls.uniq
end

def skip_svg?(filename)
  File.extname(filename).downcase == '.svg'
end

def animated_gif?(path)
  return false unless File.extname(path).downcase == '.gif'
  
  begin
    image = MiniMagick::Image.open(path)
    layers = image.data['pages']
    layers && layers > 1
  rescue
    false
  end
end

def resize_image(path)
  puts "  Resizing: #{File.basename(path)}"
  image = MiniMagick::Image.open(path)
  
  width = image.width
  height = image.height
  
  resize_geometry = if width > height
    "#{MAX_LANDSCAPE_WIDTH}x>"
  else
    "x#{MAX_PORTRAIT_HEIGHT}>"
  end
  
  if width > (width > height ? MAX_LANDSCAPE_WIDTH : MAX_PORTRAIT_HEIGHT)
    image.resize(resize_geometry)
    image.write(path)
    puts "    Resized to #{image.width}x#{image.height}"
  else
    puts "    No resize needed"
  end
  
  image
end

def apply_tiled_watermark(path)
  return unless File.exist?(WATERMARK_PATH)
  
  puts "  Applying tiled watermark: #{File.basename(path)}"
  
  img = MiniMagick::Image.open(path)
  wm = MiniMagick::Image.open(WATERMARK_PATH)
  
  img_width = img.width
  img_height = img.height
  wm_width = wm.width
  wm_height = wm.height
  
  tile_count = 4
  tile_w = img_width / tile_count
  tile_h = img_height / tile_count
  
  temp_canvas = "/tmp/canvas_#{$$}.png"
  `convert -size #{img_width}x#{img_height} xc:transparent #{temp_canvas}`
  
  tile_count.times do |row|
    tile_count.times do |col|
      x = col * tile_w + (tile_w - wm_width) / 2
      y = row * tile_h + (tile_h - wm_height) / 2
      
      x += rand(-20..20)
      y += rand(-20..20)
      
      x = [0, [x, img_width - wm_width].min].max
      y = [0, [y, img_height - wm_height].min].max
      
      rotated = "/tmp/wm_rotated_#{$$}.png"
      rotation = rand(-30..30)
      `convert #{WATERMARK_PATH} -background none -rotate #{rotation} -alpha set #{rotated}`
      
      `composite -geometry +#{x}+#{y} -dissolve 20 #{rotated} #{temp_canvas} #{temp_canvas}`
      File.delete(rotated) if File.exist?(rotated)
    end
  end
  
  `composite -compose over #{temp_canvas} #{path} #{path}`
  File.delete(temp_canvas) if File.exist?(temp_canvas)
  
  puts "    Watermark applied (#{tile_count}x#{tile_count} tiles)"
end

def convert_to_webp_only(path)
  return nil unless File.exist?(path)
  
  webp_path = path.sub(/\.[^.]+$/, '.webp')
  return webp_path if File.exist?(webp_path)
  
  puts "  Converting to WebP: #{File.basename(path)}"
  
  begin
    image = MiniMagick::Image.open(path)
    image.quality WEBP_QUALITY.to_s
    image.format 'webp'
    image.write(webp_path)
    puts "    Created: #{File.basename(webp_path)}"
    File.delete(path)
    puts "    Deleted original: #{File.basename(path)}"
    
    webp_path
  rescue => e
    puts "    WebP conversion failed: #{e.message}"
    nil
  end
end

def optimize_images(image_paths)
  return unless image_paths.any? { |p| File.exist?(p) }
  
  puts "  Optimizing with image_optim..."
  
  begin
    optimizer = ImageOptim.new(
      pngcrush: false,
      pngout: false,
      advpng: false,
      oxipng: false,
      jhead: false,
      jpegtran: false,
      gifsicle: false,
      svgo: false
    )
    
    image_paths.each do |path|
      next unless File.exist?(path)
      
      begin
        optimized = optimizer.optimize_image(path)
        puts "    Optimized: #{File.basename(path)}" if optimized
      rescue => e
        puts "    Optimization failed for #{File.basename(path)}: #{e.message}"
      end
    end
  rescue => e
    puts "    image_optim initialization failed: #{e.message}"
  end
end

def already_processed?(path)
  return false unless File.exist?(path)
  
  webp_path = path.sub(/\.[^.]+$/, '.webp')
  return false unless File.exist?(webp_path)
  
  original_mtime = File.mtime(path)
  webp_mtime = File.mtime(webp_path)
  
  if original_mtime <= webp_mtime
    puts "  Skipping: #{File.basename(path)} - already processed"
    return true
  end
  
  false
end

def process_image(path)
  return nil unless File.exist?(path)

  filename = File.basename(path)

  if skip_svg?(filename)
    puts "  Skipping SVG: #{filename}"
    return path
  end

  if animated_gif?(path)
    puts "  Skipping animated GIF: #{filename}"
    return path
  end

  if already_processed?(path)
    webp_path = path.sub(/\.[^.]+$/, '.webp')
    return File.exist?(webp_path) ? webp_path : path
  end

  resize_image(path)
  apply_tiled_watermark(path)

  webp_path = convert_to_webp_only(path)

  if webp_path
    optimize_images([webp_path])
    puts "  Processing complete"
  end

  webp_path || path
end

def download_image(url, output_path)
  uri = URI(url)
  response = Net::HTTP.get_response(uri)

  if response.is_a?(Net::HTTPSuccess)
    FileUtils.mkdir_p(File.dirname(output_path))
    File.binwrite(output_path, response.body)
    puts "Downloaded: #{output_path}"

    return process_image(output_path)
  else
    puts "Failed to download #{url}: #{response.code}"
    nil
  end
rescue => e
  puts "Error downloading #{url}: #{e.message}"
  nil
end

def process_content_images(content, post_slug)
  urls = extract_image_urls(content)
  mapping = {}

  urls.each do |url|
    filename = File.basename(URI(url).path)
    output_path = File.join(OUTPUT_DIR, 'content', post_slug, filename)

    webp_path = download_image(url, output_path)
    if webp_path
      relative_path = webp_path.sub(%r{^.*/static/}, '/')
      mapping[url] = relative_path

      # Also map jpg path to webp path for already-updated markdown
      jpg_path = relative_path.sub(/\.webp$/, '.jpg')
      mapping[jpg_path] = relative_path if jpg_path != relative_path
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

def update_markdown_file(slug, url_mapping)
  return if url_mapping.empty?
  
  markdown_path = File.join(POSTS_DIR, "#{slug}.md")
  return unless File.exist?(markdown_path)
  
  content = File.read(markdown_path)
  updated_content = update_content_image_paths(content, url_mapping)
  
  if content != updated_content
    File.write(markdown_path, updated_content)
    puts "  Updated markdown: #{slug}.md"
  end
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


# Generate watermark dynamically using ImageMagick
# Key fix: use exact font name from `convert -list font` output
def generate_watermark(text, output_path, size: 100)
  puts "  Generating watermark: #{text}"
  
  # Must use exact font name from ImageMagick's font list (case-sensitive)
  font_name = "DejaVu-Sans"
  
  # Calculate size based on text length
  width = [text.length * 12, 120].max
  height = 30
  
  # Escape single quotes in text
  safe_text = text.gsub("'", "'\\''")
  
  # Use convert directly with explicit font name
  cmd = "convert -size #{width}x#{height} xc:transparent -font '#{font_name}' " \
        "-pointsize 14 -fill white -gravity center -annotate +0+0 '#{safe_text}' #{output_path}"
  
  result = system(cmd)
  
  if result && File.exist?(output_path)
    puts "    Watermark created: #{output_path}"
    
    # Resize to desired size
    image = MiniMagick::Image.open(output_path)
    image.resize "#{size}x#{size}!"
    image.write output_path
    puts "    Resized to #{size}x#{size}"
    
    true
  else
    puts "    ERROR: Watermark creation failed"
    false
  end
end

# Ensure watermark exists, generate if missing
def ensure_watermark(site_url)
  return if File.exist?(WATERMARK_PATH)
  
  FileUtils.mkdir_p(File.dirname(WATERMARK_PATH))
  
  # Extract domain from URL
  domain = URI(site_url).host rescue site_url
  generate_watermark(domain, WATERMARK_PATH)
end

def main
  # Ensure watermark exists before processing images
  ensure_watermark(ENV.fetch("PUBLIC_DOMAIN", "example.com"))
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

    update_markdown_file(slug, mapping)
  end
  
  puts "\nDone!"
end

main if __FILE__ == $0

#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'fileutils'
require 'uri'
require 'mini_magick'
require 'image_optim'

WP_API_URL = ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
OUTPUT_DIR = ENV.fetch('OUTPUT_DIR', 'hugo-site/static/images')
WATERMARK_PATH = File.join(OUTPUT_DIR, 'watermark.png')

# Image processing configuration
MAX_LANDSCAPE_WIDTH = 1920
MAX_PORTRAIT_HEIGHT = 1200
WATERMARK_SIZE = 100
WATERMARK_OPACITY = 0.20
WATERMARK_TILES = 4
WATERMARK_JITTER = 20
WEBP_QUALITY = 80
AVIF_QUALITY = 50

def extract_image_urls(content)
  urls = []
  content.scan(/<img[^>]+src=["']([^"']+)["']/) { |match| urls << match[0] }
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
  image = MiniMagick::Image.open(path)
  watermark = MiniMagick::Image.open(WATERMARK_PATH)
  
  watermark.resize "#{WATERMARK_SIZE}x#{WATERMARK_SIZE}!"
  watermark.alpha 'set'
  watermark.background 'none'
  
  img_width = image.width
  img_height = image.height
  wm_width = watermark.width
  wm_height = watermark.height
  
  tile_width = img_width / WATERMARK_TILES
  tile_height = img_height / WATERMARK_TILES
  
  WATERMARK_TILES.times do |row|
    WATERMARK_TILES.times do |col|
      x_offset = (col * tile_width) + (tile_width - wm_width) / 2
      y_offset = (row * tile_height) + (tile_height - wm_height) / 2
      
      x_offset += rand(-WATERMARK_JITTER..WATERMARK_JITTER)
      y_offset += rand(-WATERMARK_JITTER..WATERMARK_JITTER)
      
      x_offset = [0, [x_offset, img_width - wm_width].min].max
      y_offset = [0, [y_offset, img_height - wm_height].min].max
      
      watermark_copy = watermark.dup
      watermark_copy.expression = "A*#{WATERMARK_OPACITY}"
      image = image.composite(watermark_copy) do |c|
        c.geometry "+#{x_offset}+#{y_offset}"
      end
    end
  end
  
  image.write(path)
  puts "    Watermark applied (#{WATERMARK_TILES}x#{WATERMARK_TILES} tiles)"
end

def convert_to_webp(path)
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
    webp_path
  rescue => e
    puts "    WebP conversion failed: #{e.message}"
    nil
  end
end

def convert_to_avif(path)
  return nil unless File.exist?(path)
  
  avif_path = path.sub(/\.[^.]+$/, '.avif')
  return avif_path if File.exist?(avif_path)
  
  puts "  Converting to AVIF: #{File.basename(path)}"
  
  begin
    image = MiniMagick::Image.open(path)
    image.quality AVIF_QUALITY.to_s
    image.format 'avif'
    image.write(avif_path)
    puts "    Created: #{File.basename(avif_path)}"
    avif_path
  rescue => e
    puts "    AVIF conversion failed (ImageMagick may lack AV1 encoder): #{e.message}"
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
  avif_path = path.sub(/\.[^.]+$/, '.avif')
  
  return false unless File.exist?(webp_path) && File.exist?(avif_path)
  
  original_mtime = File.mtime(path)
  webp_mtime = File.mtime(webp_path)
  avif_mtime = File.mtime(avif_path)
  
  if original_mtime <= webp_mtime && original_mtime <= avif_mtime
    puts "  Skipping: #{File.basename(path)} - already processed"
    return true
  end
  
  false
end

def process_image(path)
  return unless File.exist?(path)
  
  filename = File.basename(path)
  
  if skip_svg?(filename)
    puts "  Skipping SVG: #{filename}"
    return
  end
  
  if animated_gif?(path)
    puts "  Skipping animated GIF: #{filename}"
    return
  end
  
  if already_processed?(path)
    return
  end
  
  puts "Processing: #{filename}"
  resize_image(path)
  apply_tiled_watermark(path)
  
  variants = [path]
  variants << convert_to_webp(path) if convert_to_webp(path)
  variants << convert_to_avif(path) if convert_to_avif(path)
  
  optimize_images(variants.compact)
  
  puts "  Processing complete"
end

def download_image(url, output_path)
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  
  if response.is_a?(Net::HTTPSuccess)
    FileUtils.mkdir_p(File.dirname(output_path))
    File.binwrite(output_path, response.body)
    puts "Downloaded: #{output_path}"
    
    process_image(output_path)
    
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

#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'fileutils'
require 'date'

WP_API_URL = ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
OUTPUT_DIR = ENV.fetch('OUTPUT_DIR', 'hugo-site/content/pages')

def clean_filename(title)
  title.downcase.gsub(/[^\w\s-]/, '').gsub(/[-\s]+/, '-')[0, 50]
end

def html_to_markdown(html)
  return '' if html.nil? || html.empty?
  
  md = html.gsub(/<h1>(.*?)<\/h1>/, "# \\1\n\n")
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

def fetch_pages
  pages = []
  page = 1
  
  loop do
    uri = URI("#{WP_API_URL}/pages?page=#{page}&per_page=100&status=publish")
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

def create_frontmatter(page)
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

def process_page(page)
  frontmatter = create_frontmatter(page)
  content_md = html_to_markdown(page.dig('content', 'rendered'))
  
  filepath = File.join(OUTPUT_DIR, "#{page['slug']}.md")
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
end

def main
  puts "Fetching pages from WordPress..."
  pages = fetch_pages
  puts "Found #{pages.length} pages"
  
  pages.each do |page|
    process_page(page)
  rescue => e
    puts "Error processing page #{page['id']}: #{e.message}"
  end
  
  puts "Done!"
end

main if __FILE__ == $0

#!/usr/bin/env ruby
require_relative '../lib/sync'

def main
  puts "Fetching pages from WordPress..."
  pages = Sync.fetch_pages
  puts "Found #{pages.length} pages"
  
  pages.each do |page|
    begin
      Sync.process_page(page)
    rescue => e
      puts "Error processing page #{page['id']}: #{e.message}"
    end
  end
  
  puts "Done!"
end

main if __FILE__ == $0

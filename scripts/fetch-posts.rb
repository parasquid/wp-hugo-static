#!/usr/bin/env ruby
require_relative '../lib/sync'

def main
  puts "Fetching posts from WordPress..."
  posts = Sync.fetch_posts
  puts "Found #{posts.length} posts"

  processed = 0
  skipped_archived = 0

  posts.each do |post|
    begin
      archived = Sync.post_archived?(post['id'])
      
      if archived
        puts "Processing archived post: #{post['slug']}"
        skipped_archived += 1
      end

      Sync.process_post(post, archived: archived)
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

#!/usr/bin/env ruby
require_relative '../lib/sync'

require 'optparse'

options = {
  full: false,
  post_id: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby sync.rb [options]"
  
  opts.on("--full", "Perform full sync (ignore last sync timestamp)") do |v|
    options[:full] = v
  end
  
  opts.on("--post-id=ID", Integer, "Sync a single post by ID") do |v|
    options[:post_id] = v
  end
  
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    puts
    puts "Examples:"
    puts "  ruby sync.rb              # Incremental sync since last run"
    puts "  ruby sync.rb --full      # Full sync of all posts/pages"
    puts "  ruby sync.rb --post-id=5 # Sync only post ID 5"
    exit
  end
end.parse!

if options[:post_id]
  puts "Syncing single post ID: #{options[:post_id]}"
  count = Sync.sync_post(options[:post_id])
  puts "Synced #{count} post"
else
  puts "Starting sync..."
  puts
  
  if options[:full]
    result = Sync.sync_all
  else
    result = Sync.sync_incremental
  end
  
  puts
  puts "Sync complete!"
  puts "  Posts: #{result[:posts]}"
  puts "  Pages: #{result[:pages]}"
  puts "  Deleted posts: #{result[:deleted_posts]}"
  puts "  Deleted pages: #{result[:deleted_pages]}"
end

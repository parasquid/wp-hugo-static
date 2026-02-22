#!/usr/bin/env ruby
require_relative '../lib/sync'
require 'net/http'
require 'json'
require 'fileutils'

GITHUB_TOKEN = ENV.fetch('GITHUB_TOKEN', '')
GITHUB_REPO = ENV.fetch('GITHUB_REPO', 'owner/repo')
OUTPUT_DIR = 'hugo-site/data/comments'

GITHUB_GRAPHQL_URL = 'https://api.github.com/graphql'

def fetch_discussions(slug)
  return [] if GITHUB_TOKEN.empty?

  query = <<~GRAPHQL
    query($owner: String!, $repo: String!, $slug: String!) {
      repository(owner: $owner, name: $repo) {
        discussions(first: 10, query: $slug) {
          nodes {
            id
            title
            url
            comments(first: 100) {
              nodes {
                author { login }
                body
                createdAt
                url
              }
            }
          }
        }
      }
    }
  GRAPHQL

  owner, repo = GITHUB_REPO.split('/')
  variables = { owner: owner, repo: repo, slug: slug }
  body = { query: query, variables: variables }

  uri = URI(GITHUB_GRAPHQL_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{GITHUB_TOKEN}"
  request['Content-Type'] = 'application/json'
  request.body = body.to_json

  begin
    response = http.request(request)
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      discussions = data.dig('data', 'repository', 'discussions', 'nodes') || []
      discussions.select { |d| d['title']&.downcase&.include?(slug.downcase) }
    else
      puts "Error fetching discussions: #{response.code}"
      []
    end
  rescue => e
    puts "Error querying GitHub: #{e.message}"
    []
  end
end

def extract_comments_from_discussion(discussion)
  return [] unless discussion['comments'] && discussion['comments']['nodes']
  discussion['comments']['nodes'].map do |comment|
    {
      'author' => comment.dig('author', 'login') || 'anonymous',
      'body' => comment['body'] || '',
      'createdAt' => comment['createdAt'] || '',
      'url' => comment['url'] || discussion['url']
    }
  end
end

def process_post(post)
  slug = post['slug']
  post_id = post['id']

  puts "Processing post: #{slug}"
  archived = Sync.post_archived?(post_id)
  puts "  Archived: #{archived}"

  discussions = fetch_discussions(slug)

  if discussions.empty?
    puts "  No discussions found for: #{slug}"
    return nil
  end

  all_comments = []
  discussions.each do |discussion|
    comments = extract_comments_from_discussion(discussion)
    all_comments.concat(comments)
  end

  return nil if all_comments.empty?

  FileUtils.mkdir_p(OUTPUT_DIR)
  output = { 'comments' => all_comments }
  filepath = File.join(OUTPUT_DIR, "#{slug}.json")

  File.open(filepath, 'w:UTF-8') { |f| f.write(JSON.pretty_generate(output)) }
  puts "  Saved #{all_comments.length} comments to: #{filepath}"
  filepath
end

def main
  puts "Fetching posts from WordPress..."
  posts = Sync.fetch_posts
  puts "Found #{posts.length} posts"

  processed = 0
  skipped_archived = 0
  skipped_no_discussions = 0
  created_files = 0

  posts.each do |post|
    begin
      result = process_post(post)
      if result
        created_files += 1
      else
        skipped_no_discussions += 1
      end
      processed += 1
    rescue => e
      puts "Error processing post #{post['id']}: #{e.message}"
    end
  end

  puts "\nDone!"
  puts "Processed: #{processed}"
  puts "Skipped (archived): #{skipped_archived}"
  puts "Skipped (no discussions): #{skipped_no_discussions}"
  puts "Created files: #{created_files}"
end

main if __FILE__ == $0

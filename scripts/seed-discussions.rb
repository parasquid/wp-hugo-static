#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

GITHUB_TOKEN = ENV.fetch('GITHUB_TOKEN', nil)
GITHUB_REPO = ENV.fetch('GITHUB_REPO', nil)
CATEGORY_NAME = 'Discussions'

POST_SLUGS = {
  'test-post-regular-1' => 'Regular Post 1',
  'test-post-regular-2' => 'Regular Post 2'
}

ARCHIVED_SLUG = 'test-post-archived'

def check_env_vars
  unless GITHUB_TOKEN
    puts "ERROR: GITHUB_TOKEN environment variable not set."
    puts "Please set it to a GitHub Personal Access Token with 'repo' scope."
    exit 0
  end

  unless GITHUB_REPO
    puts "ERROR: GITHUB_REPO environment variable not set."
    puts "Please set it to your GitHub repository (e.g., 'owner/repo')."
    exit 0
  end

  puts "GitHub repository: #{GITHUB_REPO}"
  puts
end

def graphql_request(query, variables = {})
  uri = URI('https://api.github.com/graphql')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{GITHUB_TOKEN}"
  request['Content-Type'] = 'application/json'
  request.body = { query: query, variables: variables }.to_json

  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    raise "GraphQL request failed: #{response.code} - #{response.body}"
  end

  result = JSON.parse(response.body)

  if result['errors']
    raise "GraphQL errors: #{result['errors']}"
  end

  result['data']
end

def get_repo_id
  query = <<~GRAPHQL
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        id
      }
    }
  GRAPHQL

  owner, name = GITHUB_REPO.split('/')
  data = graphql_request(query, { owner: owner, name: name })
  data['repository']['id']
end

def get_or_create_category(repo_id)
  query = <<~GRAPHQL
    query($repoId: ID!) {
      repository(id: $repoId) {
        discussionCategories(first: 10) {
          nodes {
            id
            name
            slug
          }
        }
      }
    }
  GRAPHQL

  data = graphql_request(query, { repoId: repo_id })
  categories = data['repository']['discussionCategories']['nodes']

  existing = categories.find { |c| c['name'] == CATEGORY_NAME || c['slug'] == 'general' }
  if existing
    puts "Found existing category: #{existing['name']} (ID: #{existing['id']})"
    return existing['id']
  end

  first_category = categories.first
  unless first_category
    raise "No discussion categories available. Please enable GitHub Discussions on your repository."
  end

  puts "Using existing category: #{first_category['name']} (ID: #{first_category['id']})"
  first_category['id']
end

def delete_discussion(discussion_id)
  mutation = <<~GRAPHQL
    mutation($id: ID!) {
      deleteDiscussion(input: { id: $id }) {
        discussion {
          id
        }
      }
    }
  GRAPHQL

  graphql_request(mutation, { id: discussion_id })
  puts "  Deleted discussion: #{discussion_id}"
end

def cleanup_existing_test_discussions(repo_id)
  puts "Checking for existing test discussions..."

  query = <<~GRAPHQL
    query($repoId: ID!) {
      repository(id: $repoId) {
        discussions(first: 50) {
          nodes {
            id
            title
            url
          }
        }
      }
    }
  GRAPHQL

  data = graphql_request(query, { repoId: repo_id })
  discussions = data['repository']['discussions']['nodes']

  test_discussions = discussions.select { |d| d['title'].include?('test-post') }

  if test_discussions.empty?
    puts "  No existing test discussions found."
    return
  end

  puts "  Found #{test_discussions.length} existing test discussion(s). Deleting..."
  test_discussions.each { |discussion| delete_discussion(discussion['id']) }
  puts "  Cleanup complete."
  puts
end

def create_discussion(repo_id, category_id, title, body)
  mutation = <<~GRAPHQL
    mutation($repoId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
      createDiscussion(input: {
        repositoryId: $repoId,
        categoryId: $categoryId,
        title: $title,
        body: $body
      }) {
        discussion {
          id
          title
          url
        }
      }
    }
  GRAPHQL

  data = graphql_request(mutation, {
    repoId: repo_id,
    categoryId: category_id,
    title: title,
    body: body
  })

  discussion = data['createDiscussion']['discussion']
  puts "  Created discussion: #{discussion['title']}"
  puts "    URL: #{discussion['url']}"
  discussion
end

def add_comment(discussion_id, body)
  mutation = <<~GRAPHQL
    mutation($discussionId: ID!, $body: String!) {
      addDiscussionComment(input: {
        discussionId: $discussionId,
        body: $body
      }) {
        comment {
          id
          url
        }
      }
    }
  GRAPHQL

  data = graphql_request(mutation, { discussionId: discussion_id, body: body })
  comment = data['addDiscussionComment']['comment']
  puts "    Added comment: #{comment['url']}"
end

def seed_discussions(repo_id, category_id)
  puts "Creating discussions for regular posts..."
  puts

  POST_SLUGS.each do |slug, post_title|
    discussion_title = "#{post_title} - Discussion"

    puts "Creating discussion for: #{slug}"
    discussion = create_discussion(
      repo_id,
      category_id,
      discussion_title,
      "Discussion thread for #{post_title}.\n\nFeel free to leave comments and questions about this post!"
    )

    puts "  Adding sample comments..."
    add_comment(discussion['id'], "Great post! I really enjoyed reading this. Looking forward to more content like this.")
    add_comment(discussion['id'], "Thanks for sharing this. I have a question: how does this compare to other solutions out there?")
    add_comment(discussion['id'], "This is exactly what I was looking for. The implementation details were very helpful!")
    puts
  end

  puts "Skipping archived post: #{ARCHIVED_SLUG} (archived posts don't get discussions)"
  puts
end

def print_summary
  puts "=" * 60
  puts "SEEDING COMPLETE"
  puts "=" * 60
  puts
  puts "Created discussions with comments for:"
  POST_SLUGS.each { |slug, title| puts "  - #{title} (#{slug})" }
  puts
  puts "Skipped:"
  puts "  - #{ARCHIVED_SLUG} (archived)"
  puts
  puts "You can view these discussions at:"
  puts "  https://github.com/#{GITHUB_REPO}/discussions"
end

def main
  puts "=" * 60
  puts "GitHub Discussions Seeder"
  puts "=" * 60
  puts

  check_env_vars

  puts "Fetching repository info..."
  repo_id = get_repo_id
  puts "Repository ID: #{repo_id}"
  puts

  puts "Getting discussion category..."
  category_id = get_or_create_category(repo_id)
  puts

  cleanup_existing_test_discussions(repo_id)

  seed_discussions(repo_id, category_id)

  print_summary
end

main if __FILE__ == $0

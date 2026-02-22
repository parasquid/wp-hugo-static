#!/usr/bin/env ruby
require 'webrick'
require 'json'
require_relative '../lib/sync'

PORT = ENV.fetch('SYNC_SERVER_PORT', '4567').to_i
SECRET = ENV.fetch('SYNC_WEBHOOK_SECRET', nil)

class SyncServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    if request.path == '/health'
      send_response(response, 200, 'OK')
    else
      send_response(response, 404, 'Not Found')
    end
  end

  def do_POST(request, response)
    if request.path == '/webhook'
      handle_webhook(request, response)
    else
      send_response(response, 404, 'Not Found')
    end
  end

  private

  def handle_webhook(request, response)
    if SECRET
      provided_secret = request.header['x-webhook-secret'].first
      if provided_secret != SECRET
        puts 'Webhook rejected: invalid secret'
        send_response(response, 401, 'Unauthorized')
        return
      end
    end

    begin
      payload = JSON.parse(request.body)
    rescue JSON::ParserError
      send_response(response, 400, 'Invalid JSON')
      return
    end

    puts "Received webhook: #{payload}"

    action = payload['action']
    post_id = payload['post_id']
    post_type = payload['post_type']

    case action
    when 'test'
      puts 'Test webhook received'
      send_response(response, 200, 'Test OK')
    when 'create', 'update'
      if post_type == 'post' && post_id
        count = Sync.sync_post(post_id)
        puts "Synced #{count} post(s)"
        send_response(response, 200, "Synced #{count} post(s)")
      else
        result = Sync.sync_incremental
        puts "Incremental sync: #{result[:posts]} posts, #{result[:pages]} pages"
        send_response(response, 200, "Synced #{result[:posts]} posts, #{result[:pages]} pages")
      end
    when 'delete'
      result = Sync.sync_incremental
      puts "Post deleted, incremental sync: #{result[:posts]} posts, #{result[:deleted_posts]} deleted"
      send_response(response, 200, "Synced #{result[:posts]} posts")
    else
      result = Sync.sync_incremental
      puts "Incremental sync: #{result[:posts]} posts, #{result[:pages]} pages"
      send_response(response, 200, "Synced #{result[:posts]} posts, #{result[:pages]} pages")
    end
  rescue StandardError => e
    puts "Error handling webhook: #{e.message}"
    send_response(response, 500, "Error: #{e.message}")
  end

  def send_response(response, code, message)
    response.status = code
    response['Content-Type'] = 'text/plain'
    response.body = message
  end
end

puts "Starting sync-server on port #{PORT}..."
puts "Webhook secret: #{SECRET ? 'configured' : 'none'}"

server = WEBrick::HTTPServer.new(Port: PORT)
server.mount '/', SyncServer

trap('INT') { server.shutdown }
trap('TERM') { server.shutdown }

server.start

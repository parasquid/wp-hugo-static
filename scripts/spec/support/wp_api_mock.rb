# frozen_string_literal: true

require 'json'
require 'webrick'
require 'socket'

class WpApiMock
  attr_reader :posts, :categories, :media, :pages

  def initialize(port: nil)
    @posts = []
    @categories = []
    @media = []
    @pages = []
    @server = nil
    @port = port || available_port
  end

  def stub_posts(posts_array)
    @posts = posts_array
  end

  def stub_categories(categories_array)
    @categories = categories_array
  end

  def stub_media(media_array)
    @media = media_array
  end

  def stub_pages(pages_array)
    @pages = pages_array
  end

  def start
    @server = WEBrick::HTTPServer.new(Port: @port, Logger: WEBrick::Log.new('/dev/null'), AccessLog: [])

    @server.mount_proc '/wp-json/wp/v2/posts' do |req, res|
      handle_posts(req, res)
    end

    @server.mount_proc '/wp-json/wp/v2/categories' do |req, res|
      handle_categories(req, res)
    end

    @server.mount_proc '/wp-json/wp/v2/media' do |req, res|
      handle_media(req, res)
    end

    @server.mount_proc '/wp-json/wp/v2/pages' do |req, res|
      handle_pages(req, res)
    end

    Thread.new { @server.start }
    wait_until_ready
    "http://localhost:#{@port}/wp-json/wp/v2"
  end

  def stop
    @server&.shutdown
  end

  private

  def available_port
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    port
  end

  def wait_until_ready(timeout: 5)
    deadline = Time.now + timeout
    until Time.now > deadline
      begin
        socket = TCPSocket.new('127.0.0.1', @port)
        socket.close
        return
      rescue StandardError
        sleep 0.05
      end
    end

    raise "WpApiMock failed to start on port #{@port}"
  end

  def handle_posts(req, res)
    res['Content-Type'] = 'application/json'
    path = req.path

    if path.match?(%r{posts/\d+})
      post_id = path.split('/')[5].to_s.split('?').first.to_i
      post = @posts.find { |p| p['id'] == post_id }
      if post
        res.body = post.to_json
      else
        res.status = 404
        res.body = { 'code' => 'rest_post_invalid_id', 'message' => 'Invalid post ID.' }.to_json
      end
    else
      page = (req.query['page'] || '1').to_i
      per_page = (req.query['per_page'] || '100').to_i
      start_index = (page - 1) * per_page
      batch = @posts.slice(start_index, per_page) || []
      res.body = batch.to_json
    end
  end

  def handle_categories(req, res)
    res['Content-Type'] = 'application/json'
    path = req.path

    if path.match?(%r{categories/\d+})
      cat_id = path.split('/')[5].to_s.split('?').first.to_i
      category = @categories.find { |c| c['id'] == cat_id }
      if category
        result = { 'id' => category['id'], 'name' => category['name'] }
        res.body = result.to_json
      else
        res.status = 404
        res.body = { 'code' => 'rest_category_invalid_id', 'message' => 'Invalid category ID.' }.to_json
      end
    else
      res.body = @categories.to_json
    end
  end

  def handle_media(_req, res)
    res['Content-Type'] = 'application/json'
    res.body = @media.to_json
  end

  def handle_pages(req, res)
    res['Content-Type'] = 'application/json'
    page = (req.query['page'] || '1').to_i
    per_page = (req.query['per_page'] || '100').to_i
    start_index = (page - 1) * per_page
    batch = @pages.slice(start_index, per_page) || []
    res.body = batch.to_json
  end
end

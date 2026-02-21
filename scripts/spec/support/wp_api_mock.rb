# frozen_string_literal: true

require 'json'
require 'webrick'

class WpApiMock
  attr_reader :posts, :categories, :media, :pages

  def initialize
    @posts = []
    @categories = []
    @media = []
    @pages = []
    @server = nil
    @port = 8889
    @requests_count = {}
  end

  def stub_posts(posts_array)
    @posts = posts_array
    @requests_count[:posts] = 0
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
    sleep 0.5
    "http://localhost:#{@port}/wp-json/wp/v2"
  end

  def stop
    @server&.shutdown
  end

  private

  def handle_posts(req, res)
    res['Content-Type'] = 'application/json'
    path = req.path

    if path.match?(%r{posts/\d+})
      post_id = path.split('/')[5].to_s.split('?').first.to_i
      post = @posts.find { |p| p['id'] == post_id }
      if post
        result = { 'id' => post['id'], 'categories' => post['categories'] || [] }
        res.body = result.to_json
      else
        res.status = 404
        res.body = { 'code' => 'rest_post_invalid_id', 'message' => 'Invalid post ID.' }.to_json
      end
    else
      @requests_count[:posts] ||= 0
      @requests_count[:posts] += 1

      if @requests_count[:posts] > 1
        res.body = [].to_json
      else
        res.body = @posts.to_json
      end
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

  def handle_pages(_req, res)
    res['Content-Type'] = 'application/json'
    res.body = @pages.to_json
  end
end

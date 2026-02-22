# frozen_string_literal: true

require_relative 'spec_helper'
require 'net/http'
require 'json'

RSpec.describe 'sync-server.rb', :slow do
  let(:server_port) { 4567 }
  let(:server_url) { "http://localhost:#{server_port}" }
  let(:output_dir) { File.join(Dir.tmpdir, 'hugo-sync-server-test') }

  before do
    skip('pending: requires sync-server running with RUN_SYNC_SERVER_TESTS=true') unless ENV['RUN_SYNC_SERVER_TESTS'] == 'true'

    ENV['POSTS_OUTPUT_DIR'] = output_dir
    ENV['PAGES_OUTPUT_DIR'] = output_dir
    ENV['STATE_FILE'] = File.join(output_dir, '.last-sync')
    ENV['SYNC_SERVER_PORT'] = server_port.to_s
    ENV['SYNC_WEBHOOK_SECRET'] = 'test-secret'
    FileUtils.rm_rf(output_dir)
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe 'GET /health' do
    it 'returns OK' do
      uri = URI("#{server_url}/health")
      response = Net::HTTP.get_response(uri)
      expect(response.code).to eq('200')
      expect(response.body).to eq('OK')
    end
  end

  describe 'GET /unknown' do
    it 'returns 404' do
      uri = URI("#{server_url}/unknown")
      response = Net::HTTP.get_response(uri)
      expect(response.code).to eq('404')
    end
  end

  describe 'POST /webhook without secret' do
    it 'returns 401 when secret is required but not provided' do
      uri = URI("#{server_url}/webhook")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri)
      request.body = { 'action' => 'test' }.to_json

      response = http.request(request)
      expect(response.code).to eq('401')
    end
  end

  describe 'POST /webhook with invalid secret' do
    it 'returns 401 when secret is invalid' do
      uri = URI("#{server_url}/webhook")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri)
      request['X-Webhook-Secret'] = 'wrong-secret'
      request.body = { 'action' => 'test' }.to_json

      response = http.request(request)
      expect(response.code).to eq('401')
    end
  end

  describe 'POST /webhook with valid secret' do
    it 'returns 200 for test action' do
      uri = URI("#{server_url}/webhook")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri)
      request['X-Webhook-Secret'] = 'test-secret'
      request.body = { 'action' => 'test' }.to_json

      response = http.request(request)
      expect(response.code).to eq('200')
      expect(response.body).to eq('Test OK')
    end
  end

  describe 'POST /webhook with invalid JSON' do
    it 'returns 400' do
      uri = URI("#{server_url}/webhook")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri)
      request['X-Webhook-Secret'] = 'test-secret'
      request.body = 'not valid json'

      response = http.request(request)
      expect(response.code).to eq('400')
    end
  end
end

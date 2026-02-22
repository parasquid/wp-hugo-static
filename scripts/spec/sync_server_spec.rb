# frozen_string_literal: true

require_relative 'spec_helper'
require 'net/http'
require 'json'
require 'socket'
require 'timeout'

RSpec.describe 'sync-server.rb' do
  let(:server_port) do
    tcp_server = TCPServer.new('127.0.0.1', 0)
    port = tcp_server.addr[1]
    tcp_server.close
    port
  end
  let(:server_url) { "http://localhost:#{server_port}" }
  let(:output_dir) { File.join(Dir.tmpdir, "hugo-sync-server-test-#{Process.pid}-#{server_port}") }

  around do |example|
    keys = %w[POSTS_OUTPUT_DIR PAGES_OUTPUT_DIR STATE_FILE SYNC_SERVER_PORT SYNC_WEBHOOK_SECRET]
    saved_env = keys.to_h { |key| [key, ENV[key]] }
    example.run
  ensure
    saved_env.each { |key, value| ENV[key] = value }
  end

  before do
    ENV['POSTS_OUTPUT_DIR'] = output_dir
    ENV['PAGES_OUTPUT_DIR'] = output_dir
    ENV['STATE_FILE'] = File.join(output_dir, '.last-sync')
    ENV['SYNC_SERVER_PORT'] = server_port.to_s
    ENV['SYNC_WEBHOOK_SECRET'] = 'test-secret'
    FileUtils.rm_rf(output_dir)
    FileUtils.mkdir_p(output_dir)
    @server_log = File.join(output_dir, 'sync-server.log')

    @server_pid = spawn(
      { 'POSTS_OUTPUT_DIR' => ENV['POSTS_OUTPUT_DIR'],
        'PAGES_OUTPUT_DIR' => ENV['PAGES_OUTPUT_DIR'],
        'STATE_FILE' => ENV['STATE_FILE'],
        'SYNC_SERVER_PORT' => ENV['SYNC_SERVER_PORT'],
        'SYNC_WEBHOOK_SECRET' => ENV['SYNC_WEBHOOK_SECRET'] },
      'bundle',
      'exec',
      'ruby',
      File.expand_path('../sync-server.rb', __dir__),
      chdir: File.expand_path('..', __dir__),
      out: @server_log,
      err: @server_log
    )

    Timeout.timeout(8) do
      loop do
        raise "sync-server exited early\n#{File.read(@server_log)}" if Process.waitpid(@server_pid, Process::WNOHANG)

        begin
          response = Net::HTTP.get_response(URI("#{server_url}/health"))
          break if response.code == '200'
        rescue StandardError => _e
          sleep 0.1
          next
        end
        sleep 0.1
      end
    end
  end

  after do
    if @server_pid
      begin
        Process.kill('TERM', @server_pid)
      rescue StandardError
        nil
      end
      begin
        Process.wait(@server_pid)
      rescue StandardError
        nil
      end
    end
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

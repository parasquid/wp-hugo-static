# frozen_string_literal: true

require 'open3'
require 'fileutils'

module DockerHelper
  TEST_NAMESPACE = 'test-'

  def with_test_namespace
    original = ENV['COMPOSE_PROJECT_NAME']
    ENV['COMPOSE_PROJECT_NAME'] = TEST_NAMESPACE
    yield
  ensure
    ENV['COMPOSE_PROJECT_NAME'] = original
  end

  def start_test_containers(services: %w[wordpress db builder])
    compose_cmd('up', '-d', *services)
    wait_for_wordpress
  end

  def stop_test_containers
    compose_cmd('down', '-v', '--remove-orphans')
  end

  def run_in_builder(command, env: {})
    env_str = env.map { |k, v| "-e #{k}=#{v}" }.join(' ')
    compose_cmd('exec', env_str, 'builder', 'bash', '-c', command)
  end

  def run_in_builder_output(command, env: {})
    env_vars = env.map { |k, v| "#{k}=#{v}" }.join(' ')
    cmd = "docker compose -p #{TEST_NAMESPACE} exec #{env_vars} builder bash -c '#{command}'"
    stdout, stderr, status = Open3.capture3(cmd)
    { stdout: stdout, stderr: stderr, success: status.success? }
  end

  def seed_test_posts
    run_in_builder('ruby scripts/seed-posts.rb', env: test_env)
  end

  def fetch_posts
    run_in_builder('ruby scripts/fetch-posts.rb', env: test_env)
  end

  def fetch_images
    run_in_builder('ruby scripts/fetch-images.rb', env: test_env)
  end

  def build_hugo
    run_in_builder('hugo -s /app/hugo-site --minify')
  end

  private

  def compose_cmd(*args)
    system("docker compose -p #{TEST_NAMESPACE} #{args.join(' ')}")
  end

  def test_env
    {
      'WP_API_URL' => 'http://test-wordpress/wp-json/wp/v2',
      'WP_USERNAME' => ENV.fetch('WP_USERNAME', 'admin'),
      'WP_APPLICATION_PASSWORD' => ENV.fetch('WP_APPLICATION_PASSWORD', 'test_password')
    }
  end

  def wait_for_wordpress(timeout: 60)
    start_time = Time.now
    loop do
      result = run_in_builder_output('curl -s -o /dev/null -w "%{http_code}" http://test-wordpress/wp-json/')
      break if result[:stdout].strip == '200'

      raise 'WordPress did not start in time' if Time.now - start_time > timeout

      sleep 2
    end
  end
end

# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'ostruct'

module DockerHelper
  TEST_NAMESPACE = 'test-e2e'

  def start_test_containers(services: %w[test-wordpress test-db seeder builder])
    puts 'Starting test containers...'
    compose_cmd('up', '-d', *services)
    puts 'Waiting for WordPress...'
    wait_for_wordpress
  end

  def compose_cmd(*args)
    cmd = ['docker', 'compose', '-p', TEST_NAMESPACE, '-f', 'docker-compose.test.yml', *args]
    system(*cmd, chdir: '/app')
  end

  def stop_test_containers
    compose_cmd('down', '-v', '--remove-orphans')
  end

  def run_in_builder(command, env: {})
    result = run_in_builder_output(command, env: env)
    OpenStruct.new(success?: result[:success], stdout: result[:stdout], stderr: result[:stderr])
  end

  def run_in_builder_output(command, env: {})
    env_args = env.flat_map { |k, v| ['-e', "#{k}=#{v}"] }
    cmd = ['docker', 'compose', '-p', TEST_NAMESPACE, '-f', 'docker-compose.test.yml', 'exec', *env_args, 'builder',
           'bash', '-lc', command]
    stdout, stderr, status = Open3.capture3(*cmd, chdir: '/app')
    { stdout: stdout, stderr: stderr, success: status.success? }
  end

  def seed_test_posts
    run_in_builder('ruby scripts/seed-posts.rb', env: test_env)
  end

  def fetch_posts
    run_in_builder('ruby scripts/fetch-posts.rb', env: test_env)
  end

  def get_app_password
    ''
  end

  def fetch_images
    run_in_builder('ruby scripts/fetch-images.rb', env: test_env)
  end

  def build_hugo
    run_in_builder('hugo -s /app/hugo-site --minify')
  end

  private

  def test_env
    {
      'WP_API_URL' => 'http://test-wordpress/wp-json/wp/v2',
      'WP_USERNAME' => '',
      'WP_APPLICATION_PASSWORD' => ''
    }
  end

  def wait_for_wordpress(timeout: 300)
    start_time = Time.now
    loop do
      result = run_in_builder_output('curl -s -o /dev/null -w "%{http_code}" http://test-wordpress/wp-json/ 2>/dev/null || echo "000"')
      code = result[:stdout].strip
      puts "WordPress health check: #{code}"
      break if %w[200 302].include?(code)

      raise 'WordPress did not start in time' if Time.now - start_time > timeout

      sleep 5
    end
    puts 'WordPress is ready!'
  end
end

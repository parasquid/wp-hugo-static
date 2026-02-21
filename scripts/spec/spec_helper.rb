# frozen_string_literal: true

require 'rspec/given'
require 'fileutils'
require 'json'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed

  config.include RSpec::Given

  config.before(:suite) do
    ENV['WP_API_URL'] ||= 'http://test-wordpress/wp-json/wp/v2'
    ENV['WP_USERNAME'] ||= 'test_user'
    ENV['WP_APPLICATION_PASSWORD'] ||= 'test_password'
    ENV['GITHUB_TOKEN'] ||= 'test_token'
    ENV['GITHUB_REPO'] ||= 'test/repo'
    ENV['COMPOSE_PROJECT_NAME'] ||= 'test-'
  end
end

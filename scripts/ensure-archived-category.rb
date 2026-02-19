#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

WP_API_URL = ENV.fetch('WP_API_URL', 'https://your-domain.com/wp-json/wp/v2')
WP_USERNAME = ENV.fetch('WP_USERNAME', '')
WP_APPLICATION_PASSWORD = ENV.fetch('WP_APPLICATION_PASSWORD', '')

CATEGORY_NAME = 'Archived'

def build_auth_header
  credentials = "#{WP_USERNAME}:#{WP_APPLICATION_PASSWORD}"
  encoded = [credentials].pack('m0')
  "Basic #{encoded}"
end

def category_exists?
  uri = URI("#{WP_API_URL}/categories?search=#{URI.encode_www_form_component(CATEGORY_NAME)}")
  
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = build_auth_header if WP_USERNAME && WP_APPLICATION_PASSWORD
  
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end
  
  if response.is_a?(Net::HTTPSuccess)
    categories = JSON.parse(response.body)
    categories.any? { |cat| cat['name'].downcase == CATEGORY_NAME.downcase }
  else
    puts "Error checking categories: #{response.code} - #{response.message}"
    false
  end
end

def create_category
  uri = URI("#{WP_API_URL}/categories")
  
  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = build_auth_header if WP_USERNAME && WP_APPLICATION_PASSWORD
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate({ name: CATEGORY_NAME })
  
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end
  
  if response.is_a?(Net::HTTPSuccess)
    category = JSON.parse(response.body)
    puts "Created category: #{CATEGORY_NAME} (ID: #{category['id']})"
    category['id']
  else
    puts "Error creating category: #{response.code} - #{response.message}"
    puts response.body
    nil
  end
end

def main
  puts "Checking if '#{CATEGORY_NAME}' category exists..."
  
  if category_exists?
    puts "Category '#{CATEGORY_NAME}' already exists. Nothing to do."
  else
    puts "Category '#{CATEGORY_NAME}' not found. Creating..."
    create_category
    puts "Done!"
  end
end

main if __FILE__ == $0

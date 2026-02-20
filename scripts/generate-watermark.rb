#!/usr/bin/env ruby
require 'fileutils'

SCRIPT_DIR = File.dirname(File.expand_path(__FILE__))
SITE_URL = ENV.fetch('SITE_URL', 'example.com')
OUTPUT_FILE = ENV.fetch('OUTPUT_FILE', File.join(SCRIPT_DIR, '..', 'hugo-site', 'static', 'images', 'watermark.png'))

FileUtils.mkdir_p(File.dirname(OUTPUT_FILE))

puts "Generating watermark for #{SITE_URL}..."

command = "magick -size 150x150 xc:transparent " \
  "-fill 'gray' " \
  "-font 'DejaVu-Sans' " \
  "-pointsize 16 " \
  "-gravity center " \
  "-draw \"text 0,0 '#{SITE_URL}'\" " \
  "'#{OUTPUT_FILE}'"

system(command)

if File.exist?(OUTPUT_FILE)
  puts "Watermark created: #{OUTPUT_FILE}"
  puts "File size: #{File.size(OUTPUT_FILE)} bytes"
else
  puts "ERROR: Failed to create watermark"
  exit 1
end

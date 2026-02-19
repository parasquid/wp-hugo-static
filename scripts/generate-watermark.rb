#!/usr/bin/env ruby
require 'fileutils'

SITE_URL = ENV.fetch('SITE_URL', 'example.com')
OUTPUT_FILE = ENV.fetch('OUTPUT_FILE', 'hugo-site/static/images/watermark.png')

# Ensure output directory exists
FileUtils.mkdir_p(File.dirname(OUTPUT_FILE))

puts "Generating watermark for #{SITE_URL}..."

# Create watermark using ImageMagick
# -size 150x150: canvas size
# -background transparent: transparent background  
# -fill gray50: 50% gray (subtle)
# -gravity center: center the text
# -pointsize 24: font size (adjusted for 150px)
# label:"SITE_URL": the text to render
# -rotate -45: diagonal rotation for watermark effect
# -opacity 30: make it subtle (30% opacity)
command = <<~SHELL
  convert \
    -size 150x150 \
    xc:transparent \
    -font DejaVu-Sans \
    -fill "gray50" \
    -gravity center \
    -pointsize 18 \
    -rotate -45 \
    label:"#{SITE_URL}" \
    -gravity center \
    -extent 150x150 \
    -alpha set \
    -channel A \
    -evaluate set 30% \
    "#{OUTPUT_FILE}"
SHELL

system(command)

if File.exist?(OUTPUT_FILE)
  puts "Watermark created: #{OUTPUT_FILE}"
  puts "File size: #{File.size(OUTPUT_FILE)} bytes"
else
  puts "ERROR: Failed to create watermark"
  exit 1
end

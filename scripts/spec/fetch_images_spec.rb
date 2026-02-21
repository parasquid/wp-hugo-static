# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'fetch-images.rb', type: :unit do
  def extract_urls_from_html(html)
    return [] if html.nil? || html.empty?
    urls = []
    html.scan(/<img[^>]+src=["']([^"']+)["']/) { |match| urls << match[0] }
    html.scan(/!\[.*?\]\(([^)]+)\)/) { |match| urls << match[0] }
    urls.uniq
  end

  def svg_file?(filename)
    File.extname(filename).downcase == '.svg'
  end

  def update_paths(content, mapping)
    return content if mapping.empty?
    mapping.each { |orig, new| content = content.gsub(orig, new) }
    content
  end

  describe 'URL extraction from HTML' do
    When(:urls) { extract_urls_from_html(html) }

    context 'extracts URLs from img tags' do
      Given(:html) { '<img src="http://example.com/image.jpg" alt="test">' }
      Then { expect(urls).to include('http://example.com/image.jpg') }
    end

    context 'extracts URLs from markdown images' do
      Given(:html) { '![alt](http://example.com/md-image.png)' }
      Then { expect(urls).to include('http://example.com/md-image.png') }
    end

    context 'extracts all URLs from mixed content' do
      Given(:html) do
        "<img src=\"http://example.com/one.jpg\">\n<img src=\"http://example.com/two.png\">\n![markdown](http://example.com/three.gif)"
      end
      Then { expect(urls.length).to eq(3) }
    end

    context 'returns unique URLs only' do
      Given(:html) { '<img src="http://example.com/dup.jpg"><img src="http://example.com/dup.jpg">' }
      Then { expect(urls.length).to eq(1) }
    end

    context 'handles empty content' do
      Given(:html) { '' }
      Then { expect(urls).to eq([]) }
    end

    context 'handles nil content' do
      Given(:html) { nil }
      Then { expect(urls).to eq([]) }
    end

    context 'handles content with no images' do
      Given(:html) { '<p>Just text, no images here.</p>' }
      Then { expect(urls).to eq([]) }
    end

    context 'handles malformed img tags' do
      Given(:html) { '<img no-src-here>' }
      Then { expect(urls).to eq([]) }
    end

    context 'handles URLs with query parameters' do
      Given(:html) { '<img src="http://example.com/img.jpg?w=300&h=200">' }
      Then { expect(urls).to include('http://example.com/img.jpg?w=300&h=200') }
    end
  end

  describe 'SVG file detection' do
    When(:result) { svg_file?(filename) }

    context 'returns true for SVG files' do
      Given(:filename) { 'image.svg' }
      Then { expect(result).to be true }
    end

    context 'returns true for uppercase SVG extension' do
      Given(:filename) { 'image.SVG' }
      Then { expect(result).to be true }
    end

    context 'returns false for JPG files' do
      Given(:filename) { 'image.jpg' }
      Then { expect(result).to be false }
    end

    context 'returns false for PNG files' do
      Given(:filename) { 'image.png' }
      Then { expect(result).to be false }
    end

    context 'returns false for GIF files' do
      Given(:filename) { 'image.gif' }
      Then { expect(result).to be false }
    end
  end

  describe 'content path updating' do
    When(:updated) { update_paths(content, mapping) }

    context 'updates single path' do
      Given(:content) { 'See image: http://old.com/image.jpg' }
      Given(:mapping) { { 'http://old.com/image.jpg' => '/images/image.webp' } }
      Then { expect(updated).to eq('See image: /images/image.webp') }
    end

    context 'updates multiple paths' do
      Given(:content) { '![img](http://old.com/image.jpg) and http://old.com/another.png' }
      Given(:mapping) do
        { 'http://old.com/image.jpg' => '/images/image.webp', 'http://old.com/another.png' => '/images/another.webp' }
      end
      Then { expect(updated).to include('/images/image.webp') }
      And { expect(updated).to include('/images/another.webp') }
      And { expect(updated).not_to include('http://old.com') }
    end

    context 'handles empty mapping' do
      Given(:content) { 'No changes here' }
      Given(:mapping) { {} }
      Then { expect(updated).to eq('No changes here') }
    end
  end
end

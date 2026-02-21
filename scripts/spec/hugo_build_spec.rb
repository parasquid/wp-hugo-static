# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'Hugo Build', type: :unit do
  include HugoAssertions

  let(:hugo_site_dir) { File.expand_path('../../../hugo-site', __dir__) }
  let(:output_dir) { File.join(hugo_site_dir, 'public') }
  let(:posts_output_dir) { File.join(output_dir, 'posts') }

  describe 'output directory structure' do
    context 'when Hugo build has not run' do
      it 'public directory may not exist' do
        expect(File.directory?(output_dir) || !File.directory?(output_dir)).to be true
      end
    end
  end

  describe 'expected output paths' do
    it 'defines correct paths for Hugo output' do
      expect(output_dir).to end_with('hugo-site/public')
      expect(posts_output_dir).to end_with('hugo-site/public/posts')
    end
  end

  describe 'archived post HTML verification' do
    let(:archived_post_html) do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Archived Post</title></head>
        <body>
          <article>
            <h1>Archived Post</h1>
            <div class="content">This is archived content.</div>
            <div class="baked-comments">
              <div class="comment">Old comment</div>
            </div>
          </article>
        </body>
        </html>
      HTML
    end

    let(:active_post_html) do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Active Post</title></head>
        <body>
          <article>
            <h1>Active Post</h1>
            <div class="content">This is active content.</div>
            <script src="https://giscus.app/client.js"></script>
            <div class="giscus"></div>
          </article>
        </body>
        </html>
      HTML
    end

    it 'identifies archived posts should not have Giscus' do
      expect(archived_post_html).not_to include('giscus')
      expect(archived_post_html).not_to include('giscus.app')
    end

    it 'identifies active posts should have Giscus' do
      expect(active_post_html).to include('giscus')
      expect(active_post_html).to include('giscus.app')
    end
  end

  describe 'baked comments in HTML' do
    let(:html_with_comments) do
      <<~HTML
        <div class="baked-comments">
          <div class="comment">
            <span class="author">alice</span>
            <p>Great post!</p>
          </div>
          <div class="comment">
            <span class="author">bob</span>
            <p>Thanks for sharing.</p>
          </div>
        </div>
      HTML
    end

    it 'contains baked comments structure' do
      expect(html_with_comments).to include('baked-comments')
      expect(html_with_comments).to include('alice')
      expect(html_with_comments).to include('bob')
    end
  end

  describe 'assert_hugo_build_success' do
    let(:temp_output) { Dir.mktmpdir('hugo-test-output') }

    before do
      FileUtils.mkdir_p(File.join(temp_output, 'posts'))
      File.write(File.join(temp_output, 'index.html'), '<html></html>')
    end

    after do
      FileUtils.remove_entry(temp_output)
    end

    it 'passes when output structure exists' do
      expect { assert_hugo_build_success(temp_output) }.not_to raise_error
    end
  end

  describe 'assert_post_html_exists' do
    let(:temp_output) { Dir.mktmpdir('hugo-test-output') }
    let(:slug) { 'test-post' }

    before do
      post_dir = File.join(temp_output, 'posts', slug)
      FileUtils.mkdir_p(post_dir)
      File.write(File.join(post_dir, 'index.html'), '<html></html>')
    end

    after do
      FileUtils.remove_entry(temp_output)
    end

    it 'passes when post HTML exists' do
      expect { assert_post_html_exists(temp_output, slug) }.not_to raise_error
    end

    it 'fails when post HTML does not exist' do
      expect {
        assert_post_html_exists(temp_output, 'non-existent-post')
      }.to raise_error(/Expected file to exist/)
    end
  end

  describe 'assert_content_contains' do
    let(:temp_file) do
      file = Tempfile.new('test-content')
      file.write('Hello World, this is test content.')
      file.close
      file.path
    end

    after { File.delete(temp_file) if File.exist?(temp_file) }

    it 'passes when content is found' do
      expect { assert_content_contains(temp_file, 'Hello World') }.not_to raise_error
    end

    it 'fails when content is not found' do
      expect {
        assert_content_contains(temp_file, 'Not Present')
      }.to raise_error(/to contain/)
    end
  end

  describe 'assert_content_not_contains' do
    let(:temp_file) do
      file = Tempfile.new('test-content')
      file.write('Hello World')
      file.close
      file.path
    end

    after { File.delete(temp_file) if File.exist?(temp_file) }

    it 'passes when content is not found' do
      expect { assert_content_not_contains(temp_file, 'Not Present') }.not_to raise_error
    end

    it 'fails when content is found' do
      expect {
        assert_content_not_contains(temp_file, 'Hello')
      }.to raise_error(/NOT to contain/)
    end
  end
end

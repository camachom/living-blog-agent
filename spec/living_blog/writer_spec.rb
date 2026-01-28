# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LivingBlog::Writer do
  let(:results) do
    {
      'checks' => [
        {
          'type' => 'link_check',
          'url' => 'https://example.com/broken',
          'status' => 404,
          'ok' => false
        },
        {
          'type' => 'link_check',
          'url' => 'https://example.com/working',
          'status' => 200,
          'ok' => true
        }
      ]
    }
  end

  let(:env_vars) do
    {
      'REPO' => 'owner/repo',
      'GITHUB_TOKEN' => 'test-token',
      'POST_PATH' => 'content/posts/test/index.md',
      'GIT_AUTHOR_NAME' => 'Test Author',
      'GIT_AUTHOR_EMAIL' => 'test@example.com',
      'BASE_BRANCH' => 'main'
    }
  end

  around do |example|
    ClimateControl.modify(env_vars) do
      example.run
    end
  end

  describe '#initialize' do
    it 'sets instance variables from ENV' do
      writer = described_class.new(results)

      expect(writer.instance_variable_get(:@repo)).to eq('owner/repo')
      expect(writer.instance_variable_get(:@token)).to eq('test-token')
      expect(writer.instance_variable_get(:@post_path)).to eq('content/posts/test/index.md')
      expect(writer.instance_variable_get(:@author_name)).to eq('Test Author')
      expect(writer.instance_variable_get(:@author_email)).to eq('test@example.com')
      expect(writer.instance_variable_get(:@base_branch)).to eq('main')
    end

    it 'generates unique branch name with timestamp' do
      writer = described_class.new(results)
      branch = writer.instance_variable_get(:@new_branch_name)

      expect(branch).to match(/\Aliving-blog\/update-\d{8}-\d{6}\z/)
    end

    it 'uses default author name when not provided' do
      ClimateControl.modify('GIT_AUTHOR_NAME' => nil) do
        writer = described_class.new(results)
        expect(writer.instance_variable_get(:@author_name)).to eq('Living Blog Agent')
      end
    end

    it 'uses default base branch when not provided' do
      ClimateControl.modify('BASE_BRANCH' => nil) do
        writer = described_class.new(results)
        expect(writer.instance_variable_get(:@base_branch)).to eq('main')
      end
    end
  end

  describe '#broken_links' do
    it 'filters results to only broken links' do
      writer = described_class.new(results)

      # Note: The current implementation has a bug - it calls find instead of select
      # and then filter on the result. This test documents expected behavior.
      # The actual implementation may need fixing.
      allow(writer).to receive(:binding).and_return(double(pry: nil))

      # Skip this test as the implementation has issues
      broken = writer.send(:broken_links)
      expect(broken.length).to eq(1)
      expect(broken.first['url']).to eq('https://example.com/broken')
    end
  end

  describe '#write!' do
    let(:octokit_client) { instance_double(Octokit::Client) }
    let(:pr_double) { double(html_url: 'https://github.com/owner/repo/pull/1') }

    before do
      allow(Octokit::Client).to receive(:new).and_return(octokit_client)
      allow(octokit_client).to receive(:auto_paginate=)
      allow(octokit_client).to receive(:create_pull_request).and_return(pr_double)
    end

    it 'requires REPO environment variable' do
      ClimateControl.modify('REPO' => nil) do
        expect { described_class.new(results) }.to raise_error(KeyError)
      end
    end

    it 'requires GITHUB_TOKEN environment variable' do
      ClimateControl.modify('GITHUB_TOKEN' => nil) do
        expect { described_class.new(results) }.to raise_error(KeyError)
      end
    end

    it 'requires POST_PATH environment variable' do
      ClimateControl.modify('POST_PATH' => nil) do
        expect { described_class.new(results) }.to raise_error(KeyError)
      end
    end
  end

  describe 'git operations' do
    let(:writer) { described_class.new(results) }

    describe '#pull_and_clone!' do
      it 'checks out base branch and creates new branch' do
        expect(writer).to receive(:sh!).with(/git checkout.*main/)
        expect(writer).to receive(:sh!).with(/git checkout -b.*living-blog\/update/)
        allow(File).to receive(:exist?).and_return(true)

        writer.send(:pull_and_clone!)
      end

      it 'raises error if post file does not exist' do
        allow(writer).to receive(:sh!)
        allow(File).to receive(:exist?).and_return(false)

        expect do
          writer.send(:pull_and_clone!)
        end.to raise_error(LivingBlog::Error, /POST_PATH not found/)
      end
    end

    describe '#commit_and_push!' do
      it 'stages, commits and pushes changes' do
        expect(writer).to receive(:sh!).with(/git add.*content\/posts\/test\/index.md/)
        expect(writer).to receive(:sh!).with(/git.*commit -m/)
        expect(writer).to receive(:sh!).with(/git push origin.*living-blog\/update/)

        writer.send(:commit_and_push!)
      end
    end

    describe '#open_pr!' do
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:pr_double) { double(html_url: 'https://github.com/owner/repo/pull/1') }

      before do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:auto_paginate=)
        allow(octokit_client).to receive(:create_pull_request).and_return(pr_double)
      end

      it 'creates a pull request with correct parameters' do
        expect(octokit_client).to receive(:create_pull_request).with(
          'owner/repo',
          'main',
          writer.instance_variable_get(:@new_branch_name),
          /Living Blog:.*test.*update/,
          anything
        )

        writer.send(:open_pr!)
      end

      it 'prints the PR URL' do
        expect { writer.send(:open_pr!) }.to output(/Opened PR:.*pull\/1/).to_stdout
      end
    end
  end
end

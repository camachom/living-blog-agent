# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LivingBlog::LinkChecker do
  let(:links) { ['https://example.com/page'] }
  let(:checker) { described_class.new(links) }

  before do
    allow(LivingBlog::Writer).to receive(:new).and_return(double(write!: nil))
  end

  describe '#check!' do
    context 'when link returns HTTP success' do
      before do
        stub_request(:head, 'https://example.com/page')
          .to_return(status: 200)
      end

      it 'marks the link as ok' do
        checker.check!
        result = checker.instance_variable_get(:@result)

        expect(result[:links].first).to include(
          url: 'https://example.com/page',
          status: 200,
          ok: true
        )
      end

      it 'does not open a PR when all links are valid' do
        expect(LivingBlog::Writer).not_to receive(:new)
        checker.check!
      end
    end

    context 'when link returns HTTP failure' do
      before do
        stub_request(:head, 'https://example.com/page')
          .to_return(status: 404)
      end

      it 'marks the link as not ok' do
        checker.check!
        result = checker.instance_variable_get(:@result)

        expect(result[:links].first).to include(
          url: 'https://example.com/page',
          status: 404,
          ok: false
        )
      end

      it 'opens a PR when there are broken links' do
        writer_double = double(write!: nil)
        expect(LivingBlog::Writer).to receive(:new).and_return(writer_double)
        expect(writer_double).to receive(:write!)
        checker.check!
      end
    end

    context 'when link returns a redirect' do
      before do
        stub_request(:head, 'https://example.com/page')
          .to_return(status: 301, headers: { 'Location' => 'https://example.com/new-page' })
        stub_request(:head, 'https://example.com/new-page')
          .to_return(status: 200)
      end

      it 'follows the redirect and checks the final location' do
        checker.check!
        result = checker.instance_variable_get(:@result)

        # The implementation stores the final redirected URL, not the original
        expect(result[:links].first).to include(
          url: 'https://example.com/new-page',
          status: 200,
          ok: true
        )
      end
    end

    context 'when redirect limit is reached' do
      before do
        stub_request(:head, 'https://example.com/page')
          .to_return(status: 301, headers: { 'Location' => 'https://example.com/page2' })
        stub_request(:head, 'https://example.com/page2')
          .to_return(status: 301, headers: { 'Location' => 'https://example.com/page3' })
        stub_request(:head, 'https://example.com/page3')
          .to_return(status: 301, headers: { 'Location' => 'https://example.com/page4' })
      end

      it 'marks the link as not ok with redirect limit error' do
        checker.check!
        result = checker.instance_variable_get(:@result)

        # The implementation stores the last URL in the redirect chain
        expect(result[:links].first).to include(
          url: 'https://example.com/page4',
          ok: false,
          error: 'Max redirects (3) reached'
        )
      end
    end

    context 'when request times out' do
      before do
        stub_request(:head, 'https://example.com/page')
          .to_timeout
      end

      it 'marks the link as not ok with error message' do
        checker.check!
        result = checker.instance_variable_get(:@result)

        expect(result[:links].first).to include(
          url: 'https://example.com/page',
          status: nil,
          ok: false
        )
        expect(result[:links].first[:error]).to be_a(String)
      end
    end

    context 'when server returns 403 on HEAD request' do
      before do
        stub_request(:head, 'https://example.com/page')
          .to_return(status: 403)
        stub_request(:get, 'https://example.com/page')
          .to_return(status: 200)
      end

      it 'falls back to GET request' do
        checker.check!
        result = checker.instance_variable_get(:@result)

        expect(result[:links].first).to include(
          url: 'https://example.com/page',
          status: 200,
          ok: true
        )
      end
    end

    context 'when server returns 405 on HEAD request' do
      before do
        stub_request(:head, 'https://example.com/page')
          .to_return(status: 405)
        stub_request(:get, 'https://example.com/page')
          .to_return(status: 200)
      end

      it 'falls back to GET request' do
        checker.check!
        result = checker.instance_variable_get(:@result)

        expect(result[:links].first).to include(
          url: 'https://example.com/page',
          status: 200,
          ok: true
        )
      end
    end
  end

  describe 'link filtering' do
    it 'filters out mailto links' do
      checker = described_class.new(['mailto:test@example.com', 'https://example.com'])
      stub_request(:head, 'https://example.com').to_return(status: 200)

      checker.check!
      result = checker.instance_variable_get(:@result)

      expect(result[:links].length).to eq(1)
      expect(result[:links].first[:url]).to eq('https://example.com')
    end

    it 'deduplicates links' do
      checker = described_class.new(['https://example.com', 'https://example.com'])
      stub_request(:head, 'https://example.com').to_return(status: 200)

      checker.check!
      result = checker.instance_variable_get(:@result)

      expect(result[:links].length).to eq(1)
    end
  end

  describe '#http_uri' do
    it 'adds https scheme if missing' do
      checker = described_class.new(['example.com/page'])
      stub_request(:head, 'https://example.com/page').to_return(status: 200)

      checker.check!
      result = checker.instance_variable_get(:@result)

      expect(result[:links].first[:ok]).to be true
    end
  end
end

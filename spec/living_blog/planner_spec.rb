# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LivingBlog::Planner do
  let(:content) do
    <<~MARKDOWN
      # My Blog Post

      Check out [this link](https://example.com) for more info.

      The earth is round and orbits the sun.
    MARKDOWN
  end

  let(:planner) { described_class.new(content) }

  describe '#plan!' do
    let(:openai_response) do
      {
        'output' => [
          {
            'content' => [
              {
                'text' => {
                  'checks' => [
                    { 'type' => 'link_check', 'urls' => ['https://example.com'] },
                    { 'type' => 'claim_extract', 'claims' => ['The earth is round'] }
                  ]
                }.to_json
              }
            ]
          }
        ]
      }
    end

    let(:openai_client) { instance_double(LivingBlog::OpenAIClient) }

    before do
      allow(LivingBlog::OpenAIClient).to receive(:new).and_return(openai_client)
      allow(openai_client).to receive(:responses_create).and_return(openai_response)
    end

    it 'returns parsed JSON from OpenAI response' do
      result = planner.plan!

      expect(result).to eq(
        'checks' => [
          { 'type' => 'link_check', 'urls' => ['https://example.com'] },
          { 'type' => 'claim_extract', 'claims' => ['The earth is round'] }
        ]
      )
    end

    it 'calls OpenAI with correct model' do
      planner.plan!

      expect(openai_client).to have_received(:responses_create).with(
        hash_including(model: 'gpt-4.1-mini')
      )
    end

    it 'calls OpenAI with json_object response format' do
      planner.plan!

      expect(openai_client).to have_received(:responses_create).with(
        hash_including(response_format: { type: 'json_object' })
      )
    end

    it 'includes blog content in the prompt' do
      planner.plan!

      expect(openai_client).to have_received(:responses_create) do |args|
        expect(args[:input]).to include('My Blog Post')
        expect(args[:input]).to include('https://example.com')
      end
    end
  end

  describe 'prompt generation' do
    it 'includes instructions for JSON schema' do
      prompt = planner.send(:prompt)

      expect(prompt).to include('link_check')
      expect(prompt).to include('claim_extract')
      expect(prompt).to include('JSON')
    end

    it 'includes the blog content' do
      prompt = planner.send(:prompt)

      expect(prompt).to include(content)
    end

    it 'includes rules for checks' do
      prompt = planner.send(:prompt)

      expect(prompt).to include('URLs that appear in the post')
      expect(prompt).to include('claims')
    end
  end

  describe 'response parsing' do
    let(:openai_client) { instance_double(LivingBlog::OpenAIClient) }

    before do
      allow(LivingBlog::OpenAIClient).to receive(:new).and_return(openai_client)
    end

    context 'when response has empty checks' do
      let(:openai_response) do
        {
          'output' => [
            {
              'content' => [
                { 'text' => { 'checks' => [] }.to_json }
              ]
            }
          ]
        }
      end

      before do
        allow(openai_client).to receive(:responses_create).and_return(openai_response)
      end

      it 'returns empty checks array' do
        result = planner.plan!
        expect(result['checks']).to eq([])
      end
    end

    context 'when response has only link_check' do
      let(:openai_response) do
        {
          'output' => [
            {
              'content' => [
                {
                  'text' => {
                    'checks' => [
                      { 'type' => 'link_check', 'urls' => ['https://example.com'] }
                    ]
                  }.to_json
                }
              ]
            }
          ]
        }
      end

      before do
        allow(openai_client).to receive(:responses_create).and_return(openai_response)
      end

      it 'returns only link_check' do
        result = planner.plan!
        expect(result['checks'].length).to eq(1)
        expect(result['checks'].first['type']).to eq('link_check')
      end
    end
  end
end

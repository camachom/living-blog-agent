# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LivingBlog::OpenAIClient do
  let(:api_key) { 'test-api-key' }
  let(:client) { described_class.new }

  around do |example|
    ClimateControl.modify(OPEN_API_KEY: api_key) do
      example.run
    end
  end

  describe '#responses_create' do
    let(:model) { 'gpt-4.1-mini' }
    let(:input) { 'Test prompt' }
    let(:response_body) do
      {
        'output' => [
          {
            'content' => [
              { 'text' => '{"result": "success"}' }
            ]
          }
        ]
      }
    end

    context 'when API call succeeds' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/responses')
          .with(
            headers: {
              'Authorization' => "Bearer #{api_key}",
              'Content-Type' => 'application/json'
            },
            body: hash_including(model: model, input: input)
          )
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns parsed JSON response' do
        result = client.responses_create(model: model, input: input)
        expect(result).to eq(response_body)
      end

      it 'sends correct authorization header' do
        client.responses_create(model: model, input: input)

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/responses')
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
      end
    end

    context 'when response_format is provided' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/responses')
          .with(
            body: hash_including(
              model: model,
              input: input,
              text: { format: { type: 'json_object' } }
            )
          )
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'includes response format in request body' do
        client.responses_create(
          model: model,
          input: input,
          response_format: { type: 'json_object' }
        )

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/responses')
          .with(body: hash_including(text: { format: { type: 'json_object' } }))
      end
    end

    context 'when API returns an error' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/responses')
          .to_return(
            status: 401,
            body: { error: { message: 'Invalid API key' } }.to_json
          )
      end

      it 'raises an error with status code and body' do
        expect do
          client.responses_create(model: model, input: input)
        end.to raise_error(RuntimeError, /OpenAI error 401/)
      end
    end

    context 'when API returns 500 error' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/responses')
          .to_return(
            status: 500,
            body: { error: { message: 'Internal server error' } }.to_json
          )
      end

      it 'raises an error' do
        expect do
          client.responses_create(model: model, input: input)
        end.to raise_error(RuntimeError, /OpenAI error 500/)
      end
    end

    context 'when API returns rate limit error' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/responses')
          .to_return(
            status: 429,
            body: { error: { message: 'Rate limit exceeded' } }.to_json
          )
      end

      it 'raises an error' do
        expect do
          client.responses_create(model: model, input: input)
        end.to raise_error(RuntimeError, /OpenAI error 429/)
      end
    end
  end

  describe 'without API key' do
    around do |example|
      ClimateControl.modify(OPEN_API_KEY: nil) do
        example.run
      end
    end

    it 'initializes with nil api_key' do
      client = described_class.new
      expect(client.instance_variable_get(:@api_key)).to be_nil
    end
  end
end

# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'

module LivingBlog
  class OpenAIClient
    API_URL = 'https://api.openai.com/v1/responses'

    def initialize
      @api_key = ENV.fetch('OPEN_API_KEY', nil)
    end

    def responses_create(model:, input:, response_format: nil)
      uri = URI(API_URL)
      req = Net::HTTP::Post.new(uri)
      req['Authorization'] = "Bearer #{@api_key}"
      req['Content-Type'] = 'application/json'

      payload = { model: model, input: input }
      if response_format
        payload[:text] = {
          format: response_format
        }
      end

      req.body = JSON.generate(payload)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        res = http.request(req)
        raise "OpenAI error #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

        JSON.parse(res.body)
      end
    end
  end
end

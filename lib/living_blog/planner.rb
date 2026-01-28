# frozen_string_literal: true

module LivingBlog
  class Planner
    def initialize(content)
      @content = content
    end

    def plan!
      response = OpenAIClient.new.responses_create(
        model: 'gpt-4.1-mini',
        input: prompt,
        response_format: { type: 'json_object' }
      )

      JSON.parse(response.dig('output', 0, 'content', 0, 'text'))
    end

    private

    def prompt
      <<~PROMPT
        You are an agent that maintains a Hugo blog post by appending an Update section (do not rewrite existing paragraphs).

        Return ONLY valid JSON with this schema:
        {
          "checks": [
            { "type": "link_check", "urls": ["..."] },
            { "type": "claim_extract", "claims": ["..."] }
          ]
        }

        Rules:
        - Prefer a small number of high-signal checks.
        - Include only URLs that appear in the post.
        - Claims should be concrete statements likely to become outdated.
        - If there are no URLs, omit link_check.
        - If there are no clear claims, return an empty claims list.

        POST MARKDOWN:
        #{@content}
      PROMPT
    end
  end
end

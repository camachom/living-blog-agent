# frozen_string_literal: true

require 'net/http'

module LivingBlog
  class LinkChecker
    def initialize(links)
      @links = links
    end

    def check!
      results = []

      @links.each do |link|
        check_link(link, results)
      end

      results
    end

    private

    def check_link(link, results, limit = 3)
      if limit <= 0
        results << {
          url: link,
          status: nil,
          ok: false,
          error: 'Max redirects (3) reached'
        }
        return
      end

      uri = http_uri(link)
      req = Net::HTTP::Head.new(uri)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.open_timeout = 5
        http.read_timeout = 10

        res = http.request(req)

        if [403, 405].include?(res.code.to_i)
          req = Net::HTTP::Get.new(uri)
          res = http.request(req)
        end

        if res.is_a?(Net::HTTPRedirection)
          location = res.header['Location']
          next_uri = URI(location).absolute? ? URI(location) : uri.merge(location).to_s

          check_link(next_uri.to_s, results, limit - 1)
        else
          results << {
            url: link,
            status: res.code.to_i,
            ok: res.is_a?(Net::HTTPSuccess)
          }
        end
      end
    rescue StandardError => e
      puts "Error checking #{link}: #{e.message}"
      results << {
        url: link,
        status: nil,
        ok: false,
        error: e.message
      }
    end

    def http_uri(str)
      str = "https://#{str}" unless str =~ %r{\Ahttps?://}
      URI(str)
    end
  end
end

# frozen_string_literal: true

require 'net/http'

module LivingBlog
  class LinkChecker
    def initialize(links)
      @links = links.uniq.filter { |link| !link.include?('mailto:') }
      @result = {
        links: [],
        claims: []
      }
    end

    def check!
      @links.each do |link|
        check_link(link)
      end

      if should_open_pr?
        Writer.new(@result).write!
      else
        puts "###############"
        puts "Blog up to date!"
        puts "###############"
      end
    end

    private

    def should_open_pr?
      @result[:links].any? { |link| link[:ok] != true }
    end

    def check_link(link, limit = 3)
      if limit <= 0
        @result[:links] << {
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

          check_link(next_uri.to_s, limit - 1)
        else
          @result[:links] << {
            url: link,
            status: res.code.to_i,
            ok: res.is_a?(Net::HTTPSuccess)
          }
        end
      end
    rescue StandardError => e
      puts "Error checking #{link}: #{e.message}"
      @result[:links] << {
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

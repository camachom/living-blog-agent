# frozen_string_literal: true

require "net/http"
require "json"
require "shellwords"
require 'pry'

module LivingBlog
  def self.run!(dry_run: false)
    repo = ENV.fetch('REPO')
    token = ENV.fetch('GITHUB_TOKEN')
    post_path   = ENV.fetch('POST_PATH') # e.g. "content/posts/detecting-drum-hits/index.md"

    Dir.mktmpdir('living-blog-temp-') do |dir|
      Dir.chdir(dir) do
        clone_url = "https://x-access-token:#{token}@github.com/#{repo}.git"
        LivingBlog.sh!("git clone #{Shellwords.escape(clone_url)} repo")
        
        Dir.chdir('repo') do
          full_path = File.join(Dir.pwd, post_path)
          content = File.read(full_path)

          plan = Planner.new(content).plan!
          urls = plan.dig("checks")
            &.find { |check| check["type"] == 'link_check' }
            &.dig("urls") || []
          LinkChecker.new(urls).check!
        end
      end
    end
  end
end

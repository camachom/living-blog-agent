# frozen_string_literal: true

require 'octokit'
require 'shellwords'

module LivingBlog
  class Writer
    def initialize(results)
      @repo = ENV.fetch('REPO')
      @post_path   = ENV.fetch('POST_PATH') # e.g. "content/posts/detecting-drum-hits/index.md"
      @author_name = ENV.fetch('GIT_AUTHOR_NAME', 'Living Blog Agent')
      @author_email = ENV.fetch('GIT_AUTHOR_EMAIL', 'living-blog-agent@users.noreply.github.com')
      @token       = ENV.fetch('GITHUB_TOKEN')
      @base_branch = ENV.fetch('BASE_BRANCH', 'main')
      @new_branch_name = "living-blog/update-#{Time.now.utc.strftime('%Y%m%d-%H%M%S')}"
      @results = results
    end

    def write!
      Dir.mktmpdir('living-blog-') do |dir|
        Dir.chdir(dir) do
          clone_url = "https://x-access-token:#{@token}@github.com/#{@repo}.git"
          sh!("git clone #{Shellwords.escape(clone_url)} repo")

          Dir.chdir('repo') do
            pull_and_clone!
            update_file!
            open_pr!
          end
        end
      end
    end

    private

    def broken_links
      results[:links].filter { |link| link[:ok] != true }
    end

    def pull_and_clone!
      sh!("git checkout #{Shellwords.escape(@base_branch)}")
      sh!("git checkout -b #{Shellwords.escape(@new_branch_name)}")

      full_path = File.join(Dir.pwd, @post_path)
      raise Error, "POST_PATH not found: #{@post_path}" unless File.exist?(full_path)
    end

    def update_file!
      full_path = File.join(Dir.pwd, @post_path)
      content = File.read(full_path)
      current = Time.now.strftime('%b %Y')

      if content.include? "## Update (#{current})"
        puts "Blog already updated this month (#{current})"
        raise Error, "Blog post already has an update for #{current}"
      end

      update_block = <<~MD
        #{'    '}
        ## Update (#{current})

            - the following links are broken:
            #{broken_links}
      MD

      File.write(full_path, content + update_block)
    end

    def open_pr!
      client = Octokit::Client.new(access_token: @token)
      client.auto_paginate = true

      pr = client.create_pull_request(
        @repo,
        @base_branch,
        @new_branch_name,
        "Living Blog: #{File.basename(File.dirname(@post_path))} update",
        "Automated update appended by Living Blog agent.\n\nNext: add real checks and only open PR when needed."
      )

      puts "Opened PR: #{pr.html_url}"
    end

    def sh!(cmd)
      puts "+ #{cmd}"
      ok = system(cmd)
      raise Error, "Command failed: #{cmd}" unless ok
    end
  end
end

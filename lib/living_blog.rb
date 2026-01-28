require "octokit"
require "shellwords"

module LivingBlog
    class Error < StandardError; end

    class Update
        def initialize
            @repo = ENV.fetch("REPO")
            @post_path   = ENV.fetch("POST_PATH") # e.g. "content/posts/detecting-drum-hits/index.md"
            @author_name = ENV.fetch("GIT_AUTHOR_NAME", "Living Blog Agent")
            @author_email= ENV.fetch("GIT_AUTHOR_EMAIL", "living-blog-agent@users.noreply.github.com")
            @token       = ENV.fetch("GITHUB_TOKEN")
            @base_branch = ENV.fetch("BASE_BRANCH", "main")
            @new_branch_name = "living-blog/update-#{Time.now.utc.strftime("%Y%m%d-%H%M%S")}"
        end

        def run!(dry_run: false)
            if dry_run
                puts "[DRY RUN] Would open PR for #{@post_path}"
                return
            end
    
            Dir.mktmpdir('living-blog-') do |dir|
                Dir.chdir(dir) do
                    clone_url = "https://x-access-token:#{@token}@github.com/#{@repo}.git"
                    sh!("git clone #{Shellwords.escape(clone_url)} repo")
    
                    Dir.chdir("repo") do    
                        path = pull_and_clone!
                        append_update!(path)
                        commit_and_push!
                        open_pr!
                    end
                end
            end
        end

        private

        def pull_and_clone!
            sh!("git checkout #{Shellwords.escape(@base_branch)}")
            sh!("git checkout -b #{Shellwords.escape(@new_branch_name)}")
    
            full_path = File.join(Dir.pwd, @post_path)
            raise Error, "POST_PATH not found: #{@post_path}" unless File.exist?(full_path)
    
            full_path
        end
    
        def append_update!(path)
          content = File.read(path)
          current = Time.now.strftime("%b %Y")
    
          if content.include? "## Update (#{current})"
              raise "blog already updated this month"
          end
    
          update_block = <<~MD
              
          ## Update (#{current})
    
          - This is an automated “Living Blog” test update.
          - Next step: replace this with real checks (broken links, stale claims, etc).
            MD
    
            File.write(path, content + update_block)
        end
    
        def commit_and_push!
            sh!("git add #{Shellwords.escape(@post_path)}")
            sh!("git -c user.name=#{Shellwords.escape(@author_name)} -c user.email=#{Shellwords.escape(@author_email)} commit -m #{Shellwords.escape("Add Living Blog update section")}")
    
            sh!("git push origin #{Shellwords.escape(@new_branch_name)}")
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
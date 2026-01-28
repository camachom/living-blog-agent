# frozen_string_literal: true

module LivingBlog
  def self.run!(dry_run: false)
    return unless dry_run

    puts "[DRY RUN] Would open PR for #{@post_path}"
    nil

    # add your new classes here
  end
end

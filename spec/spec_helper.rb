# frozen_string_literal: true

require 'webmock/rspec'
require 'climate_control'

# Load lib files
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'living_blog'

# Disable real HTTP connections during tests
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.order = :random
  Kernel.srand config.seed
end

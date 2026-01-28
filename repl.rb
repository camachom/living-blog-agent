#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick REPL loader for OpenAIClient

require 'dotenv/load'
require_relative 'lib/living_blog'

# Start Pry with the class loaded
require 'pry'
binding.pry

# frozen_string_literal: true

require 'bundler/setup'
require 'icalendar/rrule'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Disallow **should** syntax.
  #
  # There's an older "should-based" syntax, which relies upon `should` being
  # monkey-patched onto every object in the system, we want
  # to avoid such hacks and therefore disallow the "should-based" syntax.
  #
  # Read also https://relishapp.com/rspec/rspec-expectations/docs/syntax-configuration
  #
  # Please note that with these settings an RSpec such as
  # `specify { 3.should eq(3) }` will now
  # lead to `NoMethodError: undefined method "should" for 3:Integer`
  #
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end

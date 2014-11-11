API_HOST = 'http://localhost:8999'

require_relative '../lib/round'
require 'webmock/rspec'
require 'vcr'
require 'pry-byebug'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.include WebMock::API

  config.before(:each) do
    Round::Patchboard.class_variable_set(:@@patchboard, nil)
    namespace = Round::Patchboard::Resources
    namespace.constants.select { |c|
      namespace.const_get(c).is_a? Class
    }.each { |c|
      namespace.send(:remove_const, c)
    }
  end

  config.order = 'random'
end
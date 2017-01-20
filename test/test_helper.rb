ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'rr'
require 'webmock/minitest'

WebMock.enable!

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

def stub_service_config_provider(service)
  payload = {
    "logo" => {"1x" => "logo#{service.id}.png", "2x" => "logo#{service.id}@2x.png", "3x" => "logo#{service.id}@3x.png"},
    "banner" => {"1x" => "banner#{service.id}.png", "2x" => "banner#{service.id}@2x.png", "3x" => "banner#{service.id}@3x.png"},
    "root" => "https://www#{service.id}.example.com/",
    "authenticate" => {"success" => "https://www#{service.id}.example.com/auth_success", "failure" => "https://www#{service.id}.example.com/auth_failure"},
    "profile" => {"update" => "https://www#{service.id}.example.com/profile_update", "back" => "https://www#{service.id}.example.com/back_from_profile/DOMAIN_NAME/SCREEN_NAME"}
  }

  token = JWT.encode(payload, service.key)
  stub_request(:get, service.config_provider).to_return(:status => 200, :body => token, :headers => {:content_type => 'text/plain'})

  payload
end

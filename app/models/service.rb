# coding: utf-8
require "timeout"
require "net/http"
Net::HTTP.version_1_2

class Service < ActiveRecord::Base
  has_many :auth_tickets
  has_many :profile_services

  def notice(profile)
    payload = {
      'id' => self.id,
      'profile_id' => profile.id,
      'nickname' => profile.nickname,
      'profile_text' => profile.profile_html(:section_anchor_prefix => "profile_"),
      'exp' => 5.minutes.from_now.to_i
    }
    token = JWT.encode(payload, self.key)

    begin
      Timeout.timeout(3) do
        uri = URI(remote_config['profile']['update'])
        Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) {|http|
          http.post(uri.path, "token=#{token}")
        }
      end
    rescue Exception => e
      logger.debug e.backtrace
    end
  end

  def logos
    remote_config['logo']
  end

  def banners
    remote_config['banner']
  end

  def root
    remote_config['root']
  end

  def authenticate_success
    remote_config['authenticate']['success']
  end

  def authenticate_failure
    remote_config['authenticate']['failure']
  end

  def user_page_url
    remote_config['profile']['back']
  end

  def remote_config
    Rails.cache.fetch("service-remote-config-#{id}", :expires_in => 10.minutes) do
      Timeout.timeout(3) do
        uri = URI(self.config_provider)
        response = Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) {|http|
          http.get(uri.path)
        }
        JWT.decode(response.body, key).first
      end
    end
  end
end

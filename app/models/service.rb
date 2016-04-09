# coding: utf-8
require "digest/sha2"
require "timeout"
require "net/http"
Net::HTTP.version_1_2

class Service < ActiveRecord::Base
  has_many :auth_tickets
  has_many :profile_services

  def validate_authenticate_request(params)
    if Time.at(params[:timestamp].to_i) > 5.minutes.ago and
      sign([self.id, params[:timestamp], 'authenticate'].join) == params[:signature]
      true
    else
      raise InvalidSignatureError.new
    end
  end

  def notice(profile)
    params = {
      'id' => self.id,
      'profile_id' => profile.id,
      'nickname' => profile.nickname,
      'profile_text' => profile.profile_html(:section_anchor_prefix => "profile_"),
      'timestamp' => Time.now.to_i
    }

    message = [
      params['id'], params['profile_id'],
      params['nickname'], params['profile_text'], params['timestamp'],
      'update'
    ].join
    params['signature'] = sign(message)

    params = params.map {|key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
    begin
      Timeout.timeout(3) do
        uri = URI(remote_config['profile']['update'])
        Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) {|http|
          http.post(uri.path, params)
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

  class InvalidSignatureError < RuntimeError; end

  private
  def sign(message)
    OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, self.key, message)
  end
end

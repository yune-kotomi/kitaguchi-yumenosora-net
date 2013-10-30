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
      timeout(3) do
        uri = URI(self.profile_update)
        Net::HTTP.start(uri.host, uri.port) {|http|
          http.post(uri.path, params)
        }
      end
    rescue Exception => e
      logger.debug e.backtrace
    end
  end
  
  class InvalidSignatureError < RuntimeError; end
  
  private
  def sign(message)
    OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, self.key, message)
  end
end

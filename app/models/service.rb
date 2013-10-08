# coding: utf-8
require "digest/sha2"
require "timeout"
require "net/http"
Net::HTTP.version_1_2

class Service < ActiveRecord::Base
  has_many :auth_tickets
  has_many :profile_services

  def validate_params(params)
    ret = false

    #タイムスタンプのチェック
    timestamp = Time.at(params[:timestamp].to_i)
    if timestamp > 5.minutes.ago
      if params[:signature] == sign(params)
        ret = true
      else
        raise SignatureInvalidError.new
      end

    else
      raise RequestTooOldError.new
    end

    return ret
  end

  def sign(params)
    src = [
        params[:id], 
        params[:key], 
        params[:data], 
        params[:timestamp]
      ].join
    
    return OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, self.key, src)
  end

  def notice(profile)
    params = {
      'id' => self.id,
      'profile_id' => profile.id,
      'nickname' => profile.nickname,
      # cf. http://jasonfox.com/post/14571407609/undefined-method-bytesize-for-nil-nilclass
      'profile_text' => ActionController::Base.helpers.strip_tags(profile.profile_html(:section_anchor_prefix => "profile_")),
      'timestamp' => Time.now.to_i
    }

    message = [
      params['id'], params['profile_id'], 
      params['nickname'], params['profile_text'], params['timestamp']
    ].join
    params['signature'] = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, self.key, message)

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
  
  class SignatureInvalidError < RuntimeError; end
  class RequestTooOldError < RuntimeError; end
end

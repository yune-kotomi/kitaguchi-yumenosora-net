require "uuidtools"
class AuthTicket < ActiveRecord::Base
  belongs_to :profile
  belongs_to :service

  before_save :key_generate
  
  def deliver_params
    timestamp = Time.now.to_i
    {
      :id => service.id,
      :key => self.key,
      :timestamp => timestamp, 
      :signature => sign([service.id, self.key, timestamp, 'deliver'].join)
    }
  end
  
  def validate_retrieve_request(params)
    if Time.at(params[:timestamp].to_i) > 5.minutes.ago and
      params[:signature] == sign([service.id, params[:key], params[:timestamp], 'retrieve'].join)
      true
    else
      raise InvalidSignatureError.new
    end
  end
  
  def retrieve_response
    timestamp = Time.now.to_i
    {
      :profile_id => profile.id,
      :domain_name => profile.domain_name,
      :screen_name => profile.screen_name,
      :nickname => profile.nickname,
      :profile_text => profile.profile_html,
      :openid_url => profile.primary_openid.str,
      :timestamp => timestamp,
      :signature => sign([
        service.id, profile.id,
        profile.domain_name, profile.screen_name, profile.nickname,
        profile.profile_html, profile.primary_openid.str, 
        timestamp, 'retrieved'
      ].join)
    }
  end
  
  class InvalidSignatureError < RuntimeError; end

  private
  def key_generate
    self.key = UUIDTools::UUID.random_create.to_s
  end
  
  def sign(message)
    OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, service.key, message)
  end
end


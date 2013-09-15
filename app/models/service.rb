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
      src = [params[:id], params[:key], params[:timestamp], self.key].join
      
      if params[:sign] == Digest::SHA256.hexdigest(src)
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
        params[:timestamp], 
        self.key
      ].join
    
    return Digest::SHA256.hexdigest(src)
  end

  def notice(profile)
    data = ({
        :profile_id => profile.id,
        :nickname => profile.nickname,
        :profile_text => 
          profile.profile_html(:section_anchor_prefix => "profile_")
      }).to_json
    timestamp = Time.now.to_i
    signature = sign(:data => data, :timestamp => timestamp)

    begin
      timeout(3) do
        uri = URI(self.profile_update)
        Net::HTTP.start(uri.host, uri.port) {|http|
          http.post(
            uri.path, 
            "data=#{URI.escape data}&timestamp=#{timestamp}" + 
              "&sign=#{URI.escape signature}"
          )
        }
      end
    rescue Exception => e
      logger.debug e.backtrace
    end
  end
  
  class SignatureInvalidError < RuntimeError; end
  class RequestTooOldError < RuntimeError; end
end

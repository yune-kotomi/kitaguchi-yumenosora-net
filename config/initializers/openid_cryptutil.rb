module OpenID
  module CryptUtil
    def CryptUtil.hmac_sha1(key, text)
        OpenSSL::HMAC::digest(OpenSSL::Digest::SHA1.new, key, text)
    end

    def CryptUtil.hmac_sha256(key, text)
      OpenSSL::HMAC::digest(OpenSSL::Digest::SHA256.new, key, text)
    end
  end
end

require 'test_helper'
require 'webmock/test_unit'
include WebMock

class ServiceTest < ActiveSupport::TestCase
  setup do
    @one = services :one
    @profile = profiles :one
  end
  
  test "認証依頼のシグネチャが正しければtrueを返す" do
    params = {
      :id => 5,
      :timestamp => Time.new.to_i
    }
    signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.key, [params[:id], params[:timestamp]].join)
    
    assert @one.validate_params(params.merge(:signature => signature))
  end
  
  test "認証依頼のシグネチャが不正な場合例外が発生する" do
    params = {
      :id => 5,
      :timestamp => Time.new.to_i
    }
    signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.key, [params[:id], params[:timestamp], 'hoge'].join)
    
    assert_raise Service::SignatureInvalidError do
      @one.validate_params(params.merge(:signature => signature))    
    end
  end
  
  test "認証依頼が5分より前に生成されている場合、例外が発生する" do
    params = {
      :id => 5,
      :timestamp => 6.minute.ago.to_i
    }
    signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.key, [params[:id], params[:timestamp]].join)
    
    assert_raise Service::RequestTooOldError do
      @one.validate_params(params.merge(:signature => signature))
    end
  end
  
  test "認証キー引渡しリクエストに対する正しい署名が生成できる" do
    params = {
      :id => 5,
      :timestamp => Time.new.to_i,
      :key => UUIDTools::UUID.random_create.to_s
    }
    signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.key, [params[:id], params[:key], params[:timestamp]].join)
    
    assert_equal signature, @one.sign(params)
  end
  
  test "profile_updateに指定されたURLへPOSTでプロフィール内容変更の通知を送る" do
    stub_request(:any, "www.example.com")
    @one.notice(@profile)
    
    assert_requested :post, @one.profile_update, :times => 1 do |request|
      params = CGI.parse(request.body)
      
      message = [
        @one.id, 
        params['profile_id'].first, 
        params['nickname'].first, 
        params['profile_text'], 
        params['timestamp'].first
      ].join
      expected = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.key, message)
      
      expected == params['signature'].first
    end
  end
end


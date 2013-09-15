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
    signature = Digest::SHA256.hexdigest([params[:id], params[:timestamp], @one.key].join)
    
    assert @one.validate_params(params.merge(:sign => signature))
  end
  
  test "認証依頼のシグネチャが不正な場合例外が発生する" do
    params = {
      :id => 5,
      :timestamp => Time.new.to_i
    }
    signature = Digest::SHA256.hexdigest([params[:id], params[:timestamp]].join)
    
    assert_raise Service::SignatureInvalidError do
      @one.validate_params(params.merge(:sign => signature))    
    end
  end
  
  test "認証依頼が5分より前に生成されている場合、例外が発生する" do
    params = {
      :id => 5,
      :timestamp => 6.minute.ago.to_i
    }
    signature = Digest::SHA256.hexdigest([params[:id], params[:timestamp], @one.key].join)
    
    assert_raise Service::RequestTooOldError do
      @one.validate_params(params.merge(:sign => signature))
    end
  end
  
  test "認証キー引渡しリクエストに対する正しい署名が生成できる" do
    params = {
      :id => 5,
      :timestamp => Time.new.to_i,
      :key => UUIDTools::UUID.random_create.to_s
    }
    signature = Digest::SHA256.hexdigest([params[:id], params[:key], params[:timestamp], @one.key].join)
    
    assert_equal signature, @one.sign(params)
  end
  
  test "profile_updateに指定されたURLへPOSTでプロフィール内容変更の通知を送る" do
    stub_request(:any, "www.example.com")
    @one.notice(@profile)
    
    assert_requested :post, @one.profile_update, :times => 1 do |request|
      query_params = CGI.parse(request.body)
      
      data = {
        'profile_id' => @profile.id,
        'nickname' => @profile.nickname,
        'profile_text' => @profile.profile_html
      }.to_json
      expected = Digest::SHA256.hexdigest([data, query_params['timestamp'].first, @one.key].join)
      
      expected == query_params['sign'].first
    end
  end
end


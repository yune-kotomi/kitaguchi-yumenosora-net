require 'test_helper'

class AuthTicketTest < ActiveSupport::TestCase
  def sign(message)
    OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.service.key, message)
  end

  setup do
    @one = auth_tickets(:one)
  end

  test "認証情報要求リクエストに対し、正しい署名が検証できる" do
    params = {:id => @one.service.id, :key => @one.key, :timestamp => Time.now.to_i}
    params[:signature] = sign([@one.service.id, @one.key, params[:timestamp], 'retrieve'].join)
    
    assert @one.validate_retrieve_request(params)
  end
  
  test "認証情報要求リクエストの署名が不正な場合、例外を吐く" do
    params = {:id => @one.service.id, :key => @one.key, :timestamp => Time.now.to_i}
    params[:signature] = 'invalid'
    
    assert_raise AuthTicket::InvalidSignatureError do
      assert @one.validate_retrieve_request(params)
    end
  end
  
  test "認証情報要求リクエストが古い場合、例外を吐く" do
    params = {:id => @one.service.id, :key => @one.key, :timestamp => 10.minutes.ago.to_i}
    params[:signature] = sign([@one.service.id, @one.key, params[:timestamp], 'retrieve'].join)
    
    assert_raise AuthTicket::InvalidSignatureError do
      assert @one.validate_retrieve_request(params)
    end
  end
  
  test "認証キー引渡し用のシグネチャとタイムスタンプを返す" do
    params = @one.deliver_params
    
    assert_equal @one.service.id, params[:id]
    assert_equal sign([@one.service.id, @one.key, params[:timestamp], 'deliver'].join), params[:signature]
  end
  
  test "認証情報を引き渡せる形で返す" do
    expected = {
      :profile_id => @one.profile.id,
      :domain_name => @one.profile.domain_name,
      :screen_name => @one.profile.screen_name,
      :nickname => @one.profile.nickname,
      :profile_text => @one.profile.profile_html,
      :openid_url => @one.profile.primary_openid.str
    }
    
    actual = @one.retrieve_response
    
    expected.each do |key, value|
      assert_equal value, actual[key]
    end
    
    assert_equal sign([
      @one.service.id, expected[:profile_id], 
      expected[:domain_name], expected[:screen_name], expected[:nickname],
      expected[:profile_text], expected[:openid_url], actual[:timestamp],
      'retrieved'
    ].join), actual[:signature]
  end
end

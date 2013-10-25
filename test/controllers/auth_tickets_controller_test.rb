require 'test_helper'

class AuthTicketsControllerTest < ActionController::TestCase
  setup do
    @auth_ticket = auth_tickets(:one)
    @old_auth_ticket = auth_tickets(:old)
  end

  test "正しいリクエストにより認証情報が引き渡される" do
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC::hexdigest(
      OpenSSL::Digest::SHA256.new, 
      @auth_ticket.service.key, 
      [@auth_ticket.service_id, @auth_ticket.key, timestamp, 'retrieve'].join
    )
    get :show, {:id => @auth_ticket.service.id, :key => @auth_ticket.key, :timestamp => timestamp, :signature => signature}
    
    assert_response :success
    result = JSON.parse(response.body)
    profile = @auth_ticket.profile
    assert_equal ['profile_id', 'domain_name', 'screen_name', 'nickname', 'profile_text', 'openid_url', 'timestamp', 'signature'].sort, result.keys.sort
    assert_equal profile.id, result['profile_id']
    assert_equal profile.domain_name, result['domain_name']
    assert_equal profile.screen_name, result['screen_name']
    assert_equal profile.nickname, result['nickname']
    assert_equal profile.primary_openid.str, result['openid_url']
  end
  
  test "認証情報は一度しか取得できない" do
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC::hexdigest(
      OpenSSL::Digest::SHA256.new, 
      @auth_ticket.service.key, 
      [@auth_ticket.service_id, @auth_ticket.key, timestamp, 'retrieve'].join
    )
    get :show, {:id => @auth_ticket.service.id, :key => @auth_ticket.key, :timestamp => timestamp, :signature => signature}
    get :show, {:id => @auth_ticket.service.id, :key => @auth_ticket.key, :timestamp => timestamp, :signature => signature}
    assert_response :missing
  end
  
  test "不正なリクエストでは認証情報が引き渡されない" do
    get :show, {:id => @auth_ticket.service.id, :key => @auth_ticket.key, :timestamp => Time.now.to_i, :signature => 'invalid_signature'}
    assert_response :forbidden
  end
  
  test "認証キーが古い場合、認証情報が引き渡されない" do
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC::hexdigest(
      OpenSSL::Digest::SHA256.new, 
      @old_auth_ticket.service.key, 
      [@old_auth_ticket.service_id, @old_auth_ticket.key, timestamp, 'retrieve'].join
    )
    get :show, {:id => @old_auth_ticket.service.id, :key => @old_auth_ticket.key, :timestamp => timestamp, :signature => signature}
    assert_response :missing
  end
end

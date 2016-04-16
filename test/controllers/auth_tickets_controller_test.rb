require 'test_helper'

class AuthTicketsControllerTest < ActionController::TestCase
  setup do
    @auth_ticket = auth_tickets(:one)
    @old_auth_ticket = auth_tickets(:old)
  end

  test "正しいリクエストにより認証情報が引き渡される" do
    payload = {
      'key' => @auth_ticket.key,
      'exp' => 5.minutes.from_now.to_i
    }
    get :show, {:id => @auth_ticket.service.id, :token => JWT.encode(payload, @auth_ticket.service.key)}

    assert_response :success
    result = JWT.decode(response.body, @auth_ticket.service.key).first
    profile = @auth_ticket.profile
    assert_equal ['profile_id', 'domain_name', 'screen_name', 'nickname', 'profile_text', 'openid_url', 'exp'].sort, result.keys.sort
    assert_equal profile.id, result['profile_id']
    assert_equal profile.domain_name, result['domain_name']
    assert_equal profile.screen_name, result['screen_name']
    assert_equal profile.nickname, result['nickname']
    assert_equal profile.primary_openid.str, result['openid_url']
  end

  test "認証情報は一度しか取得できない" do
    payload = {
      'key' => @auth_ticket.key,
      'exp' => 5.minutes.from_now.to_i
    }
    token = JWT.encode(payload, @auth_ticket.service.key)
    get :show, {:id => @auth_ticket.service.id, :token => token}
    get :show, {:id => @auth_ticket.service.id, :token => token}
    assert_response :missing
  end

  test "不正なリクエストでは認証情報が引き渡されない" do
    payload = {
      'key' => @auth_ticket.key,
      'exp' => 5.minutes.from_now.to_i
    }
    token = JWT.encode(payload, 'invalid key')
    get :show, {:id => @auth_ticket.service.id, :token => token}
    assert_response :forbidden
  end

  test "トークンに期限がない場合、認証情報が引き渡されない" do
    payload = {
      'key' => @auth_ticket.key
    }
    token = JWT.encode(payload, @auth_ticket.service.key)
    get :show, {:id => @old_auth_ticket.service.id, :token => token}
    assert_response :forbidden
  end
end

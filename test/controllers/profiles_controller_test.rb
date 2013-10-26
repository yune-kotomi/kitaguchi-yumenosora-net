require 'test_helper'
require 'webmock/test_unit'
include WebMock

class ProfilesControllerTest < ActionController::TestCase
  setup do
    @profile = profiles(:one)
    
    @service = services(:one)
    @service2 = services(:two)
    
    @unregistered_openid_url = openid_urls(:unregistered)
    
    WebMock.reset!
  end

  test "authenticateはログイン済みの場合は認証チケットを発行してサービスに戻す" do
    timestamp = Time.new.to_i
    message = [@service.id, timestamp, 'authenticate'].join
    signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @service.key, message)
    
    assert_difference('AuthTicket.count') do
      get :authenticate, 
        {:id => @service.id, :timestamp => timestamp, :signature => signature},
        {:login_profile_id => @profile.id}
    end
    
    assert_response :redirect
    location = response.location
    assert_equal URI(@service.auth_success).host, URI(location).host
    params = CGI.parse(URI(location).query)
    assert_equal @service.id.to_s, params['id'].first
    assert AuthTicket.where(:key => params['key'].first).count > 0
  end
  
  test "初めて使うサービスの場合、結びつけた上でサービスに戻す" do
    timestamp = Time.new.to_i
    message = [@service2.id, timestamp, 'authenticate'].join
    signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @service2.key, message)
    
    assert_difference('ProfileService.count') do
      assert_difference('AuthTicket.count') do
        get :authenticate, 
          {:id => @service2.id, :timestamp => timestamp, :signature => signature},
          {:login_profile_id => @profile.id}
      end
    end
    
    assert_response :redirect
    location = response.location
    assert_equal URI(@service2.auth_success).host, URI(location).host
    params = CGI.parse(URI(location).query)
    assert_equal @service2.id.to_s, params['id'].first
    assert AuthTicket.where(:key => params['key'].first).count > 0
  end
  
  test "サービスIDが指定されていない場合はログイン状態でも使用するIDの入力を求める" do
    assert_no_difference('AuthTicket.count') do
      get :authenticate, {}, {:login_profile_id => @profile.id}
    end
    
    assert_response :success
  end
  
  test "authenticateはログアウト状態の場合、使用するIDの入力を求める" do
    timestamp = Time.new.to_i
    message = [@service.id, timestamp, 'authenticate'].join
    signature = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @service.key, message)
    
    assert_no_difference('AuthTicket.count') do
      get :authenticate, 
        {:id => @service.id, :timestamp => timestamp, :signature => signature}
    end
    
    assert_response :success
  end
  
  test "authenticateに不正な署名を与えた場合は403で応答する" do
    timestamp = Time.new.to_i
    
    assert_no_difference('AuthTicket.count') do
      post :authenticate, 
        {:id => @service.id, :timestamp => timestamp, :signature => 'invalid'}
    end
    
    assert_response :forbidden
  end
  
  test "プロフィール作成後は指定されたサービスに戻す" do
    assert_difference('Profile.count') do
      post :create, 
        {
          :profile => {:nickname => 'nickname'}, 
          :id => @service.id
        },
        {:openid_url_id => @unregistered_openid_url.id}
    end
    assert_response :redirect
    assert /^#{@service.auth_success}/ =~ response.location
    assert assigns(:openid_url).primary_openid
    assert_equal assigns(:openid_url).profile, assigns(:profile)
    assert_equal assigns(:profile).domain_name, @unregistered_openid_url.domain_name
    assert_equal assigns(:profile).screen_name, @unregistered_openid_url.screen_name
  end
  
  test "should show profile" do
    get :show, {}, {:login_profile_id => @profile.id}
    assert_response :success
    assert_equal @login_profile, assigns(:profile)
  end

  test "ログアウト状態でupdateは不可" do
    patch :update, 
      {:profile => {  }}
    assert_response :forbidden
  end

  test "should update profile" do
    patch :update, 
      {:profile => {  }},
      {:login_profile_id => @profile.id}
      
    assert_redirected_to profile_path(assigns(:profile))
  end
  
  test "update実行時には登録済みサービスに対して更新通知を送信する" do
    stub_request(:any, URI(@service.root).host)
    patch :update, 
      {:profile => {:nickname => 'new nickname'}},
      {:login_profile_id => @profile.id}
    
    assert_requested :post, @service.profile_update, :times => 1 do |post_request|
      params = CGI.parse(post_request.body)
      'new nickname' == params['nickname'].first and @profile.id.to_s == params['profile_id'].first
    end
  end
  
  test "ログアウト後、サービスに戻す" do
    get :logout, :id => @service.id
    assert_redirected_to @service.root
    assert_nil session[:login_profile_id]
    assert_nil session[:last_login]
    assert_nil session[:openid_url_id]
  end
end


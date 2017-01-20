require 'test_helper'
include WebMock::API

class ProfilesControllerTest < ActionController::TestCase
  setup do
    @profile = profiles(:one)

    @service = services(:one)
    @service2 = services(:two)

    @unregistered_openid_url = openid_urls(:unregistered)

    WebMock.reset!

    @service_conf = stub_service_config_provider(@service)
    @service2_conf = stub_service_config_provider(@service2)
  end

  test "authenticateはログイン済みの場合は認証チケットを発行してサービスに戻す" do
    token = JWT.encode({'id' => @service.id, 'exp' => 5.minutes.from_now.to_i}, @service.key)

    assert_difference('AuthTicket.count') do
      get :authenticate,
        :params => {:id => @service.id, :token => token},
        :session => {:login_profile_id => @profile.id}
    end

    assert_response :redirect
    location = response.location
    assert_equal URI(@service.authenticate_success).host, URI(location).host
    params = CGI.parse(URI(location).query)
    assert_equal @service.id.to_s, params['id'].first
    payload = JWT.decode(params['token'].first, @service.key).first
    assert AuthTicket.where(:key => payload['key']).count > 0
  end

  test "初めて使うサービスの場合、結びつけた上でサービスに戻す" do
    token = JWT.encode({'id' => @service2.id, 'exp' => 5.minutes.from_now.to_i}, @service2.key)

    assert_difference('ProfileService.count') do
      assert_difference('AuthTicket.count') do
        get :authenticate,
          :params => {:id => @service2.id, :token => token},
          :session => {:login_profile_id => @profile.id}
      end
    end

    assert_response :redirect
    location = response.location
    assert_equal URI(@service2.authenticate_success).host, URI(location).host
    params = CGI.parse(URI(location).query)
    assert_equal @service2.id.to_s, params['id'].first
    payload = JWT.decode(params['token'].first, @service2.key).first
    assert AuthTicket.where(:key => payload['key']).count > 0
  end

  test "サービスIDが指定されていない場合はログイン状態でも使用するIDの入力を求める" do
    assert_no_difference('AuthTicket.count') do
      get :authenticate, :session => {:login_profile_id => @profile.id}
    end

    assert_response :success
  end

  test "エラーで戻ってきた場合はサービスIDがparamsにないのでflashの値を使う" do
    assert_no_difference('AuthTicket.count') do
      get :authenticate,
        :session => {:login_profile_id => @profile.id},
        :flash => {:service_id => @service2.id}
    end

    assert_response :success
    assert_equal @service2, assigns(:service)
  end

  test "authenticateはログアウト状態の場合、使用するIDの入力を求める" do
    token = JWT.encode({'id' => @service.id, 'exp' => 5.minutes.from_now.to_i}, @service.key)

    assert_no_difference('AuthTicket.count') do
      get :authenticate,
        :params => {:id => @service.id, :token => token}
    end

    assert_response :success
  end

  test "authenticateに不正な署名を与えた場合は403で応答する" do
    token = JWT.encode({'id' => @service.id}, @service.key)

    assert_no_difference('AuthTicket.count') do
      post :authenticate,
        :params => {:id => @service.id, :token => token}
    end

    assert_response :forbidden

    token = JWT.encode({'id' => @service.id, 'exp' => 5.minutes.from_now.to_i}, @service2.key)

    assert_no_difference('AuthTicket.count') do
      post :authenticate,
        :params => {:id => @service.id, :token => token}
    end

    assert_response :forbidden
  end

  test "プロフィール作成後は指定されたサービスに戻す" do
    assert_difference('Profile.count') do
      post :create,
        :params => {
          :profile => {:nickname => 'nickname'},
          :id => @service.id
        },
        :session => {:openid_url_id => @unregistered_openid_url.id}
    end
    assert_response :redirect
    assert /^#{@service.authenticate_success}/ =~ response.location
    assert assigns(:openid_url).primary_openid
    assert_equal assigns(:openid_url).profile, assigns(:profile)
    assert_equal assigns(:profile).domain_name, @unregistered_openid_url.domain_name
    assert_equal assigns(:profile).screen_name, @unregistered_openid_url.screen_name
    assert_equal assigns(:openid_url).profile.id, session[:login_profile_id]
  end

  test "should show profile" do
    get :show, :session => {:login_profile_id => @profile.id}
    assert_response :success
    assert_equal @profile, assigns(:profile)
  end

  test "プロフィール編集画面をservice_id付きで開くとセッションに記録する" do
    get :show,
      :params => {:service_id => @service.id},
      :session => {:login_profile_id => @profile.id}
    assert_response :success
    assert_equal @service.id, session[:service_back_to]
  end

  test "ログアウト状態でupdateは不可" do
    patch :update,
      :params => {:profile => {  }}
    assert_response :forbidden
  end

  test "should update profile" do
    patch :update,
      :params => {:profile => {  }},
      :session => {:login_profile_id => @profile.id}

    assert_response :success
  end

  test "update実行時には登録済みサービスに対して更新通知を送信する" do
    stub_request(:any, @service_conf['profile']['update'])

    patch :update,
      :params => {:profile => {:nickname => 'new nickname'}},
      :session => {:login_profile_id => @profile.id}

    assert_requested :post, @service_conf['profile']['update'], :times => 1 do |post_request|
      query = CGI.parse(post_request.body)
      payload = JWT.decode(query['token'].first, @service.key).first

      'new nickname' == payload['nickname'] && @profile.id == payload['profile_id']
    end
  end

  test "ログアウト後、サービスに戻す" do
    get :logout, :params => {:id => @service.id}
    assert_redirected_to @service.root
    assert session[:login_profile_id].nil?
    assert session[:last_login].nil?
    assert session[:openid_url_id].nil?
  end
end

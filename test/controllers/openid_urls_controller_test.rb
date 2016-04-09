require 'test_helper'

class OpenidUrlsControllerTest < ActionController::TestCase
  def mock_redirect_url(service_id = nil)
    redirect_url = 'http://example.com/openid-provider-url'
    service_id = "/#{service_id}" if service_id.present?

    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).begin('http://example.com/') {
        mock!.redirect_url(
          'http://test.host/',
          "http://test.host/openid_urls/complete#{service_id}"
        ) {redirect_url}
      }
    end

    redirect_url
  end

  def mock_complete_response(service_id, response_status = OpenID::Consumer::SUCCESS, identity_url = nil)
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters,
        "http://test.host/openid_urls/complete#{'/' + service_id.to_s if service_id.present?}"
      ) {
        response = mock!
        response.identity_url { identity_url } if identity_url.present?
        response.status { response_status }

        response
      }
    end
  end

  def mock_openid_connect_response(identity_url = nil)
    any_instance_of(OpenIDConnect) do |klass|
      result = {'result' => 'value'}
      mock(klass).authentication_result({"controller"=>"openid_urls", "action"=>"openid_connect_complete"}) { result }
      mock(klass).parse_id_token(result) { {'openid_id' => identity_url} }
    end
  end

  setup do
    @profile = profiles(:one)
    @service = services(:one)
    @service2 = services(:two)
    @primary_openid_url = openid_urls(:profile_one_primary)
    @secondary_openid_url = openid_urls(:profile_one_secondary)

    @others_openid_url = openid_urls(:profile_two_primary)

    @parameters = {
      "openid.return_to"=>"http://test.host/openid_urls/complete",
      "openid.ns"=>"http://specs.openid.net/auth/2.0",
      "openid.identity"=>"http://example.com/user",
      "openid.sig"=>"openid-sig",
      "openid.assoc_handle"=>"openid-assoc-handle",
      "openid.response_nonce"=>"nonce",
      "openid.signed"=>
        "mode,claimed_id,identity,op_endpoint,return_to,response_nonce,assoc_handle",
      "openid.mode"=>"id_res",
      "openid.claimed_id"=>"http://example.com/user",
      "openid.op_endpoint"=>"https://example.com/openid/server"
    }

    WebMock.reset!

    @service_conf = stub_service_config_provider(@service)
    @service2_conf = stub_service_config_provider(@service2)
  end

  test "OpenID URLをPOSTするとOPへリダイレクトする" do
    expected = mock_redirect_url(@service.id)

    post :login,
      {:openid_url => 'http://example.com/', :service_id => @service.id},
      {:login_profile_id => @profile.id}

    assert_redirected_to expected
  end

  test "OpenID認証成功後、初回ログインならプロフィール作成画面へ" do
    mock_complete_response(@service.id, OpenID::Consumer::SUCCESS, @parameters['openid.identity'])

    assert_difference("OpenidUrl.count") do
      get :complete, @parameters.merge(:service_id => @service.id)
    end

    assert_redirected_to :controller => :profiles,
      :action => :new,
      :service_id => @service.id
    assert session[:openid_url_id].present?
  end

  test "OpenID認証成功後、初めて使うサービスなら結びつけたあとでサービスに戻す" do
    mock_complete_response(@service2.id, OpenID::Consumer::SUCCESS, @primary_openid_url.str)

    assert_no_difference("OpenidUrl.count") do
      assert_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service2.id)
      end
    end

    assert_response :redirect
    assert /^#{@service2.authenticate_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort,
      CGI.parse(URI(response.location).query).keys.sort
  end

  test "OpenID認証成功後、2回目以降のログインならサービスに戻す" do
    mock_complete_response(@service.id, OpenID::Consumer::SUCCESS, @primary_openid_url.str)

    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service.id)
      end
    end

    assert_response :redirect
    assert /^#{@service.authenticate_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort,
      CGI.parse(URI(response.location).query).keys.sort
    assert_equal @primary_openid_url.profile.id, session[:login_profile_id]
  end

  test "OpenID認証失敗後は失敗としてサービスに戻す" do
    mock_complete_response(@service.id, OpenID::Consumer::FAILURE)

    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service.id)
      end
    end

    assert_redirected_to @service.authenticate_failure
  end

  test "OpenID認証キャンセル後は失敗としてサービスに戻す" do
    mock_complete_response(@service.id, OpenID::Consumer::CANCEL)

    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service.id)
      end
    end

    assert_redirected_to @service.authenticate_failure
  end

  test "不正なOpenID URLをPOSTした場合、認証画面にリダイレクトで戻す" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).begin('invalid url') {
        raise OpenID::DiscoveryFailure.new('', '')
      }
    end

    post :login,
      {:openid_url => 'invalid url', :service_id => @service.id},
      {:login_profile_id => @profile.id}

    assert_redirected_to profile_authenticate_path
    assert_equal @service.id.to_s, flash[:service_id]
  end

  test "ログアウト状態ならOpenIDを削除できない" do
    assert_no_difference('OpenidUrl.count') do
      delete :destroy, :id => @secondary_openid_url
    end
    assert_response :forbidden
  end

  test "別のプロフィールのOpenIDは削除できない" do
    assert_no_difference('OpenidUrl.count') do
      delete :destroy, {:id => @others_openid_url}, {:login_profile_id => @profile.id}
    end
    assert_response :forbidden
  end

  test "自分のプロフィールのOpenIDは削除できる" do
    assert_difference('OpenidUrl.count', -1) do
      delete :destroy, {:id => @secondary_openid_url}, {:login_profile_id => @profile.id}
    end
    assert_redirected_to :controller => :profiles, :action => :show
  end

  test "自分のプライマリOpenIDは削除できない" do
    assert_no_difference('OpenidUrl.count') do
      delete :destroy, {:id => @primary_openid_url}, {:login_profile_id => @profile.id}
    end
    assert_redirected_to :controller => :profiles, :action => :show
  end

  # ID追加
  test "authenticate?mode=id_append flashにモード記録、OPへ" do
    expected = mock_redirect_url

    post :login,
      {:openid_url => 'http://example.com/', :mode => 'id_append'},
      {:login_profile_id => @profile.id}

    assert_redirected_to expected
    assert_equal 'id_append', flash[:auth_mode]
  end

  test "complete id_appendで、今回のIDがプロフィール作成済みならば再度ID入力を求める(ID追加ステップ1完了、2へ)" do
    mock_complete_response(nil, OpenID::Consumer::SUCCESS, @primary_openid_url.str)
    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete,
          @parameters,
          {}, # session
          {:auth_mode => 'id_append'} # flash
      end
    end

    assert_redirected_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
  end

  test "complete id_appendで、今回のIDが新規、5分以内に登録済みID認証が通っていればID追加" do
    mock_complete_response(nil, OpenID::Consumer::SUCCESS, 'http://www.example.com/new-user')
    assert_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete,
          @parameters,
          {
            :login_profile_id => @profile.id,
            :last_login => 4.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          }, # session
          {:auth_mode => 'id_append'} # flash
      end
    end

    assert_redirected_to :controller => :profiles, :action => :show
    assert_equal @profile, assigns(:openid_url).profile
  end

  test "complete id_appendで、今回のIDが新規、登録済みID認証が通ってから5分以上経っていれば再度登録済みID入力を求める" do
    mock_complete_response(nil, OpenID::Consumer::SUCCESS, 'http://www.example.com/new-user')
    assert_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete,
          @parameters,
          {
            :login_profile_id => @profile.id,
            :last_login => 6.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          }, # session
          {:auth_mode => 'id_append'} # flash
      end
    end

    assert_redirected_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
    assert_nil session[:openid_url_id]
    assert_nil session[:last_login]
  end

  test "complete id_appendで、今回のIDが新規、前に登録済みID認証が通っていなければ再度登録済みID入力を求める" do
    mock_complete_response(nil, OpenID::Consumer::SUCCESS, 'http://www.example.com/new-user')
    assert_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete,
          @parameters,
          {:login_profile_id => @profile.id}, # session
          {:auth_mode => 'id_append'} # flash
      end
    end

    assert_redirected_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
    assert_nil session[:openid_url_id]
    assert_nil session[:last_login]
  end
end

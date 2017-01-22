require 'test_helper'

class GoogleOpenidConnectControllerTest < ActionController::TestCase
  def mock_openid_connect_response(identity = nil)
    any_instance_of(OpenIDConnect) do |klass|
      result = {'result' => 'value'}
      mock(klass).authentication_result({"controller"=>"google_openid_connect", "action"=>"complete"}) { result }
      mock(klass).parse_id_token(result) { {'sub' => identity} }
    end
  end

  setup do
    @service = services(:one)
    @service2 = services(:two)
    @primary_openid_url = openid_urls(:profile_google)
    @profile = profiles(:google)

    WebMock.reset!
    @service_conf = stub_service_config_provider(@service)
    @service2_conf = stub_service_config_provider(@service2)
  end

  test "認証開始を叩くとGoogleへリダイレクトする" do
    destination = 'https://path.to/openid_connect_authenticate'
    any_instance_of(OpenIDConnect) do |klass|
      mock(klass).authentication_url('openid', root_url) { destination }
    end

    get :authenticate, :params => {:service_id => @service.id}

    assert_redirected_to destination
    assert_equal @service.id.to_s, flash[:openid_connect_after_service_id]
  end

  test "認証成功後、初回ログインならプロフィール作成画面へ" do
    mock_openid_connect_response(0)

    assert_difference('OpenidUrl.count') do
      get :complete,
        :flash => {:openid_connect_after_service_id => @service.id}
    end

    assert_redirected_to :controller => :profiles,
      :action => :new,
      :service_id => @service.id
    assert session[:openid_url_id].present?
    assert_equal "https://www.google.com/#openid-connect_0", assigns(:openid_url).str
  end

  test "認証成功後、初めて使うサービスなら結びつけてから戻す" do
    mock_openid_connect_response(1)

    assert_no_difference("OpenidUrl.count") do
      assert_difference("ProfileService.count") do
        get :complete,
          :flash => {:openid_connect_after_service_id => @service2.id}
      end
    end
    assert_response :redirect
    assert /^#{@service2.authenticate_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort,
      CGI.parse(URI(response.location).query).keys.sort
  end

  test "認証成功後、使用済みサービスならそのまま戻す" do
    mock_openid_connect_response(1)

    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete,
          :flash => {:openid_connect_after_service_id => @service.id}
      end
    end
    assert_response :redirect
    assert /^#{@service.authenticate_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort,
      CGI.parse(URI(response.location).query).keys.sort
    assert_equal @primary_openid_url.profile.id, session[:login_profile_id]
  end

  test "認証失敗時には失敗としてサービスに戻す" do
    any_instance_of(OpenIDConnect) do |klass|
      mock(klass).authentication_result({"controller"=>"google_openid_connect", "action"=>"complete"}) { raise OpenIDConnect::CancelError.new }
    end

    assert_no_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          :flash => {:openid_connect_after_service_id => @service.id}
      end
    end

    assert_redirected_to @service.authenticate_failure
  end

  test "modeが指定されたらflashに保存してGoogleへリダイレクト" do
    destination = 'https://path.to/openid_connect_authenticate'
    any_instance_of(OpenIDConnect) do |klass|
      mock(klass).authentication_url('openid', root_url) { destination }
    end

    get :authenticate,
      :params => {:service_id => @service.id, :mode => 'id_append'}

    assert_redirected_to destination
    assert_equal 'id_append', flash[:auth_mode]
  end

  test "id_appendで、今回のIDがプロフィール作成済みならば再度ID入力を求める(ID追加ステップ1完了、2へ)" do
    mock_openid_connect_response(1)

    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete,
          :session => {
            :login_profile_id => @profile.id,
            :last_login => 4.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          },
          :flash => {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles,
      :action => :authenticate,
      :mode => 'id_append'
    assert_equal @primary_openid_url.profile.id, session[:login_profile_id]
    assert_equal @primary_openid_url.id, session[:openid_url_id]
  end

  test "id_appendで、今回のIDが新規、5分以内に登録済みID認証が通っていればID追加" do
    mock_openid_connect_response(0)

    assert_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          :session => {
            :login_profile_id => @profile.id,
            :last_login => 4.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          },
          :flash => {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles, :action => :show
    assert_equal @profile, assigns(:openid_url).profile
  end

  test "id_appendで、今回のIDが新規、登録済みID認証が通ってから5分以上経っていれば再度登録済みID入力を求める" do
    mock_openid_connect_response(0)

    assert_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          :session => {
            :login_profile_id => @profile.id,
            :last_login => 6.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          },
          :flash => {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles,
      :action => :authenticate,
      :mode => 'id_append'
  end

  test "id_appendで、今回のIDが新規、前に登録済みID認証が通っていなければ再度登録済みID入力を求める" do
    mock_openid_connect_response(0)

    assert_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          :session => {:login_profile_id => @profile.id},
          :flash => {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
    assert_nil session[:openid_url_id]
    assert_nil session[:last_login]
  end
end

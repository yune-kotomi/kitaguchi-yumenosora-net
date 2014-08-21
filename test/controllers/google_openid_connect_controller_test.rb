require 'test_helper'

class GoogleOpenidConnectControllerTest < ActionController::TestCase
  def mock_openid_connect_response(identity_url = nil)
    any_instance_of(OpenIDConnect) do |klass|
      result = {'result' => 'value'}
      mock(klass).authentication_result({"controller"=>"google_openid_connect", "action"=>"complete"}) { result }
      mock(klass).parse_id_token(result) { {'openid_id' => identity_url} }
    end
  end

  setup do
    @service = services(:one)
    @service2 = services(:two)
    @primary_openid_url = openid_urls(:profile_one_primary)
  end

  test "認証開始を叩くとGoogleへリダイレクトする" do
    destination = 'https://path.to/openid_connect_authenticate'
    any_instance_of(OpenIDConnect) do |klass|
      mock(klass).authentication_url('openid', root_url) { destination }
    end

    get :authenticate, :service_id => @service.id

    assert_redirected_to destination
    assert_equal @service.id.to_s, flash[:openid_connect_after_service_id]
  end

  test "認証成功後、初回ログインならプロフィール作成画面へ" do
    mock_openid_connect_response("http://example.com/user")

    assert_difference('OpenidUrl.count') do
      get :complete, {}, nil, {:openid_connect_after_service_id => @service.id}
    end

    assert_redirected_to :controller => :profiles,
      :action => :new,
      :service_id => @service.id
    assert session[:openid_url_id].present?
    assert_equal "http://example.com/user", assigns(:openid_url).str
  end

  test "認証成功後、初めて使うサービスなら結びつけてから戻す" do
    mock_openid_connect_response(@primary_openid_url.str)

    assert_no_difference("OpenidUrl.count") do
      assert_difference("ProfileService.count") do
        get :complete, {}, nil, {:openid_connect_after_service_id => @service2.id}
      end
    end
    assert_response :redirect
    assert /^#{@service2.auth_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort,
      CGI.parse(URI(response.location).query).keys.sort
  end

  test "認証成功後、使用済みサービスならそのまま戻す" do
    mock_openid_connect_response(@primary_openid_url.str)

    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, {}, nil, {:openid_connect_after_service_id => @service.id}
      end
    end
    assert_response :redirect
    assert /^#{@service.auth_success}/ =~ response.location
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
        get :complete, {}, nil, {:openid_connect_after_service_id => @service.id}
      end
    end

    assert_redirected_to @service.auth_fail
  end
end

require 'test_helper'

class HatenaControllerTest < ActionController::TestCase
  setup do
    @profile = profiles(:one)
    @service = services(:one)
    @service2 = services(:two)
    @primary_openid_url = openid_urls(:profile_one_primary)
  end

  test "hatena_authenticate?mode=id_append flashにモード記録、はてなへ" do
    get :authenticate, :mode => 'id_append'

    assert_response :redirect
    assert_equal 'id_append', flash[:auth_mode]
  end

  test "hatena_complete id_appendで、今回のIDがプロフィール作成済みならば再度ID入力を求める(ID追加ステップ1完了、2へ)" do
    @hatena_id = openid_urls(:hatena_id)

    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => URI(@hatena_id.str).path.gsub('/', '')}}
    end

    assert_no_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          {:cert => 'cert'},
          {
            :login_profile_id => @profile.id,
            :last_login => 4.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          },
          {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
    assert_equal @hatena_id.profile.id, session[:login_profile_id]
    assert_equal @hatena_id.id, session[:openid_url_id]
  end

  test "hatena_complete id_appendで、今回のIDが新規、5分以内に登録済みID認証が通っていればID追加" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => 'new-user'}}
    end

    assert_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          {:cert => 'cert'},
          {
            :login_profile_id => @profile.id,
            :last_login => 4.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          },
          {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles, :action => :show
    assert_equal @profile, assigns(:openid_url).profile
  end

  test "hatena_complete id_appendで、今回のIDが新規、登録済みID認証が通ってから5分以上経っていれば再度登録済みID入力を求める" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => 'new-user'}}
    end

    assert_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          {:cert => 'cert'},
          {
            :login_profile_id => @profile.id,
            :last_login => 6.minutes.ago.to_i,
            :openid_url_id => @primary_openid_url.id
          },
          {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
  end

  test "hatena_complete id_appendで、今回のIDが新規、前に登録済みID認証が通っていなければ再度登録済みID入力を求める" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => 'new-user'}}
    end

    assert_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete,
          {:cert => 'cert'},
          {:login_profile_id => @profile.id},
          {:auth_mode => 'id_append'}
      end
    end

    assert_redirected_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
    assert_nil session[:openid_url_id]
    assert_nil session[:last_login]
  end

  test "はてな認証開始を叩くとはてなへリダイレクトする" do
    get :authenticate, :service_id => @service.id

    assert_response :redirect
    params = CGI.parse(URI(response.location).query)
    assert_equal ['api_key', 'api_sig'].sort, params.keys.sort
    assert_equal @service.id.to_s, flash[:hatena_after_service_id]
  end

  test "はてな認証成功後、初回ログインならプロフィール作成画面へ" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => 'new-user'}}
    end

    assert_difference('OpenidUrl.count') do
      get :complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service.id}
    end

    assert_redirected_to :controller => :profiles, :action => :new, :service_id => @service.id
    assert session[:openid_url_id].present?
    assert_equal "http://www.hatena.ne.jp/new-user/", assigns(:openid_url).str
  end

  test "はてな認証成功後、初めて使うサービスなら結びつけてから戻す" do
    @hatena_id = openid_urls(:hatena_id)

    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => URI(@hatena_id.str).path.gsub('/', '')}}
    end

    assert_no_difference('OpenidUrl.count') do
      assert_difference('ProfileService.count') do
        get :complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service2.id}
      end
    end

    assert_response :redirect
    assert /^#{@service2.authenticate_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort,
      CGI.parse(URI(response.location).query).keys.sort
  end

  test "はてな認証成功後、使用済みサービスならそのまま戻す" do
    @hatena_id = openid_urls(:hatena_id)

    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => URI(@hatena_id.str).path.gsub('/', '')}}
    end

    assert_no_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service.id}
      end
    end

    assert_response :redirect
    assert /^#{@service.authenticate_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort,
      CGI.parse(URI(response.location).query).keys.sort
    assert_equal @hatena_id.profile.id, session[:login_profile_id]
    assert_equal @hatena_id.id, session[:openid_url_id]
  end

  test "はてな認証失敗時は失敗としてサービスに戻す" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {
        raise Hatena::API::AuthError.new
      }
    end

    assert_no_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service.id}
      end
    end

    assert_redirected_to @service.authenticate_failure
  end
end

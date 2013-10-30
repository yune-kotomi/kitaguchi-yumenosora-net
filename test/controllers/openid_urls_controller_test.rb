require 'test_helper'

class OpenidUrlsControllerTest < ActionController::TestCase
  setup do
    @profile = profiles(:one)
    @service = services(:one)
    @service2 = services(:two)
    @primary_openid_url = openid_urls(:profile_one_primary)
    
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
  end

  test "OpenID URLをPOSTするとOPへリダイレクトする" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).begin('http://example.com/') {
        mock!.redirect_url(
          'http://test.host/',
          "http://test.host/openid_urls/complete/#{@service.id}"
        ) {'http://example.com/openid-provider-url'}
      }
    end
    
    post :login, 
      {:openid_url => 'http://example.com/', :service_id => @service.id}, 
      {:login_profile_id => @profile.id}
    
    assert_redirected_to 'http://example.com/openid-provider-url'
  end
  
  test "OpenID認証成功後、初回ログインならプロフィール作成画面へ" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete/#{@service.id}"
      ) {
        response = mock!
        response.identity_url { @parameters['openid.identity'] }
        response.status { OpenID::Consumer::SUCCESS }
        
        response
      }
    end
    
    assert_difference("OpenidUrl.count") do
      get :complete, @parameters.merge(:service_id => @service.id)
    end
    
    assert_redirected_to :controller => :profiles, 
      :action => :new,
      :service_id => @service.id
    assert session[:openid_url_id].present?
  end
  
  test "OpenID認証成功後、初めて使うサービスなら結びつけたあとでサービスに戻す" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete/#{@service2.id}"
      ) {
        response = mock!
        response.identity_url { @primary_openid_url.str }
        response.status { OpenID::Consumer::SUCCESS }
        
        response
      }
    end
    
    assert_no_difference("OpenidUrl.count") do
      assert_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service2.id)
      end
    end
    
    assert_response :redirect
    assert /^#{@service2.auth_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort, 
      CGI.parse(URI(response.location).query).keys.sort
  end
  
  test "OpenID認証成功後、2回目以降のログインならサービスに戻す" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete/#{@service.id}"
      ) {
        response = mock!
        response.identity_url { @primary_openid_url.str }
        response.status { OpenID::Consumer::SUCCESS }
        
        response
      }
    end
    
    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service.id)
      end
    end
    
    assert_response :redirect
    assert /^#{@service.auth_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort, 
      CGI.parse(URI(response.location).query).keys.sort
    assert_equal @primary_openid_url.profile.id, session[:login_profile_id]
  end
  
  test "追加登録の場合はOpenID認証成功後プロフィールへ結びつけ" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete"
      ) {
        response = mock!
        response.identity_url { 'http://www.example.com/new-id' }
        response.status { OpenID::Consumer::SUCCESS }
        
        response
      }
    end
    
    assert_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, 
          @parameters, 
          {
            :login_profile_id => @profile.id, 
            :openid_url_id => @primary_openid_url.id, 
            :last_login => Time.now.to_i
          }
      end
    end
    
    assert_redirected_to :controller => :profiles, :action => :show
    assert_equal assigns(:openid_url).profile, @profile
  end
  
  test "OpenID認証成功だが既にプロフィールに結びついている場合追加登録しない" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete"
      ) {
        response = mock!
        response.identity_url { @others_openid_url.str }
        response.status { OpenID::Consumer::SUCCESS }
        
        response
      }
    end
    
    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, 
          @parameters, 
          {
            :login_profile_id => @profile.id, 
            :openid_url_id => @primary_openid_url.id, 
            :last_login => Time.now.to_i
          }
      end
    end
    
    assert_redirected_to :controller => :profiles, :action => :show
    assert_not_equal assigns(:openid_url).profile, @profile
  end
  
  test "前回のログイン時刻が5分以上経っている場合追加登録しない" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete"
      ) {
        response = mock!
        response.identity_url { 'http://www.example.com/new-id' }
        response.status { OpenID::Consumer::SUCCESS }
        
        response
      }
    end
    
    assert_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, 
          @parameters, 
          {
            :login_profile_id => @profile.id, 
            :openid_url_id => @primary_openid_url.id, 
            :last_login => 1.day.ago.to_i
          }
      end
    end
    
    assert_redirected_to :controller => :profiles, :action => :new
    assert_not_equal assigns(:openid_url).profile, @profile
  end
  
  test "OpenID認証失敗後は失敗としてサービスに戻す" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete/#{@service.id}"
      ) {
        response = mock!
        response.status { OpenID::Consumer::FAILURE }
        
        response
      }
    end
    
    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service.id)
      end
    end
    
    assert_redirected_to @service.auth_fail
  end
  
  test "OpenID認証キャンセル後は失敗としてサービスに戻す" do
    any_instance_of(OpenID::Consumer) do |klass|
      mock(klass).complete(
        @parameters, 
        "http://test.host/openid_urls/complete/#{@service.id}"
      ) {
        response = mock!
        response.status { OpenID::Consumer::CANCEL }
        
        response
      }
    end
    
    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :complete, @parameters.merge(:service_id => @service.id)
      end
    end
    
    assert_redirected_to @service.auth_fail
  end
  
  test "はてな認証開始を叩くとはてなへリダイレクトする" do
    get :hatena_authenticate, :service_id => @service.id

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
      get :hatena_complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service.id}
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
        get :hatena_complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service2.id}
      end
    end
    
    assert_response :redirect
    assert /^#{@service2.auth_success}/ =~ response.location
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
        get :hatena_complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service.id}
      end
    end
    
    assert_response :redirect
    assert /^#{@service.auth_success}/ =~ response.location
    assert ['id', 'key', 'timestamp', 'signature'].sort, 
      CGI.parse(URI(response.location).query).keys.sort
    assert_equal @hatena_id.profile.id, session[:login_profile_id]
    assert_equal @hatena_id.id, session[:openid_url_id]
  end
  
  test "追加登録の場合、はてな認証成功後プロフィールに結びつけ" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => 'new-user'}}
    end
  
    assert_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :hatena_complete, 
          {:cert => 'cert'},
          {
            :login_profile_id => @profile.id, 
            :openid_url_id => @primary_openid_url.id, 
            :last_login => Time.now.to_i
          }
      end
    end
    
    assert_redirected_to :controller => :profiles, :action => :show
    assert_equal assigns(:openid_url).profile, @profile
  end
  
  test "はてな認証成功だが登録済みのIDの場合はプロフィール結びつけをしない" do
    @hatena_id = openid_urls(:hatena_id)
    
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => URI(@hatena_id.str).path.gsub('/', '')}}
    end
  
    assert_no_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :hatena_complete, 
          {:cert => 'cert'},
          {
            :login_profile_id => @profile.id, 
            :openid_url_id => @primary_openid_url.id, 
            :last_login => Time.now.to_i
          }
      end
    end
    
    assert_redirected_to :controller => :profiles, :action => :show
    assert_not_equal assigns(:openid_url).profile, @profile
  end
  
  test "前回ログインから5分以上経っていたらはてな認証後の追加登録をしない" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {{'name' => 'new-user'}}
    end
  
    assert_difference("OpenidUrl.count") do
      assert_no_difference("ProfileService.count") do
        get :hatena_complete, 
          {:cert => 'cert'},
          {
            :login_profile_id => @profile.id, 
            :openid_url_id => @primary_openid_url.id, 
            :last_login => 6.minutes.ago.to_i
          }
      end
    end
  
    assert_redirected_to :controller => :profiles, :action => :new
    assert_not_equal assigns(:openid_url).profile, @profile
  end
  
  test "はてな認証失敗時は失敗としてサービスに戻す" do
    any_instance_of(Hatena::API::Auth) do |klass|
      mock(klass).login('cert') {
        raise Hatena::API::AuthError.new
      }
    end
    
    assert_no_difference('OpenidUrl.count') do
      assert_no_difference('ProfileService.count') do
        get :hatena_complete, {:cert => 'cert'}, nil, {:hatena_after_service_id => @service.id}
      end
    end
    
    assert_redirected_to @service.auth_fail
  end
end


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
  
  test "認証成功後、初回ログインならプロフィール作成画面へ" do
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
  
  test "認証成功後、初めて使うサービスなら結びつけたあとでサービスに戻す" do
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
  
  test "認証成功後、2回目以降のログインならサービスに戻す" do
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
  
  test "追加登録の場合は認証成功後プロフィールへ結びつけ" do
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
  
  test "認証成功だが既にプロフィールに結びついている場合追加登録しない" do
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
  
  test "認証失敗後は失敗としてサービスに戻す" do
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
  
  test "認証キャンセル後は失敗としてサービスに戻す" do
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
end

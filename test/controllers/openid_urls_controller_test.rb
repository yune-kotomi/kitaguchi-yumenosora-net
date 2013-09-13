require 'test_helper'

class OpenidUrlsControllerTest < ActionController::TestCase
  setup do
    @openid_url = openid_urls(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:openid_urls)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create openid_url" do
    assert_difference('OpenidUrl.count') do
      post :create, openid_url: {  }
    end

    assert_redirected_to openid_url_path(assigns(:openid_url))
  end

  test "should show openid_url" do
    get :show, id: @openid_url
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @openid_url
    assert_response :success
  end

  test "should update openid_url" do
    patch :update, id: @openid_url, openid_url: {  }
    assert_redirected_to openid_url_path(assigns(:openid_url))
  end

  test "should destroy openid_url" do
    assert_difference('OpenidUrl.count', -1) do
      delete :destroy, id: @openid_url
    end

    assert_redirected_to openid_urls_path
  end
end

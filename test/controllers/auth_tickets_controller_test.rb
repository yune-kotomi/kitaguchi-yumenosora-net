require 'test_helper'

class AuthTicketsControllerTest < ActionController::TestCase
  setup do
    @auth_ticket = auth_tickets(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:auth_tickets)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create auth_ticket" do
    assert_difference('AuthTicket.count') do
      post :create, auth_ticket: {  }
    end

    assert_redirected_to auth_ticket_path(assigns(:auth_ticket))
  end

  test "should show auth_ticket" do
    get :show, id: @auth_ticket
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @auth_ticket
    assert_response :success
  end

  test "should update auth_ticket" do
    patch :update, id: @auth_ticket, auth_ticket: {  }
    assert_redirected_to auth_ticket_path(assigns(:auth_ticket))
  end

  test "should destroy auth_ticket" do
    assert_difference('AuthTicket.count', -1) do
      delete :destroy, id: @auth_ticket
    end

    assert_redirected_to auth_tickets_path
  end
end

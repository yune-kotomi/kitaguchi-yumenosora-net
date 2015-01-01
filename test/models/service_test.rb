require 'test_helper'
include WebMock::API

class ServiceTest < ActiveSupport::TestCase
  def sign(message)
    OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.key, message)
  end

  setup do
    @one = services :one
    @profile = profiles :one
  end

  test "認証依頼を検証できる" do
    params = {:id => @one.id, :timestamp => Time.now.to_i}
    params[:signature] = sign([params[:id], params[:timestamp], 'authenticate'].join)

    assert @one.validate_authenticate_request(params)
  end

  test "認証依頼が不正な場合、例外を吐く" do
    params = {:id => @one.id, :timestamp => Time.now.to_i}
    params[:signature] = 'invalid'

    assert_raise Service::InvalidSignatureError do
      @one.validate_authenticate_request(params)
    end
  end

  test "認証依頼リクエストが古い場合、例外を吐く" do
    params = {:id => @one.id, :timestamp => 10.minutes.ago.to_i}
    params[:signature] = sign([params[:id], params[:timestamp], 'authenticate'].join)

    assert_raise Service::InvalidSignatureError do
      @one.validate_authenticate_request(params)
    end
  end

  test "profile_updateに指定されたURLへPOSTでプロフィール内容変更の通知を送る" do
    stub_request(:any, "www.example.com")
    @one.notice(@profile)

    assert_requested :post, @one.profile_update, :times => 1 do |request|
      params = CGI.parse(request.body)

      message = [
        @one.id,
        params['profile_id'].first,
        params['nickname'].first,
        params['profile_text'],
        params['timestamp'].first,
        'update'
      ].join
      expected = OpenSSL::HMAC::hexdigest(OpenSSL::Digest::SHA256.new, @one.key, message)

      expected == params['signature'].first
    end
  end
end

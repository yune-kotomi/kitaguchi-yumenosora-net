require 'test_helper'
include WebMock::API

class ServiceTest < ActiveSupport::TestCase
  setup do
    @one = services :one
    @profile = profiles :one
  end

  test "profile_updateに指定されたURLへPOSTでプロフィール内容変更の通知を送る" do
    payload = stub_service_config_provider(@one)

    stub_request(:any, URI(payload['root']).host)
    @one.notice(@profile)

    assert_requested :post, payload['profile']['update'], :times => 1 do |request|
      params = CGI.parse(request.body)
      payload = JWT.decode(params['token'].first, @one.key).first
      expected = {
        'id' => @one.id,
        'profile_id' => @profile.id,
        'nickname' => @profile.nickname,
        'profile_text' => @profile.profile_html(:section_anchor_prefix => "profile_")
      }

      assert payload['exp'].present?
      expected.each {|k, v| assert_equal v, payload[k] }
    end
  end

  test "ロゴやリダイレクト先をクライアントから取得できる" do
    Rails.cache.delete("service-remote-config-#{@one.id}")

    payload = stub_service_config_provider(@one)

    assert_equal payload['logo'], @one.logos
    assert_equal payload['banner'], @one.banners
    assert_equal payload['root'], @one.root
    assert_equal payload['authenticate']['success'], @one.authenticate_success
    assert_equal payload['authenticate']['failure'], @one.authenticate_failure
    assert_equal payload['profile']['back'], @one.user_page_url
  end
end

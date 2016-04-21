require 'test_helper'

class ProfilesHelperTest < ActionView::TestCase
  include ProfilesHelper

  setup do
    WebMock.reset!
    @user = profiles(:two)
    @service = services(:one)
    @service_conf = stub_service_config_provider(@service)
  end

  test 'back_from_profileはサービスに戻すURLを返す' do
    actual = back_from_profile(@service, @user)
    expected = "https://www#{@service.id}.example.com/back_from_profile/#{@user.domain_name}/#{@user.screen_name}"
    assert_equal expected, actual
  end

  test '表示用ラベルを返す(はてな)' do
    assert_equal 'はてなID', openid_label('http://www.hatena.ne.jp/yune_kotomi/')
  end

  test '表示用ラベルを返す(livedoor)' do
    assert_equal 'livedoor ID', openid_label('http://profile.livedoor.com/yune_kotomi/')
  end

  test '表示用ラベルを返す(mixi)' do
    assert_equal 'mixi OpenID', openid_label('https://id.mixi.jp/example/')
  end

  test '表示用ラベルを返す(Google)' do
    assert_equal 'Googleアカウント', openid_label('https://www.google.com/accounts/o8/id?id=example')
  end

  test '表示用ラベルを返す(Yahoo!)' do
    assert_equal 'Yahoo! JAPAN ID', openid_label('https://me.yahoo.co.jp/a/example/')
  end

  test '表示用ラベルを返す(汎用OpenID)' do
    url = 'http://example.com/id'
    assert_equal url, openid_label(url)
  end
end

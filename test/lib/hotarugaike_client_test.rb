require_relative '../../lib/hotarugaike_client'
include WebMock::API

class HotarugaikeProfileClientTest < ActiveSupport::TestCase
  setup do
    @params = {
      :service_id => 1,
      :key => "xxxxxxxxxxxxxxxx",
      :entry_point => 'http://kitaguchi.yumenosora.net/profile'
    }
    @client = Hotarugaike::Profile::Client.new(@params)
    WebMock.reset!
  end

  test '認証開始URLを返す' do
    uri = @client.start_authentication
    assert uri.start_with?(@params[:entry_point])

    query = URI(uri).query.split('&').map{|q| q.split('=') }.to_h
    assert_equal @params[:service_id], query['id'].to_i

    token = query['token']
    assert JWT.decode(token, @params[:key])

    payload = JWT.decode(token, @params[:key]).first
    assert_equal ['id', 'exp'].sort, payload.keys.sort
    assert payload['exp'] <= 5.minutes.from_now.to_i
  end

  test '認証情報を取得して返す' do
    payload = {
      'key' => 'authorization-key',
      'exp' => 5.minutes.from_now.to_i
    }
    token = JWT.encode(payload, @params[:key])

    expected = {
      'profile_id' => 553,
      'domain_name' => 'www.example.com',
      'screen_name' => 'screen_name',
      'nickname' => 'nickname',
      'profile_text' => 'profile html',
      'openid_url' => 'http://www.example.com/id',
      'exp' => 5.minutes.from_now.to_i
    }
    stub_request(:get, /#{@params[:entry_point]}\/retrieve\?id=#{@client.service_id}&token=.+/).with do |request|
      query = request.uri.query.split('&').map{|q| q.split('=') }.to_h
      query['id'] == @params[:service_id].to_s && JWT.decode(query['token'], @params[:key])
    end.to_return(:status => 200, :body => JWT.encode(expected, @params[:key]), :headers => {:content_type => 'text/plain'})

    result = @client.retrieve(token)
    assert_equal expected, result
  end

  test '取得した認証情報に期限がない場合は失敗する' do
    payload = {
      'key' => 'authorization-key',
      'exp' => 5.minutes.from_now.to_i
    }
    token = JWT.encode(payload, @params[:key])

    expected = {
      'profile_id' => 553,
      'domain_name' => 'www.example.com',
      'screen_name' => 'screen_name',
      'nickname' => 'nickname',
      'profile_text' => 'profile html',
      'openid_url' => 'http://www.example.com/id'
    }
    stub_request(:get, /#{@params[:entry_point]}\/retrieve.*/).with do |request|
      query = request.uri.query.split('&').map{|q| q.split('=') }.to_h
      query['id'] == @params[:service_id].to_s && JWT.decode(query['token'], @params[:key])
    end.to_return(:status => 200, :body => JWT.encode(expected, @params[:key]), :headers => {:content_type => 'text/plain'})

    assert_raises Hotarugaike::Profile::Client::InvalidProfileExchangeError do
      @client.retrieve(token)
    end
  end

  test 'ログアウトURLを返す' do
    assert_equal "#{@params[:entry_point]}/logout?id=#{@params[:service_id]}", @client.logout
  end

  test 'プロフィール編集URLを返す' do
    assert_equal "#{@params[:entry_point]}?service_id=#{@params[:service_id]}", @client.edit
  end

  test '更新通知されたプロフィールを展開する' do
    expected = {
      'profile_id' => 553,
      'domain_name' => 'www.example.com',
      'screen_name' => 'screen_name',
      'nickname' => 'nickname',
      'profile_text' => 'profile html',
      'exp' => 5.minutes.from_now.to_i
    }
    payload = @client.updated_profile(JWT.encode(expected, @params[:key]))
    assert_equal expected, payload
  end
end

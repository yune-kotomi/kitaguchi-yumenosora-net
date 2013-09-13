json.array!(@openid_urls) do |openid_url|
  json.extract! openid_url, 
  json.url openid_url_url(openid_url, format: :json)
end

def login_with(openid)
  Element.find('#openid_url').value = openid
  Element.find('#openid-form form').submit
end

Document.ready? do
  ({
    'livedoor' => 'http://livedoor.com',
    'mixi' => 'https://mixi.jp',
    'yahoojp' => 'yahoo.co.jp'
  }).each do |key, openid|
    Element.find("##{key}").on('click') do
      login_with(openid)
    end
  end
end

def login_with(openid)
  Element.find('#openid_url').value = openid
  Element.find('#openid-form form').submit
end

Document.ready? do
  Element.find('#livedoor,#mixi,#google,#yahoojp,#submit').on('click') do
    Ojikoen::UI::Column.scroll_forward
  end

  ({
    'livedoor' => 'http://livedoor.com',
    'mixi' => 'https://mixi.jp',
    'google' => 'https://www.google.com/accounts/o8/id',
    'yahoojp' => 'yahoo.co.jp'
  }).each do |key, openid|
    Element.find("##{key}").on('click') do
      login_with(openid)
    end
  end
  
  Element.find('#submit').on('click') do
    Element.find('#openid-form form').submit
  end
end


def login_with(openid)
  Element.find('#openid_url').value = openid
  Element.find('#openid-form form').submit
end

Document.ready? do
  # ログインボタン群
  Element.find('.specific-id-button').each do |button|
    button.on('click') do
      url = button['data-url']
      login_with(url)
    end
  end

  # 「その他の〜」ダイアログ
  Element.find('#other-openid').on('click') do
    Element.find('#openid-form').fade_in
    false
  end

  Element.find('#openid-form .close-button').on('click') do
    Element.find('#openid-form').fade_out
    false
  end
end

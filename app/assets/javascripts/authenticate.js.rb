def login_with(openid)
  Element.find('#openid_url').value = openid
  Element.find('#openid-login form').submit
end

Document.ready? do
  # ログインボタン群
  Element.find('.specific-id-button').each do |button|
    button.on('click') do
      url = button['data-url']
      login_with(url)
    end
  end

  dialog = Element.find('#openid-login')
  unless dialog.empty?
    Element.find('#other-openid').on('click') { `#{dialog.get(0)}.showModal()`}
    `dialogPolyfill.registerDialog(#{dialog.get(0)})`
    dialog.find('button[type="button"]').on('click') { `#{dialog.get(0)}.close()` }
  end
end

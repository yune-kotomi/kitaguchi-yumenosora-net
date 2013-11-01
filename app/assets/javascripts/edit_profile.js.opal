Document.ready? do
  form = Element.find('form.edit_profile')
  previous_form = form.serialize
  
  Element.find(".input-field input[type='text'],.input-field textarea").on('blur') do
    unless previous_form == form.serialize
      previous_form = form.serialize
      HTTP.post(form['action'], :payload => form.serialize) do |response|
        if response.ok?
          puts 'success'
        else
          puts response
        end
      end
    end
  end
  
  Element.find('.delete-openid').each do |delete_menu|
    delete_menu.on('click') do
      Ojikoen::UI::Dialog.new(
        'ok' => 'はい',
        'cancel' => 'いいえ',
        'title' => 'OpenIDの削除',
        'message' => '本当にこのOpenIDを削除してよろしいですか?'
      ) do |value|
        id = delete_menu['data-id']
        Element.find("#delete_openid_url_#{id}").submit
      end.open
    end
  end
end


Document.ready? do
  form = Element.find('form.edit_profile')
  previous_form = form.serialize

  form.find("input[type='text'],textarea").on('blur') do
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

  Element.find('#openid-list .list-item').each do |anchor|
    anchor.on('click') do |e|
      id = anchor['data-id']
      Element.find("#openid-dialog-#{id}").fade_in
      false
    end
  end

  Element.find('.modal .close-button').each do |button|
    button.on('click') do
      id = button['data-id']
      Element.find("#openid-dialog-#{id}").fade_out
      false
    end
  end
end

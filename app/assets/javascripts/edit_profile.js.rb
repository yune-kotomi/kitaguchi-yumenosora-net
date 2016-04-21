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

  dialog = Element.find('#openid-delete')
  unless dialog.empty?
    `dialogPolyfill.registerDialog(#{dialog.get(0)})`

    Element.find('button.openid-delete').each do |button|
      button.on('click') do
        id = button['data-id']
        Element.find('#openid-label').text = Element.find("#openid-#{id} span.label").text
        dialog['data-id'] = id
        `#{dialog.get(0)}.showModal()`
      end
    end
    dialog.find('.mdl-button').on('click') { `#{dialog.get(0)}.close()` }
    dialog.find('#execute-delete').on('click') do
      id = dialog['data-id']
      HTTP.delete("/openid_urls/#{id}.json") do |request|
        if request.ok?
          Element.find("#openid-#{id}").remove
        end
      end
    end
  end
end

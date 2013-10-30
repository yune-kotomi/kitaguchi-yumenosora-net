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
end


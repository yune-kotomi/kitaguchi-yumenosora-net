Document.ready? do
  snackbar = Element.find('#errors')
  unless snackbar.empty?
    %x{
      setTimeout(function(){
        #{snackbar.get(0)}.MaterialSnackbar.showSnackbar({message: 'ニックネームは必須項目です'});
      }, 400)
    }
  end
end

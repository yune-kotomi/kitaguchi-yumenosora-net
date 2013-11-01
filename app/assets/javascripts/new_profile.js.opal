Document.ready? do
  Element.find('#submit').on('click') do
    Ojikoen::UI::Column.scroll_forward
    Element.find('form').submit
  end
end


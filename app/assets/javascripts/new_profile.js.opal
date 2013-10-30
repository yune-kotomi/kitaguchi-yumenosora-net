Document.ready? do
  Element.find('#submit').on('click') do
    Ojikoen::UI::Column.scroll_forward
    `$('form').submit()`
  end
end


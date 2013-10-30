require '../utils/jquery.tmpl.js'

class Element
  def template(values = {})
    `#{self}.tmpl(#{values.to_n})`
  end
end

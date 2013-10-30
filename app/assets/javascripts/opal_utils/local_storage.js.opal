module LocalStorage
  def self.[](key)
    value = `localStorage.getItem(#{key})`
    JSON.parse(value)
  end
  
  def self.[]=(key, value)
    `localStorage.setItem(#{key}, #{value.to_json})`
  end
end


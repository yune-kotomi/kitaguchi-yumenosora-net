class Timer
  # 定期的に実行
  def periodically(interval, &block)
    callback = `function(){ #{block.call}; }`
    `setInterval(callback, #{interval * 1000})`    
  end
  
  # 遅延実行
  def after(interval, &block)
    callback = `function(){ #{block.call}; }`
    `setTimeout(callback, #{interval * 1000})`  
  end
end

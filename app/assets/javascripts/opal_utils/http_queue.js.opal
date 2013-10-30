class HttpQueue
  def initialize(&block)
    @block = block
    @queue = []
  end
  
  def enqueue
    id = UUIDGenerator.generate
    
    @queue.push id
    return id
  end
  
  def dequeue(id)
    @queue.delete(id)
    
    if @queue.empty?
      @block.call
    end
  end
end

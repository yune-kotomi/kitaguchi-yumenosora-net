class Element
  def text
    `#{self}.text() || ""`
  end
  
  def serialize
    `#{self}.serialize()`
  end
  
  alias_native :parents, :parents
  
  alias_native :fade_in, :fadeIn
  alias_native :fade_out, :fadeOut
  
  alias_native :outer_height, :outerHeight
  alias_native :inner_height, :innerHeight
  alias_native :outer_width, :outerWidth
  alias_native :inner_width, :innerWidth
  
  alias_native :scroll_left, :scrollLeft
  alias_native :scroll_top, :scrollTop
  
  def scroll_left=(value)
    `#{self}.scrollLeft(#{value})`
  end
  
  def scroll_top=(value)
    `#{self}.scrollTop(#{value})`
  end
  
  def offset
    value = `#{self}.offset()`
    ret = {
      :top => `value.top`,
      :left => `value.left`
    }
    
    return ret
  end
  
  def unbind(event_name=nil)
    `#{self}.unbind(#{event_name})`
  end
  
  def sortable(params, &block)
    %x{
      var p = #{params.to_n};
      p['update'] = function(event, ui){
        return #{block.call `event, ui`}
      }
      #{self}.sortable(p);
    }
  end
end

module Window
  def self.inner_height
    return Element.find(`window`).inner_height
  end
  
  def self.inner_width
    return Element.find(`window`).inner_width
  end
  
  def self.on(name, selector = nil)
    Element.find(`window`).on(name, selector) do
      yield
    end
  end
end

# HTTPにFormDataを渡すとto_jsonしようとするので
class MultipartHttp < HTTP
  def initialize(url, method, options, handler=nil)
    @url     = url
    @method  = method
    @ok      = true
    @xhr     = nil
    http     = self
    payload  = options.delete :payload
    settings = options.to_n

    if handler
      @callback = @errback = handler
    end

    %x{
      settings.data = payload;

      settings.url  = url;
      settings.type = method;

      settings.success = function(data, status, xhr) {
        http.body = data;
        http.xhr = xhr;

        if (typeof(data) === 'object') {
          http.json = #{ JSON.from_object `data` };
        }

        return #{ http.succeed };
      };

      settings.error = function(xhr, status, error) {
        http.body = xhr.responseText;
        http.xhr = xhr;

        return #{ http.fail };
      };
    }

    @settings = settings
  end
end

def p(value)
  `console.log(#{value})`
end


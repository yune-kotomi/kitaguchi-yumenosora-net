module Ojikoen
  module UI
    COMMON_MARGIN = 10
    
    # move_to(selector) 与えられたセレクタで指定された要素を含むカラムへ移動
    # scroll_forward 右向きにスクロールアウト
    # scroll_backward 左向きにスクロールアウト
    # standard_width カラム幅
    # standard_height カラム可視高さ
    class Column
      def self.init
        @@column = self.new
      end
      
      def self.move_to(selector)
        @@column.move_to(selector)
      end
      
      def self.scroll_forward
        position = Element.find('html,body').scroll_left+2000
        `$('html,body').animate({scrollLeft: #{position}}, 200, 'swing')`
        Element.find('body').fade_out
      end
      
      def self.scroll_backward
        position = Element.find('html,body').scroll_left - 2000
        `$('html,body').animate({scrollLeft: #{position}}, 200, 'swing')`
        Element.find('body').fade_out
      end
      
      def self.reinitialize(target)
        %x{
          #{target}.find('.scroll-panel').each(function(){
            if(typeof($(this).data('jsp')) == 'undefined'){
              $(this).jScrollPane();
            }else{
              $(this).data('jsp').reinitialise();
            }
          });
        }
      end
      
      def initialize(body)
        @current_index = 0
        @body = Element.find('#content>div.column')
        
        @body.size.times do |i|
          column = @body.at(i)
          column['data-index'] = i
          column.add_class('main-column')
          column.hide if i > 0
        end
        
        # パンくずリストの固定リンクにイベントハンドラを設定
        Element.find('div.breadcrumb>ul>li').each do |li|
          li.find('a').on('click') do
            Ojikoen::UI::Column.scroll_backward
          end
        end
        
        # カラムごとのパンくずリストを追加
        @breadcrumbs = []
        @body.size.times do |i|
          li = Element.new('li')
          li['data-index'] = i
          li.on('click') do
            Element.find(li['data-selector']).find('li.active').remove_class('active')
            self.move_to(li['data-selector'])
          end
          Element.find('div.breadcrumb>ul').append(li)
          @breadcrumbs.push(li)
        end
        
        # 幅・高さ
        css = Element.new('style')
        # エフェクト用の余白に左右１画面分(=半カラム２つ分)加算
        column_count = Element.find('#content>div.column.half').size + 
          Element.find('#content>div.column.full').size*2 + 4
        body_width = column_count * 50
        column_width = 100 / body_width * 50
        breadcrumb_width = (Element.find('div.breadcrumb>ul>li').outer_width + COMMON_MARGIN) *
          Element.find('div.breadcrumb>ul>li').size
        css.html = <<EOS
body>div.container {
  width: #{body_width}%;
}
div.container>div.column.half {
  width: #{column_width}%;
}
div.container>div.column.full {
  width: #{column_width * 2}%;
}
div.breadcrumb>ul {
  width: #{breadcrumb_width}px;
}
EOS
        Element.find('head').append(css)
        @height_css = Element.new('style')
        Element.find('head').append(@height_css)
        Window.on('resize') do
          breadcrumb_resize
          if resized
            self.class.reinitialize(Element.find('body'))
          end
        end
        
        breadcrumb_resize
        resized
        `$('.scroll-panel').jScrollPane()`
        
        Element.find('body').find('img').on('load') do
          self.class.reinitialize(Element.find('body'))
        end
        
        update_util_styles
      end
      
      def move_to(selector)
        target = Element.find(selector)
        columns = target.parents
        columns.size.times do |i|
          column = columns.at(i)
          if column.has_class?('main-column')
            index = column['data-index'].to_i
            
            # 表示中カラムより先を隠す
            @body.each do |c|
              if c['data-index'].to_i > index
                c.find('.menu>li').remove_class('active')
                c.fade_out
              else
                c.fade_in
              end
            end
            
            # 指定カラムの右端がウィンドウ右端になるように横スクロール
            if column.has_class?('half')
              if index == 0
                # トップレベルカラムでhalfの場合、画面中央に表示
                position = column.offset[:left] - column.outer_width/2
              else
                position = column.offset[:left] - column.outer_width
              end
            else
              position = column.offset[:left]
            end
            Ojikoen::UI.scroll_x_to(position)
            
            # 表示中のカラムより先のパンくずリストを隠す
            @breadcrumbs.each do |li|
              if li['data-index'].to_i > index
                li.fade_out
              else
                li.fade_in
              end
            end
            
            # 表示中のカラムのパンくずを右端にする。領域に余裕があればトップレベルを左端に。
            container = Element.find('div.breadcrumb')
            breadcrumb = Element.find("div.breadcrumb li[data-index='#{index}']")
            position = container.scroll_left + 
              breadcrumb.offset[:left] - container.offset[:left] + 
              breadcrumb.outer_width - 
              container.inner_width
            container.scroll_left = position
            
            # パンくずを更新
            breadcrumb.text = target['data-title']
            breadcrumb['data-selector'] = selector
            
            # 同一カラム中の他の要素を隠す
            target.show
            column.find(".column-element:not(#{selector})").hide
            
            # 縦スクロール設定
            self.class.reinitialize(column)
          end
        end
      end
      
      private
      def breadcrumb_resize
        target = Element.find('div.breadcrumb')
        width = Window.inner_width - Element.find('div.banner').outer_width - COMMON_MARGIN
        target.css('width', "#{width}px")
      end
      
      def resized
        height = `$(window).innerHeight()` - Element.find('#header').outer_height
        ret = (@previous_height != height)
        if ret == true
          @previous_height = height
          @height_css.html = <<EOS
body>div.container {
  height: #{height}px;
}
div.scroll-panel {
  height: #{height}px;
}
EOS
        end
        
        update_util_styles
        
        ret
      end
      
      # カラム幅・高さのCSSクラス定義
      def update_util_styles
        target = Element.find('style#util-styles')
        if target.size == 0
          target = Element.new('style')
          target['id'] = 'util-styles'
          Element.find('head').append(target)
        end
        
        target.text = <<EOS
.standard-width {
  width: #{Ojikoen::UI.standard_width}px;
}
.standard-height {
  height: #{Ojikoen::UI.standard_height}px;
}

.content .standard-width {
  width: #{Ojikoen::UI.standard_width - Ojikoen::UI::COMMON_MARGIN * 2}px;
}
.content .standard-height {
  height: #{Ojikoen::UI.standard_height - Ojikoen::UI::COMMON_MARGIN * 2}px;
}
EOS
      end
    end
    
    def self.scroll_x_to(position)
      `$('html,body').animate({scrollLeft: #{position}}, 200, 'swing')`
    end
    
    def self.standard_width
      Element.find('div.column.half').inner_width
    end
    
    def self.standard_height
      Window.inner_height - Element.find('#header').outer_height
    end
    
    class Selector
      def initialize(params = {})
        @display = params[:body].find('>.display')
        @body = params[:body].find('>.body')
        default = params[:default]
        @params = params
        
        Element.find('body').append(@body)
        
        unless default.nil?
          li = @body.find("li[data-value='#{default}']")
          @display['data-value'] = default
          
          @display.text = li.text unless params[:update] == false
        end
        
        # イベントハンドラ
        @display.on('click') do
          open
        end
        
        @body.find('li').each do |li|
          li.on('click') do
            update(li)
            
            value = li['data-value']
            yield(value)
          end
        end
        
        @body.on('click') do
          close
        end
      end
      
      def update(li)
        unless @params[:update] == false
          @display.text = li.text
        end
        value = li['data-value']
        @display['data-value'] = value
      end
      
      def open
        @overlay = Element.new('div').
          add_class('selector').
          add_class('overlay').
          css('width', "#{Window.inner_width}px").
          css('height', "#{Window.inner_height}px")
        @overlay.on('click') do
          close
        end
        @body.before(@overlay)
        
        position = @display.offset[:left] + @display.outer_width + COMMON_MARGIN * 2
        @body.
          css('width', "#{Ojikoen::UI.standard_width}px").
          css('height', "#{Window.inner_height - COMMON_MARGIN*2}px").
          css('left', "#{position}px")
        
        @body.show
        position = @body.offset[:left] + @body.inner_width - Ojikoen::UI.standard_width * 2
        Ojikoen::UI.scroll_x_to(position)
        
        @body.find('.active').remove_class('active')
        value = @display['data-value']
        li = @body.find("li[data-value='#{value}']")
        unless li.size == 0
          position = li.offset[:top] + @body.scroll_top - COMMON_MARGIN
          @body.scroll_top = position
          li.add_class('active') unless @params[:update] == false
        end
        
        @display.add_class('active')
      end
      
      def close
        @overlay.remove
        @body.fade_out
        
        unless @params[:scroll_on_close] == false
          id = @display.parents('.column-element')['id']
          Ojikoen::UI::Column.move_to("##{id}")
        end

        @params[:body].remove_class('active')
      end
      
      def value
        return @display['data-value']
      end
    end
    
    # data-destination=移動先
    # data-url=リンク先
    class Menu
      def initialize(body)
        @body = body
        
        @body.find('li').each do |li|
          li.on('click') do
            open(li)
          end
          
          # メニュー中にリンクが貼られている場合、右向きにスクロールアウトした後遷移させる
          li.find('a').each do |link|
            link.on('click') do
              if link['href'] == "#"
                false
              else
                Ojikoen::UI::Column.scroll_forward
              end
            end
          end
          
          li.find('form').on('submit') do
            Ojikoen::UI::Column.scroll_forward
          end
        end
      end
      
      def open(element)
        element.parents('.main-column').find('li.active').remove_class('active')
        element.add_class('active')
        if element['data-destination'] == nil
          unless element['data-url'] == nil
            `location.href = #{element['data-url']}`
            Ojikoen::UI::Column.scroll_forward
          end
        else
          Column.move_to(element['data-destination'])
        end
      end
    end
    
    class Dialog
      attr_accessor :message
      
      def initialize(params)
        template = Element.find('#ojikoen-ui-dialog-template').template(params)
        @overlay = template.find('div.overlay')
        @body = template.find('div.ojikoen-ui-dialog')
        @message = @body.find('div.message')
        
        @body.find('button.ok').on('click') do
          yield(@body.find('input[type="text"]').value)
        end
        @body.find('button.ok,button.cancel').on('click') do
          close
        end
        
        if params['value'].nil?
          @body.find('div.input').remove
        end
        @input_default_value = params['value']
        
        if params['cancel'].nil?
          @body.find('button.cancel').remove
          @body.find('button.ok').css('width', '100%')
        end
        
        Element.find('body').append(template)
      end
      
      def open
        @overlay.fade_in
        @body.fade_in
        
        # サイズ調整
        height = Window.inner_height * 0.8 - 
          @body.find('div.title').outer_height -
          @body.find('div.buttons').outer_height
        input = @body.find('div.input')
        height -= input.outer_height unless input.size == 0
        
        @message.css('height', "#{height}px")
        
        input.find('input').value = @input_default_value
        input.find('input').focus
      end
      
      def close
        @overlay.fade_out
        @body.fade_out
      end
    end
  end
end

Document.ready? do
  Ojikoen::UI::Column.init
  id = Element.find('#content>div.column:first-child>.column-element:first-child')['id']
  Ojikoen::UI::Column.move_to("##{id}")
  
  Element.find('ul.menu').each do |menu|
    Ojikoen::UI::Menu.new(menu)
  end
end


if(typeof(Ojikoen) == 'undefined'){
  Ojikoen = {}
}

Ojikoen.UI = {
  initialize: function(){
    $('#dialog input[type="text"]').keydown(function(event){
      if(event.which === 13){
        $('#dialog button.ok').click();
      }
    });
  },
  
  openMenu: function(parent, menu){
    var top = parent.offset().top + parent.outerHeight();
    var left = parent.offset().left;
    
    var cover = $('<div>').
      addClass('overlay-cover').
      css({'display': 'none'});
    $(document.body).append(cover);
    cover.fadeIn(200);
    cover.click(function(){
      menu.fadeOut(200);
      cover.remove();
    });
    
    menu.css({'top': top + 'px', 'left': left + 'px'});
    menu.fadeIn(200);
    menu.find('li').click(function(){
      menu.fadeOut(200);
      cover.remove();
    });
  },
  
  openDialog: function(title, message, input, cancel, ok, callback){
    var dialog = $('#dialog');
    
    if(title == null){
      dialog.find('.title').hide();
    }else{
      dialog.find('.title').show();
      dialog.find('.title').html(title);
    }
    
    if(message == null){
      dialog.find('.message').hide();
    }else{
      dialog.find('.message').show();
      dialog.find('.message').html(message);
    }
    
    if(input == null){
      dialog.find('.input').hide();
    }else{
      dialog.find('.input').show();
      dialog.find('.input>input[type="text"]').val(input);
    }
    
    if(cancel == null){
      dialog.find('button.cancel').hide();
    }else{
      dialog.find('button.cancel').text(cancel);
      dialog.find('button.cancel').show();
    }
    
    dialog.find('button.ok').text(ok);
    
    var top = ($(window).innerHeight() - dialog.outerHeight())/2;
    dialog.css({'top': top + 'px'});
    
    var cover = $('<div>').
      addClass('overlay-cover').
      css({'display': 'none'});
    $(document.body).append(cover);
    cover.fadeIn(200);
    
    dialog.find('button').unbind();
    dialog.find('button').click(function(){
      cover.remove();
      dialog.fadeOut(200);
    });
    dialog.find('button.ok').click(function(){
      if(callback != null){
        callback($('#dialog>div.input>input').val());
      }
    });
    
    dialog.fadeIn(200, function(){
      if(input != null){
        dialog.find('input').focus();
      }
    });
  }
}

$(document).ready(function(){
  Ojikoen.UI.initialize();
});

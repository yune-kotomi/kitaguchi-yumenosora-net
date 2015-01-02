class Profile < ActiveRecord::Base
  has_many :openid_urls
  has_many :profile_services

  validates_presence_of :screen_name
  validates_presence_of :nickname

  before_save :generate_long_name

  def primary_openid
    return self.openid_urls.where(:primary_openid => true)[0]
  end

  def profile_html(options = {:section_anchor_prefix => "profile_#{self.id}"})
    src = self.profile_text.to_s

    #セクションアンカーをユニークにする
    unless options[:section_anchor_prefix].blank?
      src = uniq_sec_anchor(src, options[:section_anchor_prefix])
    end

    #記法展開
    sectionanchor = options[:sectionanchor] || '■'
    parser = Text::Hatena.new(:sectionanchor => sectionanchor)
    begin
      parser.parse(src)
      html = parser.html.force_encoding('UTF-8')

    rescue
      html = "記法の展開中にエラーが発生しました。"
    end

    html = tex_cgi_switch(html, options[:tex_cgi_uri]) unless options[:tex_cgi_uri] == nil
    return html.to_s
  end

  private
  def generate_long_name
    self.long_name = "#{domain_name}@#{screen_name}"
    return self.long_name
  end

  def validate_on_create
    unless read_attribute(:screen_name) =~ /^[a-zA-Z0-9_-]+$/
      errors.add(
        :screen_name,
        '半角英数字およびアンダースコア、ハイフンのみが使えます。'
      ) unless read_attribute(:screen_name).empty?
    end

    if Profile.where(:long_name => generate_long_name).count > 0
      errors.add(:screen_name, "この表示名は使用できません。")
    end
  end

  def uniq_sec_anchor(str, id)
    c=-1
    if str == nil
      return str
    else
      temp=str.gsub(/^\*(.*?)$/){
        title=$1
        if $1 =~ /\*/
          "*#{title}"
        else
          c += 1
          "*#{id}_#{c}*#{title}"
        end
      }
      return temp
    end
  end

  #Tex記法の参照先を変更する
  def tex_cgi_switch(src, new_uri)
    return src.gsub(
      '<img src="http://d.hatena.ne.jp/cgi-bin/mimetex.cgi',
      "<img src=\"#{new_uri}")
  end
end

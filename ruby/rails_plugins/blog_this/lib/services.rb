# blog_this plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


module BlogThis #:nodoc
  module Services #:nodoc

    # WordPress service.
    service :wordpress do
      label "WordPress"
      description "Enter your blog URL. We will the redirect you to your posting page, for example, if your blog is http://co.mments.com, we will redirect you to http://co.mments.com/wp-admin/post.php"

      parameter :blog_url, "Blog URL" do |url|
        uri = URI.parse(url.strip) rescue nil
        if uri and not uri.scheme
          uri = URI.parse("http://#{url.strip}") rescue nil
        end
        if uri and uri.host.blank?
          uri = URI.parse("#{uri.scheme}://#{uri.opaque}") rescue nil
        end
        unless uri and uri.scheme =~ /^http(s?)$/i and !uri.host.blank?
          raise ArgumentError, "Please enter a valid URL"
        end
        path = uri.path || "/"
        path += "/" unless path[-1] == ?/
        "#{uri.scheme.downcase}://#{uri.host.downcase}#{path}"
      end

      request do |title, content, url|
        { :url=>"#{self.blog_url}wp-admin/post.php?text=#{CGI.escape(content)}&popupurl=#{CGI.escape(url)}&popuptitle=#{CGI.escape(title)}",
          :title=>"WordPress", :options=>"scrollbars=no,top=175,left=75,status=yes,resizable=yes" }
      end
    end


    # Blogger/BlogSpot service.
    service :blogger do
      label "Blogger/BlogSpot"
      description "You're all set. When you click <strong>Blog this</strong>, Blogger will check your login and redirect you to your blog."

      request do |title, content, url|
        { :url=>"http://www.blogger.com/blog_this.pyra?t=#{CGI.escape(content)}&u=#{CGI.escape(url)}&n=#{CGI.escape(title)}",
          :title=>"Blogger", :options=>"scrollbars=no,top=175,left=75,width=475,height=300,status=yes,resizable=yes" }
      end
    end

  end
end


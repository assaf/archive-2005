# blog_this plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


module BlogThis #:nodoc
  module Services #:nodoc

    class WordPress < BlogThis::Service

      label_as "WordPress"


      def update(params)
        uri = URI.parse(params[:blog_url]) rescue nil
        if uri and not uri.scheme
          uri = URI.parse("http://#{params[:blog_url].strip}") rescue nil
        end
        if uri and uri.host.blank?
          uri = URI.parse("#{uri.scheme}://#{uri.opaque}") rescue nil
        end
        unless uri and uri.scheme =~ /^http(s?)$/i and !uri.host.blank?
          raise ArgumentError, "Please enter a valid URL"
        end
        path = uri.path || "/"
        unless path =~ /\/wp-admin\/post\.php$/i
          path << "/" unless path =~ /\/$/
          path << "wp-admin/" unless path =~ /wp-admin\/?$/i
          path << "/" unless path =~ /\/$/
          path << "post.php" unless path =~ /post\.php$/i
        end
        @blog_url = "#{uri.scheme.downcase}://#{uri.host.downcase}#{path}"
      end


      def request(title, content, url)
        { :url=>"#{@blog_url}?text=#{CGI.escape(content)}&popupurl=#{CGI.escape(url)}&popuptitle=#{CGI.escape(title)}",
          :title=>"WordPress", :options=>"scrollbars=no,top=175,left=75,width=600,height=400,status=yes,resizable=yes" }
      end

    end


    class Blogger < BlogThis::Service

      label_as "Blogger/BlogSpot"


      def request(title, content, url)
        { :url=>"http://www.blogger.com/blog_this.pyra?t=#{CGI.escape(content)}&u=#{CGI.escape(url)}&n=#{CGI.escape(title)}",
          :title=>"Blogger", :options=>"scrollbars=no,top=175,left=75,width=600,height=400,status=yes,resizable=yes" }
      end

    end

  end
end


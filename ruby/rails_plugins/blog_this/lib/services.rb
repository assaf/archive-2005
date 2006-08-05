# blog_this plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


module BlogThis #:nodoc
  module Services #:nodoc

    # WordPress service.
    service :wordpress do
      title "WordPress"
      parameter :blog_url, "Your blog URL",
                "Enter the URL of your blog, e.g. http://blog.co.mments.com"
      render do |page, inputs|
        page << <<-EOF
(function() {
  var content = "#{inputs[:content]}";
  var url = "#{inputs[:url]}";
  var title = "#{inputs[:title]}";
  var popup = window.open('#{inputs[:blog_url]}/wp-admin/post.php?text=' + escape(content) + '&popupurl=' + escape(url) + '&popuptitle=' + escape(title),
       'WordPress','scrollbars=no,top=175,left=75,status=yes,resizable=yes');
  if (!document.all) T = setTimeout('popup.focus()',50);
EOF
      end
=begin
        page << <<-EOF
(function() {
  var form = Object.extend(document.createElement("form"), {
    action: "#{"%s/wp-admin/post.php" % "#{inputs[:blog_url]}"}",
    method: "post",
    target: "_blank"
  });
  form.style.display = "none";
  var inputs = [
    Object.extend(document.createElement("input"), {
      type: "hidden",
      name: "post_title",
      value: "#{inputs[:title]}"
    }),
    Object.extend(document.createElement("input"), {
      type: "hidden",
      name: "content",
      value: "#{inputs[:content]}"
    })
  ];
  for (var i = 0, input; input = inputs[i]; ++i)
    form.appendChild(input);
  document.body.appendChild(form);
  form.submit();
})();
EOF
      end
=end
    end


    # Blogger/BlogSpot service.
    service :blogger do
      title "Blogger/BlogSpot"
      render do |page, inputs|
        page << <<-EOF
(function() {
  var content = "#{inputs[:content]}";
  var url = "#{inputs[:url]}";
  var title = "#{inputs[:title]}";
  var popup = window.open('http://www.blogger.com/blog_this.pyra?t=' + escape(content) + '&u=' + escape(url) + '&n=' + escape(title),
    'bloggerForm','scrollbars=no,width=475,height=300,top=175,left=75,status=yes,resizable=yes');
  if (!document.all) T = setTimeout('popup.focus()',50);
})();
EOF
      end
    end

  end
end


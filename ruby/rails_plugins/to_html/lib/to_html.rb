module ToHtml

    HTML_TYPE_NAMES = {
        "Fixnum"     => "integer",
        "Date"       => "date",
        "Time"       => "datetime",
        "TrueClass"  => "boolean",
        "FalseClass" => "boolean",
        "URI"        => "url"
    }
  
       
    HTML_FORMATTING = { 
        "date"     => lambda { |date| %Q{<abbr title="#{date.xmlschema}">#{date.to_s}</abbr>} },
        "datetime" => lambda { |time| %Q{<abbr title="#{time.xmlschema}">#{time.to_s}</abbr>} },
        "url"      => lambda { |url| %Q{<a href="#{url}">#{url}</a>} }
    }

    
    def self.envelope(options)
        builder = options[:builder] or raise ArgumentError
        options = options.merge(:in_body=>true)
        return builder.html do
            builder.head do
                builder.title options[:name].to_s.titleize if options[:name]
                yield Where.new(:html_head), options
            end
            builder.body do
                yield Where.new(:header), options
                yield Where.new(:main), options
                yield Where.new(:footer), options
            end
        end
    end


    class Where

        SYMBOLS = [:html_head, :header, :main, :footer]

        def initialize(where)
            @where = where
        end

        SYMBOLS.each do |symbol|
            class_eval %Q{
                def #{symbol}()
                    yield if @where == :#{symbol} and block_given?
                end
            }
            class_eval %Q{
                def #{symbol}?()
                    @where == :#{symbol}
                end
            }
        end

        def path(select)
            path = Regexp.new("(^|\\b)#{select.to_s}$") unless path.is_a?(Regexp)
            yield if @where =~ path and block_given?
        end

        def path?(path)
            path = Regexp.new("(^|\\b)#{select.to_s}$") unless path.is_a?(Regexp)
            @where =~ path
        end

    end


    class ::Object

        def to_html(options = {}, &block)
            builder = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
            name = (options[:name] || self.class).to_s

            unless options[:in_body]
                return ToHtml::envelope(options) do |where, options|
                    where.main { to_html(options, &block) }
                    block.call where, builder, nil if block
                end
            end
            type_name = HTML_TYPE_NAMES[self.class.to_s]
            attributes = {}
            attributes[:class] = type_name if type_name
            if name.to_s =~ /(^|_)url$/
                builder.p attribute do
                    builder << HTML_FORMATTING["url"].call(self)
                    block.call Where.new(name), builder, self if block
                end
            elsif HTML_FORMATTING[type_name]
                builder.p attributes do
                    builder << HTML_FORMATTING[type_name].call(self)
                    block.call Where.new(name), builder, self if block
                end
            else
                builder.p attributes do
                    builder.text! self.to_s
                    block.call Where.new(name), builder, self if block
                end
            end
        end

    end


    class ::Hash

        def to_html(options = {}, &block)
            level = options[:level] ||= 1
            options[:indent] ||= 2
            builder = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
            options[:name] ||= "record"
            path = (options[:path] || options[:name]).to_s

            unless options[:in_body]
                return ToHtml::envelope(options) do |where, options|
                    where.main do
                        builder.div do
                            to_html(options, &block)
                            block.call Where.new(path), builder, self if block
                        end
                    end
                    block.call where, builder, nil if block
                end
            end
            builder.tag! "h#{level}", options[:name].titleize

            each do |name, value|
                case value
                when nil # Nothing
                when Array:
                    value.to_html options.merge(:name=>name, :level=>level + 1, :path=>"#{path} #{name}"), &block
                when Hash:
                    attributes = {}
                    attributes[:id] = value[:id] if value[:id]
                    builder.div(attributes) do
                        value.to_html options.merge(:name=>name, :level=>level + 1, :path=>"#{path} #{name}"), &block
                    end
                else
                    builder.dt "#{name.to_s.titleize}:"
                    class_name = name.to_s.dasherize
                    if name.to_s =~ /(^|_)url$/
                        builder.dd(:class=>class_name) do
                            builder << HTML_FORMATTING["url"].call(value)
                            block.call Where.new("#{path} #{name}"), builder, value if block
                        end
                    else
                        type_name = HTML_TYPE_NAMES[value.class.to_s]
                        class_name << " #{type_name}" if type_name && class_name != type_name && type_name != "url"
                        if HTML_FORMATTING[type_name]
                            builder.dd(:class=>class_name) do
                                builder << HTML_FORMATTING[type_name].call(value)
                                block.call Where.new("#{path} #{name}"), builder, value if block
                            end
                        else
                            builder.dd :class=>class_name do
                                builder.text! value.to_s
                                block.call Where.new("#{path} #{name}"), builder, value if block
                            end
                        end
                    end
                end
            end
        end

    end


    class ::Array

        def to_html(options = {}, &block)
            level = options[:level] ||= 1
            builder = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
            name = (options[:name] || "records").to_s
            path = (options[:path] || name).to_s

            unless options[:in_body]
                return ToHtml::envelope(options) do |where, options|
                    where.main do
                        builder.div do
                            to_html(options, &block)
                            block.call Where.new(path), builder, self if block
                        end
                    end
                    block.call where, builder, nil if block
                end
            end
            builder.ol :class=>name.dasherize do
                each do |value|
                    name = name.singularize
                    case value
                    when nil # Nothing
                    when Array:
                        builder.li(:class=>name.dasherize) do
                            value.to_html options.merge(:name=>name, :level=>level, :path=>path), &block
                        end
                    when Hash:
                        attributes = {:class=>name.dasherize}
                        attributes[:id] = value[:id] if value[:id]
                        builder.li(attributes) do
                            value.to_html options.merge(:name=>name, :level=>level, :path=>path), &block
                        end
                    else
                        class_name = name.dasherize
                        if name.to_s =~ /(^|_)url$/
                            builder.li(:class=>class_name) do
                                builder << HTML_FORMATTING["url"].call(value)
                                block.call Where.new(path), builder, value if block
                            end
                        else
                            type_name = HTML_TYPE_NAMES[value.class.to_s]
                            class_name << " #{type_name}" if type_name && class_name != type_name
                            if HTML_FORMATTING[type_name]
                                builder.li(:class=>class_name) do
                                    builder << HTML_FORMATTING[type_name].call(value)
                                    block.call Where.new(path), builder, value if block
                                end
                            else
                                builder.li :class=>class_name do
                                    builder.text! value.to_s
                                    block.call Where.new(path), builder, value if block
                                end
                            end
                        end
                    end
                end
            end
        end

    end

end


module ::ActiveSupport::JSON::Encoders #:nodoc:
    define_encoder Time do |object|
        object.to_s.to_json
    end
end


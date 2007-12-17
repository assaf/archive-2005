module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Conversions

        def to_xml(options = {})
          options[:root]     ||= all? { |e| e.is_a?(first.class) && first.class.to_s != "Hash" } ? first.class.to_s.underscore.pluralize : "records"
          options[:children] ||= options[:root].singularize
          options[:indent]   ||= 2

          root     = options.delete(:root).to_s
          children = options.delete(:children)

          if !options.has_key?(:dasherize) || options[:dasherize]
            root = root.dasherize
            children = children.dasherize
          end

          options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
          options[:builder].instruct! unless options.delete(:skip_instruct)

          opts = options.merge({ :root => children })

          xml = options[:builder]
          if empty?
            xml.tag!(root, options[:skip_types] ? {} : {:type => "array"})
          else
            xml.tag!(root, options[:skip_types] ? {} : {:type => "array"}) do
               yield xml if block_given?

              each do |value|
                case value
                  when ::Hash
                    value.to_xml(opts.merge!({:skip_instruct => true }))
                  when ::Method, ::Proc
                    value.call(opts.merge!({ :skip_instruct => true }))
                  else
                    if value.respond_to?(:to_xml)
                      value.to_xml(opts.merge!({ :skip_instruct => true }))
                    else
                      type_name = Hash::Conversions::XML_TYPE_NAMES[value.class.name]

                      attributes = opts[:skip_types] || value.nil? || type_name.nil? ? { } : { :type => type_name }
                      if value.nil?
                        attributes[:nil] = true
                      end

                      options[:builder].tag!(children,
                        Hash::Conversions::XML_FORMATTING[type_name] ? Hash::Conversions::XML_FORMATTING[type_name].call(value).to_s : value.to_s,
                        attributes
                      )
                  end
                end
              end
            end
          end
        end

      end
    end
  end
end

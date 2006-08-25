# blog_this plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


module BlogThis


  def self.create(config)
    if String === config
      config = {:service=>config}
    end
    symbol = config.delete(:service)
    if symbol and service = services[symbol.to_sym]
      service.new(config)
    end
  end


  def self.services()
    unless @services
      @services = {}
      BlogThis::Services.constants.each do |const|
        klass = BlogThis::Services.const_get(const)
        if Class === klass
          @services[klass.to_sym] = klass
        end
      end
    end
    @services
  end


  def self.list()
    hash = services.clone
    hash.each { |k,v| hash[k] = v.label }
  end


  class Service

    class << self

      def to_sym()
        @symbol ||= name.split("::").last.downcase.to_sym
      end

      def label()
        @label ||= name.split("::").last.capitalize
      end

      def label_as(label)
        @label = label.to_s
      end

    end


    def initialize(config)
      config.each { |k, v| instance_variable_set("@#{k}", v) }
    end


    def to_hash()
      hash = {}
      instance_variables.each do |name|
        value = instance_variable_get(name)
        hash[name[1..-1].to_sym] = value if value
      end
      hash[:service] = to_sym
      hash
    end

    
    def label()
      self.class.label
    end


    def to_sym()
      self.class.to_sym
    end


    def update(params)
    end

    
    def render_options()
      template = File.expand_path(File.join(File.dirname(__FILE__), "/#{self.to_sym}.rhtml"))
      template = File.join("../..", template.sub(File.expand_path(RAILS_ROOT), ""))
      locals = instance_variables.inject({}) do |hash, name|
        hash[name[1..-1].to_sym] = instance_variable_get(name)
        hash
      end
      {:file=>template, :locals=>locals}
    end

  end


end

module SerializeWithOptions

  def serialize_with_options(set = :default, &block)
    configuration = read_inheritable_attribute(:configuration) || {}
    options       = read_inheritable_attribute(:options) || {}

    configuration[set] = Config.new(configuration).instance_eval(&block)

    write_inheritable_attribute :configuration, configuration
    write_inheritable_attribute :options, options

    include InstanceMethods
  end

  def serialization_configuration(set)
    configuration = read_inheritable_attribute(:configuration)
    conf = if configuration
      configuration[set] || configuration[:default]
    end

    conf.try(:dup) || { :methods => nil, :only => nil, :except => nil }
  end

  def serialization_options(set)
    options = read_inheritable_attribute(:options)
    options[set] ||= returning serialization_configuration(set) do |opts|
      includes = opts.delete(:includes)

      if includes
        opts[:include] = includes.inject({}) do |hash, class_name|
          if class_name.is_a? Hash
            hash.merge(class_name)
          else
            begin
              klass = class_name.to_s.classify.constantize
              hash[class_name] = klass.serialization_options(set)
              hash
            rescue NameError
              hash.merge(class_name => { :include => nil })
            end
          end
        end
      end
    end
    write_inheritable_attribute :options, options
    options[set]
  end

  class Config
    undef_method :methods
    Instructions = [:skip_instruct, :dasherize, :skip_types, :root_in_json].freeze

    def initialize(conf)
      @conf = conf
      @data = { :methods => nil, :only => nil, :except => nil }
    end

    def method_missing(method, *args)
      @data[method] = Instructions.include?(method) ? args.first : args
      @data
    end

    def inherit(set)
      raise "Not known configuration!" unless @conf[set]
      @data = @conf[set].dup
    end
    
  end

  module InstanceMethods
    def to_xml(opts = {})
      set, opts = parse_serialization_options(opts)
      super(self.class.serialization_options(set).deep_merge(opts))
    end

    def as_json(opts = {})
      set, opts = parse_serialization_options(opts)
      super(self.class.serialization_options(set).deep_merge(opts))
    end

    private

    def parse_serialization_options(opts)
      if set = opts[:flavor]
        opts = {}
      else
        set  = :default
      end

      [set, opts]
    end
  end
end

require_relative "typed_hash"

module Jim
  class SpecError < StandardError; end

  class UnsafeSpec
    @@accessors = [:metadata]

    def self.string_accessor(name)
      @@accessors << name
      attr_reader(name)
      define_method("#{name}=") { |value|
        raise SpecError, "expected #{name} to be a String, got #{value.class}: #{value.inspect}" unless value.is_a?(String)
        instance_variable_set(:"@#{name}", value)
      }
    end

    def self.array_accessor(name)
      @@accessors << name
      attr_reader(name)
      define_method("#{name}=") { |value|
        unless value.is_a?(Array) && value.all? { |x| x.is_a?(String) }
          raise SpecError, "expected #{name} to be an Array of Strings, got #{value.class}: #{value.inspect}"
        end
        instance_variable_set(:"@#{name}", value)
      }
    end

    def self.string_or_array_accessor(name)
      @@accessors << name
      attr_reader(name)
      define_method("#{name}=") { |value|
        value = [value] if value.is_a?(String)
        unless value.is_a?(Array) && value.all? { |x| x.is_a?(String) }
          raise SpecError, "expected #{name} to be an Array of Strings, got #{value.class}: #{value.inspect}"
        end
        instance_variable_set(:"@#{name}", value)
      }
    end

    array_accessor :authors
    array_accessor :files
    string_accessor :name
    string_accessor :summary
    string_accessor :description
    string_accessor :homepage
    string_or_array_accessor :email
    array_accessor :licenses
    string_accessor :bindir
    array_accessor :executables
    array_accessor :require_paths
    string_accessor :required_ruby_version
    string_accessor :version

    def initialize(&block)
      @metadata = TypedHash.new(String, String, {})

      yield self
      @@extract_spec_fn.call(self)
    end

    def metadata
      @metadata
    end

    def metadata=(value)
      @metadata = TypedHash.new(String, String, value)
    end

    def author=(author)
      self.authors=([author])
    end

    def license=(license)
      self.licenses=([license])
    end

    def to_h
      @@accessors.map { |k, v| [k, instance_variable_get(:"@#{k}")] }.to_h
    end

    def inspect
      accessors = to_h.map { |k, v| [k, v.inspect].join('=') }
      "<Jim::UnsafeSpec #{accessors.join(' ')}>"
    end
  end
end

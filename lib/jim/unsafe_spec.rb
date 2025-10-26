require_relative "typed_array"
require_relative "typed_hash"

module Jim
  class SpecError < StandardError; end
  class UnsafeSpec
    ArrayOfStrings = Jim::TypedArray(String)
    HashOfStringToString = Jim::TypedHash(String, String)
    HashOfStringToAOS = Jim::TypedHash(String, ArrayOfStrings)

    @@accessors = [:metadata, :specification_version]

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

    def self.array_of_strings_accessor(name)
      @@accessors << name
      attr_reader(name)
      define_method("#{name}=") { |value|
        instance_variable_set(:"@#{name}", ArrayOfStrings.from(value))
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
    array_of_strings_accessor :extra_rdoc_files
    array_of_strings_accessor :rdoc_options

    def initialize(&block)
      @specification_version = 4
      @metadata = HashOfStringToString.new
      @runtime_dependencies = HashOfStringToAOS.new
      @dev_dependencies = HashOfStringToAOS.new

      yield self
      self.class.class_variable_get(:@@extract_spec_fn).call(self)
    end

    def metadata
      @metadata
    end

    def metadata=(value)
      @metadata = HashOfStringToString.from(value)
    end

    def author=(author)
      self.authors=([author])
    end

    def license=(license)
      self.licenses=([license])
    end

    def add_dependency(gem_name, *requirements)
      @runtime_dependencies[gem_name] = ArrayOfStrings.from(requirements)
    end
    alias_method :add_runtime_dependency, :add_dependency

    def add_development_dependency(gem_name, *requirements)
      @dev_dependencies[gem_name] = ArrayOfStrings.from(requirements)
    end

    def to_h
      @@accessors.map { |k, v|
        value = instance_variable_get(:"@#{k}")
        value = value.to_h if value.is_a?(Hash)

        if [:required_ruby_version, :required_rubygems_version].include?(k) && value.is_a?(String)
          operator, version = value.strip.split(' ', 2).map(&:strip)
          value = {
            'requirements' => [
              [operator, {'version' => version}]
            ]
          }
        end

        if k == :version
          value = {'version' => value}
        end

        [k.to_s, value]
      }.to_h
    end

    def inspect
      accessors = to_h.map { |k, v| [k, v.inspect].join('=') }
      "<Jim::UnsafeSpec #{accessors.join(' ')}>"
    end
  end
end

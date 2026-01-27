module Jwl
  ##
  # A Hash that raises exceptions unless keys and values are of the
  # specified types.
  #
  # Usage:
  #
  # ```ruby
  # h = TypeHash.new(String, String)
  # h["a"] = "foo"
  # #=> "foo"
  # h["b"] = 1
  # #=> Jwl::TypedHashError: expected val to be String, got Integer: 1
  # ```
  class TypedHash < Hash
    class TypedHashError < TypeError; end

    class << self
      attr_accessor :key_class
      attr_accessor :value_class

      def from(val)
        raise TypedHashError, "expected Hash, got #{val.class}" unless val.is_a?(Hash)
        new().merge(val)
      end
    end

    def merge(*others)
      self.clone.merge!(*others)
    end

    def merge!(*others)
      others.map do |other|
        other.map { |k, v| self[k] = v }
      end
      self
    end

    def []=(key, val)
      unless key.is_a?(self.class.key_class)
        raise TypedHashError, "expected key to be #{self.class.key_class}, got #{key.class}: #{key.inspect}"
      end

      if val.is_a?(Array) && self.class.value_class.respond_to?(:from)
        val = self.class.value_class.from(val) # steep:ignore NoMethod
      end

      unless val.is_a?(self.class.value_class)
        raise TypedHashError, "expected val to be #{self.class.value_class}, got #{val.class}: #{val.inspect}"
      end

      super(key, val)
    end

    def to_h
      super.map { |k, v|
        case v
        when Array
          [k, v.to_a]
        when Hash
          [k, v.to_h]
        else
          [k, v]
        end
      }.to_h
    end
  end

  def self.TypedHash(key_class, value_class)
    cls = Class.new(TypedHash)
    cls.set_temporary_name("hashOf#{key_class.name}To#{value_class.name}")
    cls.instance_variable_set(:@key_class, key_class)
    cls.instance_variable_set(:@value_class, value_class)
    cls
  end
end

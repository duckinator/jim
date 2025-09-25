module Jim
  class TypedHashError < StandardError; end

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
  # #=> Jim::TypedHashError: expected val to be String, got Integer: 1
  # ```
  class TypedHash < Hash
    def initialize(key_cls, val_cls, init=nil)
      @key_cls = key_cls
      @val_cls = val_cls

      init.map { |k, v| self[k] = v } unless init.nil?
    end

    def []=(key, val)
      unless key.is_a?(@key_cls)
        raise TypedHashError, "expected key to be #{@key_cls}, got #{key.class}: #{key.inspect}"
      end

      unless val.is_a?(@val_cls)
        raise TypedHashError, "expected val to be #{@val_cls}, got #{val.class}: #{val.inspect}"
      end

      super(key, val)
    end
  end
end

module Jim
  ##
  # An Array that raises exceptions unless values are of the
  # specified types.
  #
  # Usage:
  #
  # ```ruby
  # ArrayOfString = TypeArray(String)
  # a = ArrayOfString.new
  # a[0] = "foo"
  # #=> "foo"
  # a[1] = 1
  # #=> Jim::TypeError: expected val to be String, got Integer: 1
  # ```
  class TypedArray < Array
    class TypedArrayError < TypeError
      def initialize(val_cls, val)
        super("expected val to be #{val_cls.name}, got #{val.class}: #{val.inspect}")
      end
    end

    class << self
      attr_reader :value_class

      def from(val)
        raise TypedArrayError.new(Array, val) unless val.is_a?(Array)
        new(val)
      end
    end

    def check(val)
      raise TypedArrayError.new(self.class.value_class, val) unless val.is_a?(self.class.value_class)
      val
    end

    def initialize(ary)
      super()
      ary.each { |v| self.push(v) }
    end
    def []=(key, val);  super(key, check(val)); end
    def push(val);      super(check(val));      end
    def unshift(val);   super(check(val));      end
  end

  def self.TypedArray(value_class)
    cls = Class.new(TypedArray)
    cls.set_temporary_name("arrayOf#{value_class.name}")
    cls.instance_variable_set(:@value_class, value_class)
    cls
  end
end

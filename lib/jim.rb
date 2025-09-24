# frozen_string_literal: true

require_relative "jim/version"
require "prism"

module Jim
  class Error < StandardError; end
  class SpecError < Error; end

  attr_reader :specs

  def self.add_spec(spec)
    @specs ||= []
    @specs << spec
  end

  class TypedHash < Hash
    class TypedHashError < Jim::Error; end

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

  class UnsafeSpec
    attr_accessor :_extract_spec_fn

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

  module GemCompat
    Specification = UnsafeSpec
  end

  def self.load_spec(gemspec)
    spec = nil
    extract_spec = ->(new_spec) { spec = new_spec }
    Module.new { |mod|
      mod.const_set(:Gem, Module.new {|gem_mod|
        spec_cls = UnsafeSpec.clone
        spec_cls.class_variable_set(:@@extract_spec_fn, extract_spec)
        gem_mod.const_set(:Specification, spec_cls)
      })
      load(gemspec, wrap=self)
    }
    spec
  end

  def self.cli
    gemspec, *rest = Dir.glob("*.gemspec")
    abort "Found multiple gemspecs: #{gemspec}, #{rest.join(',')}" unless rest.empty?

    p load_spec(gemspec)
  end
end

# frozen_string_literal: true

require_relative "jwl/version"
require_relative "jwl/unsafe_spec"
require_relative "jwl/platform"
require "prism"

module Jwl
  class Error < StandardError; end

  # Given a path to a gemspec, which contains arbitrary code of dubious provenance,
  # run the code in a way that can returns the Jwl::UnsafeSpec instance
  # created by the Gem::Specification.new {...} call.
  #
  # That is to say, if you have jwl.gemspec containing:
  #     Gem::Specification.new do |spec|
  #       spec.name = "foo"
  #     end
  #
  # You get a Jwl::UnsafeSpec returned, even though you have to use `load`,
  # and `load` always returns a boolean.
  #
  # This is truly cursed. I hate everything about this.
  # It's also the least-cursed option I could think of.
  def self.load_spec(gemspec)
    # Make sure the variable is in the outer scope.
    spec = nil
    # Create a lambda that can assign that variable.
    extract_spec = ->(new_spec) { spec = new_spec }
    # Create a wrapper module to attempt to isolate the calamity.
    Module.new { |mod|
      # Create a wrapper module named `Gem` for compatibility.
      mod.const_set(:Gem, Module.new {|gem_mod|
        # Clone the UnsafeSpec class.
        spec_cls = Class.new(UnsafeSpec)
        # For *that clone specifically*, set @@extract_spec_fn to the lambda.
        spec_cls.class_variable_set(:@@extract_spec_fn, extract_spec)
        # Inside our fake `Gem` module, shove our fake `Specification` class.
        gem_mod.const_set(:Specification, spec_cls)

        gem_mod.define_singleton_method(:win_platform?, &Jwl::Platform.method(:windows?))

        # Add `Gem::Platform::RUBY`, and raise an exception for all other platforms.
        gem_mod.const_set(:Platform, Class.new { |c|
          c.const_set(:UnsupportedPlatformError, Class.new(StandardError))
          c.const_set(:RUBY, "ruby")
          c.define_method(:const_missing) { |name|
            c.const_get(:UnsupportedPlatformError).new("Unsupported platform: #{name}")
          }
        })
      })
      # Summon an eldritch being, hoping that `wrap=self` contains some of
      # the impending disaster.
      load(gemspec, wrap=self)
    }
    spec
  end

  def self.source_date_epoch
    # The default value for SOURCE_DATE_EPOCH if not specified.
    # We want a date after 1980-01-01, to prevent issues with Zip files.
    # This particular timestamp is for 1980-01-02 00:00:00 GMT.
    Time.at(ENV['SOURCE_DATE_EPOCH']&.to_i || 315_619_200).utc.freeze
  end

  def self.cli
    require_relative "jwl/cli"
    Cli.run
  end
end

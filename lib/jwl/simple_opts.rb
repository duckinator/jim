# frozen_string_literal: true

# This file was based off okay/simple_opts.

require "optparse"

module Jwl
  ##
  # An OptionParser wrapper providing a few convenience functions.
  class SimpleOpts < OptionParser
    class SimpleOptsError < StandardError; end
    class UnexpectedArgument < SimpleOptsError; end

    def initialize(banner: nil, defaults: nil)
      super()
      @okay_options = defaults || {}

      self.banner = banner unless banner.nil?

      separator "\nOptions:"
    end

    # simple(..., :a)
    # simple(..., :b)
    #   ==
    # options = {}
    # on(...) { |val| options[:a] = val }
    # on(...) { |val| options[:b] = val }
    def simple(*args)
      key = args.pop
      on(*args) { |*x| @okay_options[key] = x[0] }
    end

    def parse(args)
      parse!(args.dup)
      @okay_options
    end

    def parse_and_consume_all!(args)
      args = args.dup
      parse!(args)
      raise UnexpectedArgument, args[0] unless args.empty?
      @okay_options
    end

    def parse_with_args(args)
      args = args.dup
      parse!(args)
      [@okay_options, args]
    end
  end
end


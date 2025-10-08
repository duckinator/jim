require_relative "client"
require_relative "config"
require_relative "console"
require_relative "simple_opts"

module Jim
  module Cli
    extend Jim::Console

    METHODS = %w[gemspec signin signout help]

    def self.run
      if METHODS.include?(ARGV[0])
        send(*ARGV)
      else
        help
      end
    end

    def self.config(command, setting, value=nil)
      config = Jim::Config.load_or_create

      Jim::Config.set(setting, value) unless value.nil?

      Jim::Config.get(setting)
    end

    # Sign in to the specified gem server.
    def self.signin(*args)
      require "io/console"

      opts = SimpleOpts.new(
        defaults: { host: "https://rubygems.org" },
        banner: "Usage: jim signin [--host HOST] [--otp CODE]",
      )

      opts.simple("--host HOST",
                  "Address of gem host to push to.",
                  :host)

      opts.simple("--user USERNAME",
                  "Username to sign in as.",
                  :user)

      opts.simple("--otp CODE",
                  "Multifactor authentication code.",
                  :otp)

      options = opts.parse_and_consume_all!(args)

      gem_host = prompt("Host", options[:host])

      username = prompt("Username", options[:user])
      password = prompt("Password", noecho: true)
      puts

      otp = prompt("OTP", options[:otp])

      config = Jim::Client.new(gem_host).sign_in(username, password, otp)
      name = config["name"]
      scopes = config["scopes"]

      puts "Saved key with name \"#{name}\" and scopes:"
      puts "- " + scopes.filter {|k, v| v}.keys.map(&:to_s).join("\n- ")
    end

    # Sign out from configured gem host
    def self.signout
      Jim::Config.delete_api_key
    end

    # Print information about the gemspec in the current directory.
    def self.gemspec(spec=nil)
      if spec.nil?
        spec, *rest = Dir.glob("*.gemspec")
        abort "Found multiple gemspecs: #{spec}, #{rest.join(',')}" unless rest.empty?
      end

      require 'pp'
      pp Jim.load_spec(spec).to_h
    end

    # Print this help text.
    def self.help
      puts <<~EOF
        Usage: jim [OPTIONS] [COMMAND] [ARGS...]

        Commands
          #{subcommand_summaries("jim", METHODS).join("\n  ")}
      EOF
    end

    def self.help_text(prefix, method_name, summary: false)
      file, line = method(method_name).source_location
      comment_line = line - 1

      comment = Prism.parse_file_comments(file).filter { |c|
        c.location.start_line == comment_line
      }.first&.slice

      comment = comment&.lines&.first&.strip if summary

      ["#{prefix} #{method_name}", comment]
    end

    def self.subcommand_summaries(prefix, methods)
      require 'prism'

      comments = methods.map { |m| help_text(prefix, m, summary: true) }.to_h

      # Take the longest name, and add 4 for spacing.
      width = comments.keys.sort_by(&:length).last.length + 4

      comments.map {|name, comment| "#{name.ljust(width)} #{comment}" }
    end
  end
end

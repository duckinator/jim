require "fileutils"
require "pathname"
require_relative "build"
require_relative "client"
require_relative "config"
require_relative "console"
require_relative "github_api"
require_relative "packer"
require_relative "simple_opts"

module Jim
  module Cli
    extend Jim::Console

    METHODS = %w[signin signout build clean pack release help]

    def self.run
      ARGV[0] = "help" if %w[--help -h].include?(ARGV[0])

      if METHODS.include?(ARGV[0])
        send(*ARGV)
      else
        help
        exit 1
      end
    end

    # Pack a gem into a single file.
    def self.pack(*args)
      opts = SimpleOpts.new(
        banner: "Usage: jim pack [--quiet]",
      )

      opts.simple("--quiet",
                  "Don't print anything on success",
                  :quiet)

      options, args = opts.parse_with_args(args)

      return puts opts if options[:help] || !args.empty?

      spec = load_spec_or_abort!

      unless spec.executables.length == 1
        abort "error: expected only one executable specified in #{spec_file}, found:\n- #{spec.executables.join("\n- ")}"
      end

      contents = Packer.pack(spec)
      filename = File.join("build", "pack", "#{spec.name}.rb")

      FileUtils.mkdir_p("build/pack")
      File.write(filename, contents)

      puts filename unless options[:quiet]

      filename
    end

#    def self.config(command, setting, value=nil)
#      config = Jim::Config.load_or_create
#
#      Jim::Config.set(setting, value) unless value.nil?
#
#      Jim::Config.get(setting)
#    end

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

      opts.simple("-h", "--help",
                  "Show this help message and exit",
                  :help)

      options = opts.parse_and_consume_all!(args)

      return puts opts if options[:help]

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

    # Builds a Gem from the provided gemspec.
    def self.build(*args)
      opts = SimpleOpts.new(
        banner: "Usage: jim build [--quiet] [-C PATH] GEMSPEC",
        defaults: { path: "." },
      )

      opts.simple("--quiet",
                  "Don't print anything on success",
                  :quiet)

      opts.simple("-C PATH",
                  "Change the current working directory to PATH before building",
                  :path)

      opts.simple("-h", "--help",
                  "Show this help message and exit",
                  :help)

      options, args = opts.parse_with_args(args)

      return puts opts if options[:help] || args.length > 1

      spec = load_spec_or_abort!(args.shift)

      out_file = Dir.chdir(options[:path]) { Jim::Build.build(spec) }

      unless options[:quiet]
        puts "Name:    #{spec.name}"
        puts "Version: #{spec.version}"
        puts
        puts "Output:  #{out_file}"
      end

      out_file
    end

    # Clean up build/pack artifacts.
    def self.clean
      FileUtils.rm_r(Jim::Build::BUILD_DIR) if File.exist?(Jim::Build::BUILD_DIR)
    end

    # Build and release a gem.
    def self.release
      spec = load_spec_or_abort!

      packed_file = self.pack("--quiet")
      gem_file = self.build("--quiet")

      github_repo = spec.metadata["jim/github_repo"]
      gem_host = spec.metadata["jim/gem_host"]

      unless github_repo
        warn 'No GitHub repo specified. Set spec.metadata["jim/github_repo"] in your gemspec to release to GitHub.'
      end

      unless gem_host
        warn 'No gem host specified. Set spec.metadata["jim/gem_host"] in your gemspec to release to a gem host.'
      end

      gh_release =
        if github_repo
          token = ENV["JIM_GITHUB_TOKEN"]
          abort "error: Expected JIM_GITHUB_TOKEN to be defined" if token.nil? || token.empty?

          owner, repo = github_repo.split("/")
          if repo.nil?
            abort "error: Expected spec.metadata[\"github_repo\"] to be of the format \"owner/repo\", got #{github_repo.inspect}"
          end

          assets = [packed_file, gem_file].map { |f| [f, Pathname(f).basename] }.to_h

          gh = Jim::GithubApi.new(owner, repo, spec.name, token.strip)
          gh.create_release(spec.version, assets: assets)
        end

      puts "FIXME: Actually publish #{gem_file} to #{gem_host}" if gem_host

      if options[:github]
        puts "Publishing GitHub release."
        gh_release.publish!
      end
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
        Usage: jim [COMMAND] [OPTIONS] [ARGS...]

        Commands
          #{subcommand_summaries("jim", METHODS).join("\n  ")}
      EOF
    end

    def self.help_text(prefix, method_name, summary: false)
      require 'prism'

      method_obj = method(method_name)

      file, line = method_obj.source_location
      raise RuntimeError, "method(#{method_name}).source_location should never be nil" if file.nil? || line.nil?

      comment_line = line - 1

      # Slight kludge for packed script, since I don't want to monkeypatch Prism.
      comments =
        if $JIM_DATA
          Prism.parse_comments($JIM_DATA["files"][file])
        else
          Prism.parse_file_comments(file)
        end

      comment = comments.filter { |c|
        c.location.start_line == comment_line
      }.first&.slice

      comment = comment&.lines&.first&.strip if summary

      ["#{prefix} #{method_name}", comment]
    end

    def self.subcommand_summaries(prefix, methods)
      comments = methods.map { |m| help_text(prefix, m, summary: true) }.to_h

      # Take the longest name, and add 4 for spacing.
      width = comments.keys.sort_by(&:length).last.length + 4

      comments.map {|name, comment| "#{name.ljust(width)} #{comment}" }
    end

    def self.load_spec_or_abort!(spec=nil)
      if spec.nil?
        spec, *rest = Dir.glob("*.gemspec")
        abort "Found multiple gemspecs: #{spec}, #{rest.join(',')}" unless rest.empty?
      end

      Jim.load_spec(spec)
    end
  end
end

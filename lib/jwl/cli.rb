require "fileutils"
require "pathname"
require_relative "build"
require_relative "client"
require_relative "config"
require_relative "console"
require_relative "github_api"
require_relative "packer"
require_relative "simple_opts"

module Jwl
  module Cli
    extend Jwl::Console

    METHODS = %w[signin signout build clean pack release help]

    def self.run(args=nil)
      args ||= ARGV
      args[0] = "help" if %w[--help -h].include?(args[0])

      if METHODS.include?(args[0])
        send(*args)
      else
        help
        exit 1
      end
    end

    # Pack a gem into a single file.
    def self.pack(*args)
      opts = SimpleOpts.new(
        banner: "Usage: jwl pack [--quiet]",
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
#      config = Jwl::Config.load_or_create
#
#      Jwl::Config.set(setting, value) unless value.nil?
#
#      Jwl::Config.get(setting)
#    end

    # Sign in to the specified gem server.
    def self.signin(*args)
      require "io/console"

      opts = SimpleOpts.new(
        defaults: { host: "https://rubygems.org" },
        banner: "Usage: jwl signin [--host HOST] [--otp CODE]",
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

      config = Jwl::Client.new(gem_host).sign_in(username, password, otp)
      name = config["name"]
      scopes = config["scopes"]

      puts "Saved key with name \"#{name}\" and scopes:"
      puts "- " + scopes.filter {|k, v| v}.keys.map(&:to_s).join("\n- ")
    end

    # Sign out from configured gem host
    def self.signout
      Jwl::Config.delete_api_key
    end

    # Builds a Gem from the provided gemspec.
    def self.build(*args)
      opts = SimpleOpts.new(
        banner: "Usage: jwl build [--quiet] [-C PATH] GEMSPEC",
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

      out_file = Dir.chdir(options[:path]) { Jwl::Build.build(spec) }

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
      FileUtils.rm_r(Jwl::Build::BUILD_DIR) if File.exist?(Jwl::Build::BUILD_DIR)
    end

    # Build and release a gem.
    def self.release
      spec = load_spec_or_abort!

      # Re-use the configuration that GitHub Packages wants.
      github_repo = spec.metadata["github_repo"]

      # Re-use the configuration that RubyGems uses to block pushing to the wrong host.
      gem_host = spec.metadata["allowed_push_host"]

      packed_file =
        if spec.executables.length == 1
          puts "Packing gem..."
          self.pack("--quiet")
        end

      puts "Building gem..."
      gem_file = self.build("--quiet")

      unless github_repo
        warn 'No GitHub repo specified. Set spec.metadata["github_repo"] in your gemspec to release to GitHub.'
      end

      unless gem_host
        warn 'No gem host specified. Set spec.metadata["allowed_push_host"] in your gemspec to release to a gem host.'
      end

      gh_release =
        if github_repo
          token = ENV["JWL_GITHUB_TOKEN"]
          if (token.nil? || token.empty?) && ENV["JIM_GITHUB_TOKEN"]
            abort "error: Jim was renamed to Jwl. Please change JIM_GITHUB_TOKEN to JWL_GITHUB_TOKEN."
          end
          abort "error: Expected JWL_GITHUB_TOKEN to be defined"  if token.nil? || token.empty?

          gh_repo_uri = URI(github_repo)
          owner_and_repo = gh_repo_uri.path.sub(%r[^/], '')
          owner, repo = owner_and_repo&.split("/")
          if gh_repo_uri.host != "github.com" || repo.nil?
            abort "error: Expected spec.metadata[\"github_repo\"] to be of the format \"https://github.com/owner/repo\", got #{github_repo.inspect}"
          end

          note = "If you want a self-contained executable, use the packed #{File.basename(packed_file)} file." if packed_file

          files = []
          files << packed_file if packed_file
          files << gem_file

          assets = files.map { |f| [f, Pathname(f).basename] }.to_h

          puts "Preparing GitHub Release."
          gh = Jwl::GithubApi.new(owner, repo, spec.name, token.strip)
          gh.create_release(spec.version, assets: assets, note: note)
        end

      puts "FIXME: Actually publish #{gem_file} to #{gem_host}" if gem_host

      if github_repo
        puts "Publishing GitHub Release."
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
      pp Jwl.load_spec(spec).to_h
    end

    # Print this help text.
    def self.help
      puts <<~EOF
        Usage: jwl [COMMAND] [OPTIONS] [ARGS...]

        Commands
          #{subcommand_summaries("jwl", METHODS).join("\n  ")}
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
        if $JWL_DATA
          Prism.parse_comments($JWL_DATA["files"][file])
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

      Jwl.load_spec(spec)
    end
  end
end

# frozen_string_literal: true

require_relative "lib/jim/version"

Gem::Specification.new do |spec|
  spec.name = "jim"
  spec.version = Jim::VERSION
  spec.authors = ["Ellen Marie Dash"]
  spec.email = ["me@duckie.co"]

  spec.summary = "jim likes gems"
  spec.description = "jim likes gems very much and would like to help you with them"
  spec.homepage = "https://github.com/duckinator/jim"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/duckinator/jim"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end

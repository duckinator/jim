# frozen_string_literal: true

require_relative "lib/jwl/version"

Gem::Specification.new do |spec|
  spec.name = "jwl"
  spec.version = Jwl::VERSION
  spec.authors = ["Ellen Marie Dash"]
  spec.email = ["me@duckie.co"]

  spec.summary = "jewel likes gems"
  spec.description = "jewel likes gems very much and would like to help you with them"
  spec.homepage = "https://github.com/duckinator/jwl"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/duckinator"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/duckinator/jwl"
  spec.metadata["github_repo"] = spec.metadata["source_code_uri"]

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

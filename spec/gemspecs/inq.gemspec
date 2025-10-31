# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "inq"
  spec.version       = "1.2.3"
  spec.authors       = ["Ellen Marie Dash"]
  spec.email         = ["me@duckie.co"]

  spec.summary       = %q{Quantify the health of a GitHub repository.}
  spec.homepage      = "https://github.com/duckinator/inq"
  spec.license       = "MIT"

  spec.files         = [
    ".cirrus.yml",
    ".github_changelog_generator",
    ".gitignore",
    ".rspec",
    ".rubocop.yml",
    "CHANGELOG.md",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "Gemfile",
    "ISSUES.md",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "bors.toml",
    "dashboard-mockups/mockup.html",
    "exe/inq",
    "inq.gemspec",
    "lib/inq.rb",
    "lib/inq/cacheable.rb",
    "lib/inq/cli.rb",
    "lib/inq/config.rb",
    "lib/inq/constants.rb",
    "lib/inq/date_time_helpers.rb",
    "lib/inq/exe.rb",
    "lib/inq/frontmatter.rb",
    "lib/inq/report.rb",
    "lib/inq/report_collection.rb",
    "lib/inq/sources.rb",
    "lib/inq/sources/ci/appveyor.rb",
    "lib/inq/sources/ci/travis.rb",
    "lib/inq/sources/github.rb",
    "lib/inq/sources/github/contributions.rb",
    "lib/inq/sources/github/issue_fetcher.rb",
    "lib/inq/sources/github/issues.rb",
    "lib/inq/sources/github/pulls.rb",
    "lib/inq/sources/github_helpers.rb",
    "lib/inq/template.rb",
    "lib/inq/templates/contributions_partial.html",
    "lib/inq/templates/issues_or_pulls_partial.html",
    "lib/inq/templates/new_contributors_partial.html",
    "lib/inq/templates/report.html",
    "lib/inq/templates/report_partial.html",
    "lib/inq/text.rb",
    "lib/inq/version.rb"
  ]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Inq only supports Ruby versions under "normal maintenance".
  # This number should be updated when a Ruby version goes into security
  # maintenance.
  #
  # Ruby maintenance info: https://www.ruby-lang.org/en/downloads/branches/
  #
  # NOTE: Update Gemfile when this is updated!
  spec.required_ruby_version = "~> 3.3"

  spec.add_runtime_dependency "github_api", "= 0.18.2"
  spec.add_runtime_dependency "okay", "~> 12.0"

  spec.add_runtime_dependency "json_pure"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.9"
  spec.add_development_dependency "timecop", "= 0.9.1"
  spec.add_development_dependency "vcr", "~> 4.0"
  spec.add_development_dependency "webmock"
  # Rubocop pulls in C extensions, which we want to avoid in Windows CI.
  spec.add_development_dependency "rubocop", "= 0.68.1" unless Gem.win_platform? && ENV["CI"]
  spec.add_development_dependency "github_changelog_generator"
end

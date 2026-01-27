# `jwl`, a build and release tool for pure-Ruby gems

`jwl` is a minimal tool for building and (eventually) publishing pure-Ruby gems.

Features:
- signs in to a gem host
- builds gems
- cleans up after itself (if you ask it to)
- will eventually be able to publish gems
- packing an entire (pure-Ruby) gem into a single file

Things `jwl` is not going to do:
- jwl will not support gems with native extensions.
- jwl will not handle every edge case.
- jwl will not manage locally-installed gems.

If you like `jwl` and use Python, be sure to check out [bork](https://github.com/duckinator/bork).

## Installation

I'm hoping to provide single-file executables that bundle the entire gem,
akin to [Python's ZipApps](https://docs.python.org/3/library/zipapp.html).

<!-- You can [download the latest release](https://github.com/duckinator/jwl/releases/latest/download/jwl.rbz]. -->

## Usage

The basic commands you will need are:
- `jwl signin` / `jwl signout`: sign in or out of a gem host.
- `jwl build`: build a gem, with the output in `./build/`.
- `jwl clean`: removes things created by `jwl build`.

More advanced features:
- `jwl pack`: pack an entire gem into `./build/pack/#{gem_name}.rb`.

Eventually, there will also be:
- `jwl push`: push the specified gem to the configured host.

### Basic Usage

```console
puppy@cerberus:~/okay$ jwl signin
Username: duckinator
Password: 
OTP: 
Please choose which scopes you want your API key to have:
index_rubygems? [Y/n] 
push_rubygem? [y/N] y
yank_rubygem? [y/N] 
Saved key with name "jwl--cerberus-puppy-2025-10-25T152604" and scopes:
- index_rubygems
- push_rubygem
puppy@cerberus:~/okay$ jwl build

Name:    okay
Version: 12.0.4

Output:  /home/puppy/okay/build/okay-12.0.4.gem
puppy@cerberus:~/okay$ gem list | grep okay
puppy@cerberus:~/okay$ gem install build/okay-12.0.4.gem 
Successfully installed okay-12.0.4
1 gem installed
puppy@cerberus:~/okay$
```

### Packed Gems

Packing a gem creates a single Ruby file that contains the entirety of a gem.

Your gem needs to:
- be pure Ruby
- have a single gemspec in the directory you run `jwl` from
- have a single executable specified in your gemspec

When you run `jwl pack`, creates a pure-Ruby unpacker, and appends a JSON object to the end of it.

```console
~/jwl$ ruby -Ilib exe/jwl pack
build/pack/jwl.rb
~/jwl$ mv build/pack/jwl.rb ~/jwl.rb
~/jwl$ chmod +x ~/jwl.rb
~/jwl$ cd ~
~$ ./jwl.rb
Usage: jwl [COMMAND] [OPTIONS] [ARGS...]

Commands
  jwl signin
  jwl signout
  jwl build
  jwl clean
  jwl gemspec
  jwl help
  jwl pack
~$
```

### Creating A Release

jwl can not currently publish to gem hosts.
<!--
If you want to publish to a gem host, you first need to add the following to your gemspec:

```ruby
  spec.metadata["allowed_push_host"] = "https://gem-host.example/"
```
-->

If you want to publish to GitHub Releases, you first need to add the following to your gemspec:

```ruby
  spec.metadata["github_repo"] = "https://github.com/EXAMPLE_USER/EXAMPLE_REPO"
```

If you have `jwl_GITHUB_TOKEN` set to a GitHub Access Token, `jwl release` will publish to GitHub Releases.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, run `jwl release`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/duckinator/jwl.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

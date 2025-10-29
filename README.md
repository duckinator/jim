# `jim`, a build and release tool for pure-Ruby gems

`jim` is a minimal tool for building and (eventually) publishing pure-Ruby gems.

Features:
- signs in to a gem host
- builds gems
- cleans up after itself (if you ask it to)
- will eventually be able to publish gems
- packing an entire (pure-Ruby) gem into a single file

Things `jim` is not going to do:
- jim will not support gems with native extensions.
- jim will not handle every edge case.
- jim will not manage locally-installed gems.

If you like `jim` and use Python, be sure to check out [bork](https://github.com/duckinator/bork).

## Installation

I'm hoping to provide single-file executables that bundle the entire gem,
akin to [Python's ZipApps](https://docs.python.org/3/library/zipapp.html).

<!-- You can [download the latest release](https://github.com/duckinator/jim/releases/latest/download/jim.rbz]. -->

## Usage

The basic commands you will need are:
- `jim signin` / `jim signout`: sign in or out of a gem host.
- `jim build`: build a gem, with the output in `./build/`.
- `jim clean`: removes things created by `jim build`.

More advanced features:
- `jim pack`: pack an entire gem into `./build/pack/#{gem_name}.rb`.

Eventually, there will also be:
- `jim push`: push the specified gem to the configured host.

### Example Usage

```console
puppy@cerberus:~/okay$ jim signin
Username: duckinator
Password: 
OTP: 
Please choose which scopes you want your API key to have:
index_rubygems? [Y/n] 
push_rubygem? [y/N] y
yank_rubygem? [y/N] 
Saved key with name "jim--cerberus-puppy-2025-10-25T152604" and scopes:
- index_rubygems
- push_rubygem
puppy@cerberus:~/okay$ jim build

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
- have a single gemspec in the directory you run `jim` from
- have a single executable specified in your gemspec

When you run `jim pack`, creates a pure-Ruby unpacker, and appends a JSON object to the end of it.

```console
~/jim$ ruby -Ilib exe/jim pack
build/pack/jim.rb
~/jim$ mv build/pack/jim.rb ~/jim.rb
~/jim$ chmod +x ~/jim.rb
~/jim$ cd ~
~$ ./jim.rb
Usage: jim [COMMAND] [OPTIONS] [ARGS...]

Commands
  jim signin
  jim signout
  jim build
  jim clean
  jim gemspec
  jim help
  jim pack
~$
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, (TODO).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/duckinator/jim.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

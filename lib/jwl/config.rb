require_relative "platform"
require "fileutils"
require "json"

module Jwl
  class ConfigError < StandardError; end

  class Config
    CONFIG_FILE_NAME = "jwl.json"
    KEY_FILE_NAME = "api-key.json"

    def self.config_dir
      if Platform.windows?
        warn "I haven't tested this on Windows, sorry if there's problems <3"

        config_dir = ENV['LOCALAPPDATA']

        if config_dir.nil?
          raise ConfigError, "LOCALAPPDATA environment variable is not defined -- unsure how to continue"
        end

        File.join(config_dir, 'jwl')
      else
        user_home = ENV['HOME']
        xdg_config_dir = ENV['XDG_CONFIG_DIR']

        if xdg_config_dir.nil? && user_home.nil?
          raise ConfigError, "neither XDG_CONFIG_DIR nor HOME environment variables are defined -- unsure how to continue"
        end

        # Preference, in order:
        # $XDG_CONFIG_DIR/.config/jwl
        # $HOME/.config/jwl
        config_dir = ENV['XDG_CONFIG_DIR'] || File.join(ENV.fetch('HOME'), '.config')
        File.join(config_dir, 'jwl')
      end
    end

    def self.config_file
      File.join(self.config_dir, CONFIG_FILE_NAME).freeze
    end

    def self.key_file
      File.join(self.config_dir, KEY_FILE_NAME).freeze
    end

    def self.save_api_key(name, server, key, scopes, needs_mfa)
      data = {
        "name" => name,
        "server" => server,
        "key" => key,
        "scopes" => scopes,
        "needs_mfa" => needs_mfa,
      }
      FileUtils.mkdir_p(self.config_dir)
      File.write(self.key_file, JSON.dump(data))
      data
    end

    def self.api_key
      @key ||= self.try_load_api_key
    end

    def self.load_api_key
      raise ConfigError, "please sign in first" unless self.has_api_key
      JSON.load_file(self.key_file)
    end

    def self.delete_api_key
      File.delete(self.key_file) if File.exist?(self.key_file)
      raise "failed to remove #{self.key_file}?" if File.exist?(self.key_file)
    end

    def self.has_api_key
      File.exist?(self.key_file)
    end

    def self.try_load_api_key
      self.load_api_key if self.has_api_key
    end
  end
end

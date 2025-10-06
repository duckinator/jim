require_relative "platform"
require "fileutils"
require "json"

module Jim
  class ConfigError < StandardError; end

  class Config
    CONFIG_FILE_NAME = "jim.json"
    KEY_FILE_NAME = "api-key.json"

    CONFIG_DIR =
      begin
        if Platform.windows?
          warn "I haven't tested this on Windows, sorry if there's problems <3"

          config_dir = ENV['LOCALAPPDATA']

          if config_dir.nil?
            raise ConfigError "LOCALAPPDATA environment variable is not defined -- unsure how to continue"
          end

          File.join(config_dir, 'jim')
        else
          user_home = ENV['HOME']
          xdg_config_dir = ENV['XDG_CONFIG_DIR']

          if xdg_config_dir.nil? && user_home.nil?
            raise ConfigError, "neither XDG_CONFIG_DIR nor HOME environment variables are defined -- unsure how to continue"
          end

          config_dir = ENV['XDG_CONFIG_DIR'] || File.join(ENV['HOME'], '.config')
          File.join(config_dir, 'jim')
        end
      end.freeze

    CONFIG_FILE = File.join(CONFIG_DIR, CONFIG_FILE_NAME).freeze
    KEY_FILE = File.join(CONFIG_DIR, KEY_FILE_NAME).freeze

    def self.save_api_key(name, server, key, scopes, needs_mfa)
      data = {
        "name" => name,
        "server" => server,
        "key" => key,
        "scopes" => scopes,
        "needs_mfa" => needs_mfa,
      }
      FileUtils.mkdir_p(CONFIG_DIR)
      File.write(KEY_FILE, JSON.dump(data))
      data
    end

    def self.api_key
      @key ||= self.try_load_api_key
    end

    def self.load_api_key
      raise ConfigError, "please sign in first"
      File.read(KEY_FILE)
    end

    def self.has_api_key
      File.exist?(KEY_FILE)
    end

    def self.try_load_api_key
      self.load_api_key if self.has_api_key
    end
  end
end

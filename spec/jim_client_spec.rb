# frozen_string_literal: true

require_relative "../lib/jim/client.rb"
require "tmpdir"

RSpec.describe Jim::Client do
  let(:server) { "https://gem-host.example" }
  let(:key) { "fake-api-key" }
  let(:username) { "fake-user" }
  let(:password) { "fake-password" }
  let(:otp) { "fake-otp" }

  let(:default_scopes) {
    {
      "index_rubygems" => true,
      "push_rubygem" => false,
      "yank_rubygem" => false,
    }
  }

  describe "sign_in" do
    it "respects LOCALAPPDATA on Windows" do
      skip "Windows-specific test" unless Jim::Platform.windows?

      Dir.mktmpdir do |dir|
        stub_const("ENV", {"LOCALAPPDATA" => dir})

        #Jim::Config.save_api_key("some-name", "some-server", "some-key", "some-scopes", "needs-mfa")
        Jim::Client.new
      end
    end

    it "respects XDG_CONFIG_DIR on *nix" do
      skip "*nix-specific test" unless Jim::Platform.unixy?

      Dir.mktmpdir do |dir|
        stub_const("ENV", {"XDG_CONFIG_DIR" => dir})

        client = Jim::Client.new(server)
        client.always_default = true
        expect(client).to receive(:create_api_key).and_return(key)

        client.sign_in(username, password)

        expect(Jim::Config.key_file).to eq(File.join(dir, "jim", Jim::Config::KEY_FILE_NAME))
        api_key = Jim::Config.load_api_key
        expect(api_key["needs_mfa"]).to eq(false)
        expect(api_key["scopes"]).to eq(default_scopes)
        expect(api_key["key"]).to eq(key)
      end
    end

    it "respects HOME on *nix if XDG_CONFIG_DIR is not set" do
      skip "*nix-specific test" unless Jim::Platform.unixy?

      Dir.mktmpdir do |dir|
        stub_const("ENV", {"HOME" => dir})

        client = Jim::Client.new(server)
        client.always_default = true
        expect(client).to receive(:create_api_key).and_return(key)

        client.sign_in(username, password, otp)

        expect(Jim::Config.key_file).to eq(File.join(dir, ".config", "jim", Jim::Config::KEY_FILE_NAME))
        api_key = Jim::Config.load_api_key
        expect(api_key["needs_mfa"]).to eq(true)
        expect(api_key["scopes"]).to eq(default_scopes)
        expect(api_key["key"]).to eq(key)
      end
    end
  end
end

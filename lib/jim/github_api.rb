require_relative "http"
require 'json'
require 'open3'
require 'uri'

module Jim
  module GithubApiHelpers
    def api_req(endpoint, data, headers, server, method)
      headers ||= {}
      server ||= "https://api.github.com"

      headers["Authorization"] = "token #{token}"
      headers["Accept"] = "application/vnd.github.v3+json"

      kwargs = {
        headers: headers,
      }

      unless data.nil?
        kwargs[:data] = data
        kwargs[:data] = JSON.dump(data) if data.is_a?(Array) || data.is_a?(Hash)
      end

      url = URI.join(server, endpoint)

      HTTP.send(method, url, **kwargs).or_raise!.from_json
    end

    def api_post(endpoint, data, headers=nil, server=nil)
      api_req(endpoint, data, headers, server, :post)
    end

    def api_get(endpoint, headers=nil, server=nil)
      api_req(endpoint, nil, headers, server, :get)
    end

    def api_patch(endpoint, data, headers=nil, server=nil)
      api_req(endpoint, data, headers, server, :patch)
    end
  end


  class GithubApi < Struct.new("GithubApi", :owner, :repo, :project_name, :token)
    include GithubApiHelpers
    # This is a fairly direct Python-to-Ruby port of bork.github_api:
    # https://github.com/duckinator/bork/blob/main/bork/github_api.py

    class Release < Struct.new("Release", :release, :token)
      include GithubApiHelpers

      def publish!
        url = "/" + release["url"].split("/", 4).last
        api_patch(url, {"draft" => false})
      end
    end

    # `tag_name` is the name of the tag.
    # `commitish` is a commit hash, branch, tag, etc.
    # `body` is the body of the commit.
    # `draft` indicates whether it should be a draft release or not.
    # `prerelease` indicates whether it should be a prerelease or not.
    # `assets` is a Hash mapping local file paths to the uploaded asset name.
    def create_release(tag_name, name: nil, commitish: nil, body: nil, draft: true,
                       prerelease: nil, assets: nil)
      name ||= "%{project_name} %{tag}"
      commitish ||= run("git", "rev-parse", "HEAD")
      body ||= "%{repo} %{tag}"
      name ||= "%{project_name} %{tag}"

      draft_indicator = draft ? ' as a draft' : ''

      puts "Creating GitHub release #{tag_name}#{draft_indicator} (commit=#{commitish})"

      prerelease ||= !!(tag_name =~ /[a-zA-Z]/)

      format_hash = {
        project_name: project_name,
        owner: owner,
        repo: repo,
        tag: tag_name,
        tag_name: tag_name,
      }

      # Don't fetch changelog info unless needed.
      if body.include?('{changelog}')
        format_dict['changelog'] = changelog
      end

      request = {
        "tag_name" => tag_name,
        "target_commitish" => commitish,
        "name" => name % format_hash,
        "body" => body % format_hash,
        "draft" => draft,
        "prerelease" => prerelease,
      }
      p request
      url = "/repos/#{owner}/#{repo}/releases"
      response = api_post(url, request)

      upload_url = response["upload_url"].split("{?").first

      if assets
        assets.each { |local_file, asset_name|
          add_release_asset(upload_url, local_file, asset_name)
        }
      end

      Release.new(response, token)
    end

    private

    def changelog
      prs = api_get("/repos/#{owner}/#{repo}/pulls?state=closed")
      summaries = prs
        .filter(&method(:relevant_to_changelog))
        .map(&method(:format_for_changelog))

      summaries.join("\n")
    end

    def format_for_changelog(pr)
      "* #{pr['title']} (#{pr['number']}) by @#{pr['user']['login']}"
    end

    def relevant_to_changelog(pr)
      return false if pr.nil? || !pr.has_key?("merged_at")

      return !last_release || (pr["merged_at"] > last_release["created_at"])
    end

    def last_release
      @last_release ||= api_get("/repos/#{owner}/#{repo}/releases")[0]
    end

    def add_release_asset(upload_url, local_file, name)
      puts "Adding asset #{name} to release (original file: #{local_file})"

      data = File.open(local_file, 'rb') { |f| f.read }

      headers = { "Content-Type" => "application/octet-stream" }

      url = "#{upload_url}?name=#{name}"
      api_post(url, data, headers=headers, server="")
    end

    def run(*command)
      status, out, err = Open3.popen3(*command) { |i, o, e, w| [w.value, o.read, e.read] }

      unless status.success?
        abort "error: #{command.first} exited with status #{status.exitstatus}: #{err}"
      end

      out.strip
    end
  end
end

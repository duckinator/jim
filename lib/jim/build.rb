require_relative "tar"
require "digest"
require "yaml"
require "zlib"

module Jim
  class Build
    BUILD_DIR = "build"

    CHECKSUMS_FILE = "checksums.yaml.gz"
    DATA_FILE = "data.tar.gz"
    METADATA_FILE = "metadata.gz"

    CHECKSUMS_PATH = File.join(BUILD_DIR, CHECKSUMS_FILE)
    DATA_PATH = File.join(BUILD_DIR, DATA_FILE)
    METADATA_PATH = File.join(BUILD_DIR, METADATA_FILE)

    def self.sha256(file)
      Digest::SHA256.hexdigest File.read(file)
    end

    def self.sha512(file)
      Digest::SHA512.hexdigest File.read(file)
    end

    def self.build(spec)
      spec = Jim.load_spec(spec) if spec.is_a?(String)

      filename = "#{spec.name}-#{spec.version}.gem"

      # Create the build directory if needed.
      Dir.mkdir(BUILD_DIR) unless Dir.exist?(BUILD_DIR)

      # Remove the output files, if they already exist.
      FileUtils.rm_f([CHECKSUMS_PATH, DATA_PATH, METADATA_PATH])

      Jim::Tar::UStarBuilder.new { |d|
        spec.files.each { |f|
          d.add_file_path(f)
        }
      }.build.save(DATA_PATH)

      Zlib::GzipWriter.open(METADATA_PATH) { |gz|
        gz.mtime = Jim.source_date_epoch.to_i
        gz.write(
          YAML.dump(spec.to_h)
            .gsub(/\A---$/, '--- !ruby/object:Gem::Specification')
            .gsub(/^required_(ruby|rubygems)_version:$/, '\1: !ruby/object:Gem::Requirement')
            .gsub(/^version:$/, 'version: !ruby/object:Gem::Version')
        )
      }

      checksums = {
        "SHA256" => {
          "metadata.gz" => self.sha256(METADATA_PATH),
          "data.tar.gz" => self.sha256(DATA_PATH),
        },
        "SHA512" => {
          "metadata.gz" => self.sha512(METADATA_PATH),
          "data.tar.gz" => self.sha512(DATA_PATH),
        },
      }
      Zlib::GzipWriter.open(CHECKSUMS_PATH) { |gz|
        gz.mtime = Jim.source_date_epoch.to_i
        gz.write YAML.dump(checksums)
      }

      Dir.chdir(BUILD_DIR) {
        Jim::Tar::UStarBuilder.new
          .add_file_path(CHECKSUMS_FILE)
          .add_file_path(DATA_FILE)
          .add_file_path(METADATA_FILE)
          .build
          .save(filename)
      }
    end
  end
end

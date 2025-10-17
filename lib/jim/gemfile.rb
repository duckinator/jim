require_relative "tar"
require "yaml"
require "zlib"

module Jim
  class Gemfile
    def self.sha256(file)
      Digest::SHA256.hexdigest File.read(file)
    end

    def self.sha512(file)
      Digest::SHA512.hexdigest File.read(file)
    end

    def self.build(gemspec)
      spec = Jim.load_spec(gemspec)
      filename = "#{spec.name}-#{spec.version}.gem"

      Dir.mkdir("build")

      Jim::Tar::UStarBuilder.new { |d|
        spec.files.each { |f|
          d.add_file_path(f)
        }
      }.build.save("build/data.tar.gz")

      Zlib::GzipWriter.open("build/metadata.gz") { |gz|
        gz.mtime = Jim.source_date_epoch.to_i
        gz.write YAML.dump(spec.to_h)
      }

      checksums = {
        SHA256: {
          "metadata.gz": self.sha256("build/metadata.gz"),
          "data.tar.gz": self.sha256("build/data.tar.gz"),
        },
        SHA512: {
          "metadata.gz": self.sha512("build/metadata.gz"),
          "data.tar.gz": self.sha512("build/data.tar.gz"),
        },
      }
      Zlib::GzipWriter.open("build/checksums.yaml.gz") { |gz|
        gz.mtime = Jim.source_date_epoch.to_i
        gz.write YAML.dump(checksums)
      }

      Dir.chdir("build") {
        Jim::Tar::UStarBuilder.new
          .add_file_path("checksums.yaml.gz")
          .add_file_path("data.tar.gz")
          .add_file_path("metadata.gz")
          .build
          .save(filename)
      }
    end
  end
end

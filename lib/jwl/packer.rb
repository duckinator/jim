require "json"

module Jwl
  module Packer
    UNPACKER = <<~EOF
      require 'json'
      require 'pathname'

      $JWL_DATA = JSON.load(DATA)
      $PACKED_BY_JWL = $JWL_DATA["name"]

      $JWL_DEBUG = ENV['JWL_DEBUG']

      module Kernel
        def jwl_require_relative(path, relative_to)
          base_dir = Pathname(relative_to).dirname
          full_path = Pathname(base_dir).join(path).sub_ext(".rb").to_s

          if $JWL_DATA["files"].keys.include?(full_path)
            puts "Loading packed " + full_path + "..." if $JWL_DEBUG
            unless $JWL_LOADED.include?(full_path)
              eval($JWL_DATA["files"][full_path], binding, full_path, 1)
              $JWL_LOADED.push(full_path)
            end
            return true
          end

          raise LoadError, "cannot load such file -- " + full_path + " (" + path + ")"
        end

        alias_method :jwl_orig_require, :require
        def require(path)
          jwl_orig_require(path)
        rescue LoadError => e
          raise e unless e.path == path

          $JWL_DATA["require_paths"].each do |req_path|
            combined = Pathname(req_path).join(path).sub_ext(".rb").to_s
            $JWL_LOADED ||= []
            if $JWL_DATA["files"].keys.include?(combined)
              puts "Loading packed " + combined + "..." if $JWL_DEBUG
              unless $JWL_LOADED.include?(combined)
                eval($JWL_DATA["files"][combined], binding, combined, 0)
                $JWL_LOADED.push(combined)
              end
              return true
            end
          end

          raise e
        end
      end

      $JWL_EXECUTABLE = $JWL_DATA["executable"]
      $JWL_EXE_CONTENTS = $JWL_DATA["files"][$JWL_EXECUTABLE]
      eval($JWL_EXE_CONTENTS, binding, $JWL_EXECUTABLE, 1)

      __END__
    EOF


    def self.pack(spec)
      files = spec.files.map { |file|
        contents = File.read(file)
        contents.gsub!(/^( *)(require_relative .*)$/, '\1jwl_\2,' + file.inspect)
        [file, contents]
      }.to_h

      data = {
        "name": spec.name,
        "files": files,
        "require_paths": spec.require_paths,
        "executable": File.join(spec.bindir, spec.executables.first)
      }

      [
        "#!/usr/bin/env ruby",
        "",
        "# #{spec.name} #{spec.version}",
        "# Packed by Jwl #{Jwl::VERSION}",
        UNPACKER,
        JSON.pretty_generate(data),
      ].join("\n")
    end
  end
end

require "json"

module Jim
  module Packer
    def self.pack(spec)
      files = spec.files.map { |file|
        contents = File.read(file)
        contents.gsub!(/^( *)(require_relative .*)$/, '\1jim_\2,' + file.inspect)
        [file, contents]
      }.to_h

      data = {
        "files": files,
        "require_paths": spec.require_paths,
        "executable": File.join(spec.bindir, spec.executables.first)
      }

      <<~EOF
        #!/usr/bin/env ruby

        # #{spec.name} #{spec.version} 0.2.0
        # Packed by Jim #{Jim::VERSION}

        require 'json'
        require 'pathname'

        $PACKED_BY_JIM = #{spec.name.inspect}
        $JIM_DATA = JSON.load(DATA)

        $JIM_DEBUG = ENV['JIM_DEBUG']

        module Kernel
          def jim_require_relative(path, relative_to)
            base_dir = Pathname(relative_to).dirname
            full_path = Pathname(base_dir).join(path).sub_ext(".rb").to_s

            if $JIM_DATA["files"].keys.include?(full_path)
              puts "Loading packed " + full_path + "..." if $JIM_DEBUG
              unless $JIM_LOADED.include?(full_path)
                eval($JIM_DATA["files"][full_path], binding, full_path, 0)
                $JIM_LOADED.push(full_path)
              end
              return true
            end

            raise LoadError, "cannot load such file -- " + full_path + " (" + path + ")"
          end

          alias_method :jim_orig_require, :require
          def require(path)
            jim_orig_require(path)
          rescue LoadError => e
            raise e unless e.path == path

            $JIM_DATA["require_paths"].each do |req_path|
              combined = Pathname(req_path).join(path).sub_ext(".rb").to_s
              $JIM_LOADED ||= []
              if $JIM_DATA["files"].keys.include?(combined)
                puts "Loading packed " + combined + "..." if $JIM_DEBUG
                unless $JIM_LOADED.include?(combined)
                  eval($JIM_DATA["files"][combined], binding, combined, 0)
                  $JIM_LOADED.push(combined)
                end
                return true
              end
            end

            raise e
          end
        end

        $JIM_EXECUTABLE = $JIM_DATA["executable"]
        $JIM_EXE_CONTENTS = $JIM_DATA["files"][$JIM_EXECUTABLE]
        eval($JIM_EXE_CONTENTS, binding, $JIM_EXECUTABLE, 0)

        __END__
        #{JSON.dump(data)}
      EOF
    end
  end
end

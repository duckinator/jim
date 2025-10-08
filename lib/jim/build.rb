require "fileutils"
require "pathname"
require "tmpdir"

module Jim
  class BuildError < StandardError; end

  class Build
    OUT_DIR = "dist"

    def initialize(gemspec, path: nil)
      @gemspecs = [*(gemspec || find_gemspecs)]
      @path = path

      raise BuildError, "no gemspec found" if @gemspecs.empty?
    end

    def execute!
      @gemspecs.map(&method(:build))
    end

    def with_path(&block)
      if @path
        Dir.chdir(@path, &block)
      else
        yield
      end
    end
    private :with_path

    def find_gemspecs
      with_path { Dir['*.gemspec'] }
    end
    private :find_gemspecs

    def output_file_for_spec(spec)
      with_path {
        Pathname.new(OUT_DIR)
          .join("#{spec.name}-#{spec.version}.gem")
          .expand_path
      }
    end

    def build(gemspec)
      source_dir = with_path { Dir.pwd }
      spec = Jim.load_spec(gemspec)
      out_file = output_file_for_spec(spec)
      out_dir = out_file.dirname

      Dir.mktmpdir(["jim", spec.name]) { |dir|
        puts "Working directory: #{dir}"
        puts
        Dir.chdir(dir) {
          puts "Building #{out_file.basename}..."
          build_here(source_dir, spec, out_file)

          puts "Creating #{out_dir}..."
          out_dir.mkpath

          puts "Moving built gem to final location..."
          FileUtils.mv(out_file.basename, out_file)
        }
      }
      puts
      puts "Name:    #{spec.name}"
      puts "Version: #{spec.version}"
      puts
      puts "Output:  #{out_file}"
    end
    private :build

    def build_here(source_dir, spec, out_file)
      File.write(out_file.basename, "FIXME")
    end
  end
end

require "pathname"
require "stringio"

module Jim
  module Tar
    def self.write(path, &block)
      File.open(path) { UStarBuilder.new(&block) }
    end

    RECORD_SIZE = 512

    HEADER_INFO = [
      # name      pack    unpack    offset
      [:name,     'a100', 'Z100',   0],
      [:mode,     'a8',   'A8',     100],
      [:oid,      'a8',   'A8',     108,],
      [:gid,      'a8',   'A8',     116],
      [:size,     'a12',  'A12',    124],
      [:mtime,    'a12',  'A12',    136],
      [:checksum, 'a8',   'A8',     148],
      [:typeflag, 'a',    'a',      156],
      [:linkname, 'a100', 'Z100',   157],
      [:magic,    'a6',   'A6',     257],
      [:version,  'a2',   'A2',     263],
      [:uname,    'a32',  'Z32',    265],
      [:gname,    'a32',  'Z32',    297],
      [:devmajor, 'a8',   'A8',     329],
      [:devminor, 'a8',   'A8',     337],
      [:prefix,   'a155', 'Z155',   345],
    ]

    class UStarRecord < StringIO
      def self.open(&block)
        super { |s|
          s.instance_exec(&block)
          s.string
        }
      end

      def self.defaults
        {
          magic: "ustar\0",
          version: "00",
          checksum: "",
          mtime: source_date_epoch,
          typeflag: "0",
          linkname: "",
          devmajor: "0",
          devminor: "0",
          prefix: "",
        }
      end

      def self.source_date_epoch
        # The default value for SOURCE_DATE_EPOCH if not specified.
        # We want a date after 1980-01-01, to prevent issues with Zip files.
        # This particular timestamp is for 1980-01-02 00:00:00 GMT.
        Time.at(ENV['SOURCE_DATE_EPOCH'] || 315_619_200).utc.freeze
      end

      def self.load(file)
        raise UnimplementedError
      end

      def self.from(contents, **opts)
        opts[:size] = contents.length.to_s(8)
        HEADER_INFO.each { |(name, pack, unpack, offset)|
          opts[name] = opts[name] || self.defaults.fetch(name)
        }

        opts[:mtime] = opts[:mtime].to_i.to_s(8)
        opts[:devmajor] = opts[:devmajor].rjust(7, "0")
        opts[:devminor] = opts[:devminor].rjust(7, "0")

        self.open {
          HEADER_INFO.map { |(name, pack, unpack, offset)|
            write([opts[name]].pack(pack))
          }

          write([nil].pack("Z12"))

          length = contents.length
          unless (contents.length % RECORD_SIZE).zero?
            length += RECORD_SIZE - (contents.length % RECORD_SIZE)
          end
          write([contents].pack("a#{length}"))
          self.string
        }
      end
    end

    # Write files in the UStar (_Unix Standard TAR_) format.
    class UStarBuilder
      def initialize(&block)
        @io = StringIO.new
        self
      end

      def close_write
        @io.close_write
      end

      def add_file(contents, **opts)
        @io.write(UStarRecord.from(contents, **opts))
        self
      end

      def build
        @io.close_write
        UStarBuilt.new(@io)
      end
    end

    class UStarBuilt
      def initialize(io)
        @io = io
      end

      def save(file)
        File.open(file, 'w') { |f|
          @io.rewind
          IO.copy_stream(@io, f)
        }
      end
    end
  end
end

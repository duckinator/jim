require "pathname"
require "stringio"

module Jim
  module Tar
    BLOCK_SIZE = 512
    RECORD_SIZE = BLOCK_SIZE * 20

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
      [:_PADDING, 'Z12',  'Z12',    500],
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
          magic: "ustar  ",
          version: " ",
          checksum: "".ljust(8),
          mtime: source_date_epoch,
          typeflag: "0",
          linkname: "",
          devmajor: "\x00",
          devminor: "\x00",
          prefix: "",
          _PADDING: nil,
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
        opts[:size] = contents.length
        HEADER_INFO.each { |(name, pack, unpack, offset)|
          opts[name] = opts[name] || self.defaults.fetch(name)
        }

        opts[:mode] = opts[:mode].rjust(7, "0")
        opts[:oid] = opts[:oid].to_i.to_s(8).rjust(7, "0")
        opts[:gid] = opts[:gid].to_i.to_s(8).rjust(7, "0")
        opts[:size] = opts[:size].to_s(8).rjust(11, "0")
        opts[:mtime] = opts[:mtime].to_i.to_s(8).rjust(11, "0")

        header = HEADER_INFO.map { |(name, pack, unpack, offset)|
          [opts[name]].pack(pack)
        }.join('')

        checksum = header.unpack('C512').sum

        # From wikipedia:
        #   "[The checksum] is stored as a six digit octal number with
        #    leading zeroes followed by a NUL and then a space"
        header[148...(148 + 8)] = checksum.to_s(8).rjust(6, "0") + "\x00 "

        self.open {
          write(header)

          length = contents.length
          unless (contents.length % BLOCK_SIZE).zero?
            length += BLOCK_SIZE - (contents.length % BLOCK_SIZE)
          end
          write([contents].pack("a#{length}"))

          write([nil].pack("a1024"))

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
        @io.write([nil].pack("a#{RECORD_SIZE - @io.pos}"))
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

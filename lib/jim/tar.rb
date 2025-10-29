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
      [:oid,      'a8',   'A8',     108],
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
          mode: "664",
          oid: 1000,
          gid: 1000,
          uname: "user",
          gname: "group",
          version: " ",
          checksum: "".ljust(8),
          mtime: Jim.source_date_epoch,
          typeflag: "0",
          linkname: "",
          devmajor: "\x00",
          devminor: "\x00",
          prefix: "",
          _PADDING: nil,
        }
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

        abort "??? tar header is #{header.length} bytes long ???" unless header.length == 512

        checksum = header.unpack('C512').sum

        # From wikipedia:
        #   "[The checksum] is stored as a six digit octal number with
        #    leading zeroes followed by a NUL and then a space"
        header[148...(148 + 8)] = checksum.to_s(8).rjust(6, "0") + "\x00 "

        self.open { |io|
          io.write(header)

          length = contents.length
          unless (contents.length % BLOCK_SIZE).zero?
            length += BLOCK_SIZE - (contents.length % BLOCK_SIZE)
          end
          io.write([contents].pack("a#{length}"))

          io.string
        }
      end
    end

    # Write files in the UStar (_Unix Standard TAR_) format.
    class UStarBuilder
      def initialize(&block)
        @io = StringIO.new
        instance_exec(self, &block) if block
        self
      end

      def close_write
        @io.close_write
      end

      def add_file_path(path, **opts)
        File.open(path, 'rb') { |f|
          add_file(f.read, name: path, **opts)
        }
      end

      def add_file(contents, **opts)
        @io.write(UStarRecord.from(contents, **opts))
        @io.flush
        self
      end

      def build
        length = @io.pos
        unless (@io.pos % RECORD_SIZE).zero?
          length += RECORD_SIZE - (@io.pos % RECORD_SIZE)
        end

        @io.write([nil].pack("a#{length}"))
        @io.write([nil].pack("a1024")) # FIXME: Determine if this is needed.
        @io.close_write
        UStarBuilt.new(@io)
      end
    end

    class UStarBuilt
      attr_reader :io

      def initialize(io)
        @io = io
      end

      def save(file)
        @io.rewind

        if File.extname(file) == ".gz"
          Zlib::GzipWriter.open(file) { |gz|
            gz.mtime = Jim.source_date_epoch.to_i
            IO.copy_stream(@io, gz)
          }
        else
          IO.copy_stream(@io, file)
        end

        Pathname.new(file).expand_path.to_s
      end
    end
  end
end

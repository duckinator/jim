module Jim
  module Platform
    def self.host_os
      RbConfig::CONFIG["host_os"]
    end

    def self.windows?
      /mswin|msdos|mingw|djgpp/.match? host_os
    end

    def self.linux?
      /linux/.match? host_os
    end

    def self.macos?
      /darwin/.match? host_os
    end

    def self.bsd?
      /bsd/.match? host_os
    end

    def self.solaris?
      /solaris/.match? host_os
    end

    def self.unixy?
      linux? || macos? || bsd? || solaris?
    end
  end
end

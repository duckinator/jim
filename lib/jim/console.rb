module Jim
  module Console
    def prompt(msg, default=nil, noecho: false)
      return default unless default.nil?

      print "#{msg}: "

      if noecho
        STDIN.noecho(&:gets)&.chomp
      else
        STDIN.gets&.chomp
      end
    end
  end
end

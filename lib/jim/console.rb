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

    def prompt_yesno(msg, default_to_yes: false)
      yesno = (default_to_yes ? "Y/n" : "y/N")

      begin
        print "#{msg} [#{yesno}] "
        result = STDIN.gets&.strip&.downcase
      end until result && ['y', 'n', ''].include?(result)

      (result == "y") || (result.empty? && default_to_yes)
    end
  end
end

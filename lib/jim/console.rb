module Jim
  module Console
    attr_accessor :always_default
    @always_default = false

    def prompt(msg, default=nil, noecho: false)
      return default if @always_default

      print "#{msg}: "

      if noecho
        STDIN.noecho(&:gets)&.chomp || default
      else
        STDIN.gets&.chomp || default
      end
    end

    def prompt_yesno(msg, default_to_yes: false)
      return default_to_yes if @always_default

      yesno = (default_to_yes ? "Y/n" : "y/N")

      begin
        print "#{msg} [#{yesno}] "
        result = STDIN.gets&.strip&.downcase
      end until result && ['y', 'n', ''].include?(result)

      (result == "y") || (result.empty? && default_to_yes)
    end
  end
end

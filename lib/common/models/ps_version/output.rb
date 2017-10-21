# encoding: UTF-8

class PsVersion < PsItem
  module Output

    def output(verbose = false)
      metadata = self.metadata(self.number)

      puts
      if verbose
        puts info("Prestashop version #{self.number} identified from #{self.found_from}")
        puts " | Released: #{metadata[:created_at]}"
      else
        puts info("Prestashop version #{self.number} #{"(Released on #{metadata[:created_at]}) identified from #{self.found_from}" if metadata[:created_at]}")
      end

      # Todo show vulnerabilities  ;)
      # vulnerabilities = self.vulnerabilities

      # unless vulnerabilities.empty?
      #   if vulnerabilities.size == 1
      #      puts critical("#{vulnerabilities.size} vulnerability identified from the version number")
      #   else
      #      puts critical("#{vulnerabilities.size} vulnerabilities identified from the version number")
      #   end
      #   vulnerabilities.output
      # end
    end

  end
end

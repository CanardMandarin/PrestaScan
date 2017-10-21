# encoding: UTF-8

class PsTarget < WebSite
  module PsFullPathDisclosure
    # Check for Full Path Disclosure (FPD)
    #
    # @return [ Boolean ]
    def has_full_path_disclosure?
      Browser.get(full_path_disclosure_url).body[%r/Fatal error/i] ? true : false
    end

    def full_path_disclosure_data
      return nil unless has_full_path_disclosure?
      Browser.get(full_path_disclosure_url).body[/Fatal error:.+? in (.+?) on/i, 1]
    end

    # @return [ String ]
    def full_path_disclosure_url
      if @fpd_path.nil?
        @fpd_path = Database.instance.full_path_disclosure(self.ps_version.number)
      end
      @uri.merge(@fpd_path).to_s
    end
  end
end

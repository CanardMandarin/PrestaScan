# encoding: UTF-8

class PsVersion < PsItem

  module Findable
    # Find the version of the shop designated from target_uri
    #
    # @param [ URI ] target_uri
    #
    # @return [ PsVersion ]
    def find(target_uri)
      versions = {}

      Database.instance.list_top_path.each do |path|
        version = scan_file(target_uri, path['value'], path['md5_hash'])
        if version
          version.each do |v|
            if versions.key?(v)
              versions[v] << path['value']
            else
              versions[v] = [ path['value'] ]
            end
          end
        end
      end

      if versions.length > 0
        determined_version = versions.max_by { |k, v| v.length }
        if determined_version
          return new(target_uri, number: determined_version[0], found_from: determined_version[1].join(', '))
        end
      end

      nil
    end

    # Used to check if the version is correct: must contain at least one dot.
    #
    # @return [ String ]
    def version_pattern
      '([^\r\n"\',]+\.[^\r\n"\',]+)'
    end

    protected

    # Returns the first match of <pattern> in the body of the url
    #
    # @param [ URI ] target_uri
    # @param [ Regex ] pattern
    # @param [ String ] path
    #
    # @return [ String ]
    def scan_url(target_uri, pattern, path = nil)
      url = path ? target_uri.merge(path).to_s : target_uri.to_s
      response = Browser.get_and_follow_location(url)

      response.body[pattern, 1]
    end

    # Returns the first match of <pattern> in the body of the url
    #
    # @param [ URI ] target_uri
    # @param [ Regex ] pattern
    # @param [ String ] path
    #
    # @return [ String ]
    def scan_file(target_uri, filename, md5_hash)
      url = target_uri.merge(filename).to_s
      response = Browser.get_and_follow_location(url)


      if response.code == 200
        puts notice("File #{filename} exists maybe we can identify prestashop version")
        md5_body = Digest::MD5.hexdigest(response.body)
        Database.instance.version_by_hash(md5_body)
      else
        false
      end
    end

  end
end

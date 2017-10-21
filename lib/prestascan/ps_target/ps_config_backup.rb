# encoding: UTF-8

class PsTarget < WebSite
  module PsConfigBackup

    # Checks to see if wp-config.php has a backup
    # See http://www.feross.org/cmsploit/
    # @return [ Array ] Backup config files
    def config_backup
      found       = []
      backups     = config_backup_files

      browser     = Browser.instance
      hydra       = browser.hydra
      queue_count = 0

      backups.each do |file|
        file_name = File.basename file
        file_dir = File.dirname file
        file_dir = file_dir + "/"
        file_url = @uri.merge(file_dir + url_encode(file_name)).to_s
        request = browser.forge_request(file_url, {followlocation: true})

        request.on_complete do |response|
          if response.body[%r{define}i] and not response.body[%r{<\s?html}i]
            found << file_url
          end
        end

        hydra.queue(request)
        queue_count += 1

        if queue_count == browser.max_threads
          hydra.run
          queue_count = 0
        end
      end

      hydra.run

      found
    end

    # @return [ Array ]
    def config_backup_files
      if @config_paths.nil?
        @config_paths = Database.instance.config_backup_paths(self.ps_version.number)
      end
      @config_paths
    end

  end
end

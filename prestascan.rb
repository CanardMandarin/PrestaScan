#!/usr/bin/env ruby
# encoding: UTF-8

$: << '.'

$exit_code = 0

require File.join(__dir__, 'lib', 'prestascan', 'prestascan_helper')


def main
  begin
    prestascan_options = PrestascanOptions.load_from_arguments

    $log = prestascan_options.log

    # some sanity checks
    if $log
      if $log.empty?
        $log = DEFAULT_LOG_FILE
      end

      # translate to full path if no starting / detected
      if $log !~ /^#{File::SEPARATOR}/
        $log = File.join(ROOT_DIR, $log)
      end

      # check if file exists and has a size greater zero
      if File.exist?($log) && File.size?($log)
        puts notice("The supplied log file #{$log} already exists. If you continue the new output will be appended.")
        print '[?] Do you want to continue? [Y]es [N]o, default: [N]'
        if Readline.readline !~ /^y/i
          # unset logging so puts will try to log to the file
          $log = nil
          puts notice('Scan aborted')
          exit(1)
        end
      end

      # check if we can write the file
      begin
        File.open($log, 'a')
      rescue SystemCallError => e
        # unset logging so puts will try to log to the file
        temp = $log
        $log = nil
        puts critical("Error with logfile #{temp}:")
        puts critical(e)
        exit(1)
      end
    end

 	  banner() unless prestascan_options.no_banner # called after $log set

    unless prestascan_options.has_options?
      # first parameter only url?
      if ARGV.length == 1
        prestascan_options.url = ARGV[0]
      else
        usage()
        raise('No argument supplied')
      end
    end

    # Define a global variable
    $COLORSWITCH = prestascan_options.no_color

    if prestascan_options.help
      help()
      usage()
      exit(0)
    end

    if prestascan_options.version
      puts "Current version: #{PRESTASCAN_VERSION}"
      date = last_update
      puts "Last DB update: #{date.strftime('%Y-%m-%d')}" unless date.nil?
      exit(0)
    end

    # Initialize the browser to allow the db update
    # to be done over a proxy if set
    Browser.instance(
      prestascan_options.to_h.merge(max_threads: prestascan_options.threads)
    )

    Database.instance()

    # TODO make a db clean update top update the /data/prestashop.db
    # check if db file needs upgrade and we are not running in batch mode
    # also no need to check if the user supplied the --update switch
    # if update_required? && !prestascan_options.batch && !prestascan_options.update
    #   puts notice('It seems like you have not updated the database for some time.')
    #   print '[?] Do you want to update now? [Y]es [N]o [A]bort, default: [N]'
    #   if (input = Readline.readline) =~ /^y/i
    #     prestascan_options.update = true
    #   elsif input =~ /^a/i
    #     puts 'Scan aborted'
    #     exit(1)
    #   else
    #     if missing_db_file?
    #       puts critical('You can not run a scan without any databases. Extract the data.zip file.')
    #       exit(1)
    #     end
    #   end
    # end

    if prestascan_options.update
      puts notice('Updating the Database ...')
      DbUpdater.new(DATA_DIR).update(prestascan_options.verbose)
      puts notice('Update completed.')
      # Exit program if only option --update is used
      exit(0) unless prestascan_options.url
    end

    unless prestascan_options.url
      raise 'The URL is mandatory, please supply it with --url or -u'
    end

    ps_target = PsTarget.new(prestascan_options.url, prestascan_options.to_h)

    if ps_target.ssl_error?
      raise "The target site returned an SSL/TLS error. You can try again using the --disable-tls-checks option.\nError: #{wp_target.get_root_path_return_code}\nSee here for a detailed explanation of the error: http://www.rubydoc.info/github/typhoeus/ethon/Ethon/Easy:return_code"
    end

    # Remote website up?
    unless ps_target.online?
      raise "The PrestaShop URL supplied '#{ps_target.uri}' seems to be down. Maybe the site is blocking prestascan so you can try the --random-agent parameter."
    end

    if prestascan_options.proxy
      proxy_response = Browser.get(ps_target.url)

      unless PsTarget::valid_response_codes.include?(proxy_response.code)
        raise "Proxy Error :\r\nResponse Code: #{proxy_response.code}\r\nResponse Headers: #{proxy_response.headers}"
      end
    end

    # Remote website has a redirection?
    if (redirection = ps_target.redirection)
      if redirection =~ /install/
        puts critical('The Website is not fully configured and currently in install mode. Call it to create a new admin user.')
      else
        if prestascan_options.follow_redirection
          puts "Following redirection #{redirection}"
        else
          puts notice("The remote host tried to redirect to: #{redirection}")
          print '[?] Do you want follow the redirection ? [Y]es [N]o [A]bort, default: [N]'
        end
        if prestascan_options.follow_redirection || !prestascan_options.batch
          if prestascan_options.follow_redirection || (input = Readline.readline) =~ /^y/i
            prestascan_options.url = redirection
            ps_target = PsTarget.new(redirection, prestascan_options.to_h)
          else
            if input =~ /^a/i
              puts 'Scan aborted'
              exit(1)
            end
          end
        end
      end
    end

    # Remote website is prestashop?
    unless prestascan_options.force
      unless ps_target.prestashop?
        raise 'The remote website is up, but does not seem to be running Prestashop.'
      end
    end

    # Output runtime data
    start_time   = Time.now
    start_memory = get_memory_usage unless windows?
    puts info("URL: #{ps_target.url}")
    puts info("Started: #{start_time.asctime}")
    puts

    if ps_target.has_robots?
      puts info("robots.txt available under: '#{ps_target.robots_url}'")

      ps_target.parse_robots_txt.each do |dir|
        puts info("Interesting entry from robots.txt: #{dir}")
      end
    end

    ps_target.interesting_headers.each do |header|
      output = info('Interesting header: ')

      if header[1].class == Array
        header[1].each do |value|
          puts output + "#{header[0]}: #{value}"
        end
      else
        puts output + "#{header[0]}: #{header[1]}"
      end
    end

    # if wp_target.multisite?
    #   puts info('This site seems to be a multisite (http://codex.wordpress.org/Glossary#Multisite)')
    # end

    # if wp_target.has_must_use_plugins?
    #   puts info("This site has 'Must Use Plugins' (http://codex.wordpress.org/Must_Use_Plugins)")
    # end

    # if wp_target.registration_enabled?
    #   puts warning("Registration is enabled: #{wp_target.registration_url}")
    # end

    enum_options = {
      show_progression: true,
      exclude_content: prestascan_options.exclude_content_based
    }

    ps_version = ps_target.version

    if ps_version
      ps_version.output(prestascan_options.verbose)
    else
      puts
      puts notice('PrestaShop version can not be detected')
    end

    # TODO
    # It depends on version
    if ps_target.has_full_path_disclosure?
      puts warning("Full Path Disclosure (FPD) in '#{ps_target.full_path_disclosure_url}': #{ps_target.full_path_disclosure_data}")
    end

    ps_target.config_backup.each do |file_url|
      puts critical("A config backup file has been found in: '#{file_url}'")
    end

    if ps_target.upload_directory_listing_enabled?
      puts warning("Upload directory has directory listing enabled: #{ps_target.upload_dir_url}")
    end

    if ps_target.module_directory_listing_enabled?
      puts warning("Module directory has directory listing enabled: #{ps_target.modules_dir_url}")
    end

    if ps_target.theme_directory_listing_enabled?
      puts warning("Theme directory has directory listing enabled: #{ps_target.themes_dir_url}")
    end

    # if ps_theme = ps_target.theme
    #   puts
    #   # Theme version is handled in #to_s
    #   puts info("Prestashop theme in use: #{ps_theme}")
    #   ps_theme.output(prestascan_options.verbose)
    # end
  end
end

main()
exit($exit_code)

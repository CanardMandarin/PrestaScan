# encoding: UTF-8

require 'web_site'
# require 'wp_target/wp_readme'
# require 'wp_target/wp_registrable'
# require 'wp_target/wp_must_use_plugins'
# require 'wp_target/wp_login_protection'
# require 'wp_target/wp_custom_directories'
require 'ps_target/ps_full_path_disclosure'
require 'ps_target/ps_config_backup'

class PsTarget < WebSite
  # include WpTarget::WpReadme
  # include WpTarget::WpRegistrable
  # include WpTarget::WpMustUsePlugins
  # include WpTarget::WpLoginProtection
  # include WpTarget::WpCustomDirectories
  include PsTarget::PsFullPathDisclosure
  include PsTarget::PsConfigBackup

  attr_reader :verbose, :ps_version, :ps_theme

  def initialize(target_url, options = {})
    raise Exception.new('target_url can not be nil or empty') if target_url.nil? || target_url == ''
    super(target_url)

    @verbose        = options[:verbose]
    @wp_content_dir = options[:wp_content_dir]
    @wp_plugins_dir = options[:wp_plugins_dir]
    @multisite      = nil
    @ps_version     = nil
    @ps_theme     = nil

    @vhost = options[:vhost]

    Browser.instance.referer = url
    if @vhost
      Browser.instance.vhost = @vhost
    end

  end

  # check if the target website is
  # actually running wordpress.
  def prestashop?
    prestashop = false

    response = Browser.get_and_follow_location(@uri.to_s)

    fail "The target is responding with a 403, this might be due to a WAF or a plugin.\n" \
          'You should try to supply a valid user-agent via the --user-agent option or use the --random-agent option' if response.code == 403

    if response.headers.include?('Powered-By') && response.headers['Powered-By'] =~ /prestashop/i
      prestashop = true
      puts notice('Header Powered-By reveals prestashop usage.')
    end

    if response.headers.include?('Set-Cookie')
      cookies = response.headers['Set-Cookie']
      # Workaround
      # Sometimes there is more than one 'Set-Cookie'

      # TODO
      # Make it clean
      if ! cookies.respond_to?('each')
        cookies = [cookies]
      end
      cookies.each do |cookie|
        if cookie =~ /prestashop/i
          puts notice('Set-cookie reveals prestashop usage')
          prestashop = true
        end
      end
    end

    prestashop
  end

  def login_url
    url = @uri.merge('wp-login.php').to_s

    # Let's check if the login url is redirected (to https url for example)
    redirection = redirection(url)
    url = redirection if redirection

    url
  end

  # Valid HTTP return codes
  def self.valid_response_codes
    [200, 301, 302, 401, 403, 500, 400]
  end

  # @return [ PsTheme ]
  # :nocov:
  def theme
    @ps_theme = PsTheme.find(@uri)
    @ps_theme
  end
  # :nocov:

  # @return [ PsVersion ]
  # :nocov:
  def version
    @ps_version = PsVersion.find(@uri)
    @ps_version
  end
  # :nocov:

  # The version is not yet considered
  #
  # @param [ String ] name
  # @param [ String ] version
  #
  # @return [ Boolean ]
  def has_plugin?(name, version = nil)
    WpPlugin.new(
      @uri,
      name: name,
      version: version,
      wp_content_dir: wp_content_dir,
      wp_plugins_dir: wp_plugins_dir
    ).exists?
  end

  # @return [ String ]
  def upload_dir_url
    @uri.merge("upload/").to_s
  end

  # @return [ String ]
  def modules_dir_url
    @uri.merge("modules/").to_s
  end

  # @return [ String ]
  def themes_dir_url
    @uri.merge("themes/").to_s
  end

  # Script for replacing strings in wordpress databases
  # reveals database credentials after hitting submit
  # http://interconnectit.com/124/search-and-replace-for-wordpress-databases/
  #
  # @return [ String ]
  def search_replace_db_2_url
    @uri.merge('searchreplacedb2.php').to_s
  end

  # @return [ Boolean ]
  def search_replace_db_2_exists?
    resp = Browser.get(search_replace_db_2_url)
    resp.code == 200 && resp.body[%r{by interconnect}i]
  end

  def upload_directory_listing_enabled?
    directory_listing_enabled?(upload_dir_url)
  end

  def module_directory_listing_enabled?
    directory_listing_enabled?(modules_dir_url)
  end

  def theme_directory_listing_enabled?
    directory_listing_enabled?(themes_dir_url)
  end
end

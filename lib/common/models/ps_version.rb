
# encoding: UTF-8

require 'ps_version/findable'
require 'ps_version/output'

class PsVersion < PsItem
  extend  PsVersion::Findable
  include PsVersion::Output

  # The version number
  attr_accessor :number, :metadata
  alias_method :version, :number # Needed to have the right behaviour in Vulnerable#vulnerable_to?

  # @return [ Array ]
  def allowed_options; super << :number << :found_from end

  def identifier
    @identifier ||= number
  end

  # @param [ WpVersion ] other
  #
  # @return [ Boolean ]
  def ==(other)
    number == other.number
  end

  # @return [ Hash ] Metadata for specific WP version from WORDPRESSES_FILE
  def metadata(version)
    temp = Database.instance.get_version(version)
    metadata = {}
    if !temp.nil?
      metadata[:created_at] = temp['created_at']
    end
    metadata
  end
end

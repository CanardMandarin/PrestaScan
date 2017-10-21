# encoding: UTF-8

class Database

  @@instance = nil
  @@db = nil

  # @return [ Database ]
  def initialize()
    init_db(PS_DB_FILE)
    @@instance
  end

  def init_db(db)
    unless @@db
      @@db = SQLite3::Database.open "#{db}"
      @@db.results_as_hash = true
    end
    @@db

  end

  def list_versions
    @@db.execute "SELECT * FROM version"
  end

  def get_version(version)
    stm = @@db.prepare "SELECT * FROM version
                        WHERE number = '#{version.to_s}'
                        LIMIT 1"
    stm.execute.first
  end

  def list_top_path(passive = false, limit = 30)
    @@db.execute "SELECT value FROM (
                    SELECT value, md5_hash, count(p.id) FROM path p
                    LEFT JOIN fingerprint f ON f.id_path = p.id
                    GROUP BY p.value, f.md5_hash
                    ORDER BY value
                  )
                  GROUP BY value
                  ORDER BY count(md5_hash) DESC LIMIT #{limit}"
  end

  def version_by_hash(hash)
    stm = @@db.prepare "SELECT number FROM fingerprint f
                  LEFT JOIN version v ON f.id_version = v.id
                  WHERE f.md5_hash = '#{hash}'
                  GROUP BY f.id_version"
    stm.execute.map { |x| x['number'] }
  end

  def full_path_disclosure(version)
    stm = @@db.prepare "SELECT p.value FROM full_path_disclosure f
                  LEFT JOIN version v ON v.id = f.id_version
                  LEFT JOIN path p ON p.id = f.id_path
                  WHERE v.number = '#{version.to_s}'
                  LIMIT 1"
    stm.execute.first['value']
  end

  def config_backup_paths(version)
    stm = @@db.prepare "SELECT p.value FROM config_backup c
                  LEFT JOIN version v ON v.id = c.id_version
                  LEFT JOIN path p ON p.id = c.id_path
                  WHERE v.number = '#{version.to_s}'"
    stm.execute.map { |x| x['value'] }
  end


  private_class_method :new

  # @return [ Database ]
  def self.instance()
    unless @@instance
      @@instance = new()
    end
    @@instance
  end

  def self.reset
    @@instance = nil
  end

end

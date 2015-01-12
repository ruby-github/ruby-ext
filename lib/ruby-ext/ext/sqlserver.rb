class SqlServer
  attr_accessor :logger

  def initialize
    @conn = nil
  end

  def open ip, username = 'sa', password = 'sa'
    begin
      if @conn.nil?
        WIN32OLE.ole_initialize

        @conn = WIN32OLE.new 'ADODB.Connection'
        @conn.Provider = 'SQLOLEDB.1'
      end

      @conn.Open 'Data source=%s;User ID=%s;password=%s' % [ip, username, password]

      true
    rescue
      if @logger
        @logger.exception $!
      end

      false
    end
  end

  def database name
    begin
      @conn.DefaultDatabase = name

      true
    rescue
      if @logger
        @logger.exception $!
      end

      false
    end
  end

  def execute sql
    begin
      table = Table.new

      record_set = @conn.Execute sql

      if not record_set.State.zero?
        if not record_set.EOF
          data = record_set.GetRows

          if not data.empty?
            data.first.size.times do
              table.rows << []
            end

            data.each do |x|
              x.each_with_index do |val, i|
                table.rows[i] << val
              end
            end
          end
        end
      end

      table
    rescue
      if @logger
        @logger.exception $!
      end

      nil
    end
  end

  def insert_table name, table
    if table.head.empty?
      insert_into_sql = 'insert into %s' % name
    else
      insert_into_sql = 'insert into %s (%s)' % [name, table.head.join(', ')]
    end

    if execute('begin transaction').nil?
      return false
    end

    table.rows.each do |row|
      sql = '%s values (%s)' % [insert_into_sql, row.map { |x| format x }.join(', ')]

      if execute(sql).nil?
        execute 'rollback transaction'

        return false
      end
    end

    if execute('commit transaction').nil?
      return false
    end

    true
  end

  def close
    if not @conn.nil?
      begin
        @conn.Close

        true
      rescue
        if @logger
          @logger.exception $!
        end

        false
      end
    else
      true
    end
  end

  def format value
    case
    when value.is_a?(Numeric)
      value
    when value.is_a?(NilClass)
      'null'
    else
      if value.is_a? Time
        str = value.strftime '%Y-%m-%d %H:%M:%S'
      else
        str = value.to_s.gsub "'", "''"
      end

      '\'%s\'' % str
    end
  end
end
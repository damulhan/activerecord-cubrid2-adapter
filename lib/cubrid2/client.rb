module Cubrid2
  class Client
    attr_reader :query_options, :read_timeout, :conn

    def self.default_query_options
      @default_query_options ||= {
        auto_commit: true
      }
    end

    def initialize(opts = {})
      raise Cubrid2::Error, 'Options parameter must be a Hash' unless opts.is_a? Hash

      opts = Cubrid2::Util.key_hash_as_symbols(opts)
      @read_timeout = nil
      @query_options = self.class.default_query_options.dup
      @query_options.merge! opts

      %i[auto_commit].each do |key|
        next unless opts.key?(key)

        case key
        when :auto_commit
          send(:"#{key}=", !!opts[key]) # rubocop:disable Style/DoubleNegation
        else
          send(:"#{key}=", opts[key])
        end
      end

      flags = 0

      user     = opts[:username] || opts[:user]
      pass     = opts[:password] || opts[:pass]
      host     = opts[:host] || opts[:hostname]
      port     = opts[:port]
      database = opts[:database] || opts[:dbname] || opts[:db]

      # Correct the data types before passing these values down to the C level
      user = user.to_s unless user.nil?
      pass = pass.to_s unless pass.nil?
      host = host.to_s unless host.nil?
      port = port.to_i unless port.nil?
      database = database.to_s unless database.nil?

      @conn = Cubrid.connect database, host, port, user, pass
    end

    def query(sql, options = {})
      Thread.handle_interrupt(::Cubrid2::Util::TIMEOUT_ERROR_CLASS => :never) do
        _query(sql, @query_options.merge(options))
      end
    end

    def _query(sql, _options)
      @conn.query(sql)
    end

    def query_info
      info = query_info_string
      return {} unless info

      info_hash = {}
      info.split.each_slice(2) { |s| info_hash[s[0].downcase.delete(':').to_sym] = s[1].to_i }
      info_hash
    end

    def info
      self.class.info
    end

    def ping
      @conn.server_version != ''
    end

    def server_version
      @conn.server_version
    end

    def close
      @conn.close
    end

    def auto_commit
      @conn.auto_commit
    end

    def auto_commit=(flag)
      @conn.auto_commit = flag
    end
  end
end

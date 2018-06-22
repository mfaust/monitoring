
require 'mongo'

module ExternalClients

  module MongoDb

    class Instance

      def initialize(config)
#         @config = config

        #@name = name
        @port       = config.dig(:port)  || 27017
        @host       = config.dig(:host)  || 'localhost'

        # @fields_to_ignore = %w(host version process pid uptimeMillis localTime extra_info.note backgroundFlushing.last_finished repl.setName repl.hosts repl.arbiters repl.primary repl.me ok)
        @white_list = %w(uptime asserts connections network opcounters tcmalloc storageEngine metrics mem extra_info wiredTiger globalLock)
        # @prefix_callback = nil
        @replacements = { /locks\.\.\./ => 'locks.global.' }

        Mongo::Logger.logger.level = Logger::FATAL
      end

      def to_s
        "Mongodb::Instance   #{@host}:#{@port}, #{@prefix_callback.class}"
      end

      def get
  #      database_names
        @stats = to_hash

        # transform a hash of arrays into nested hash
        result = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
        @stats.each do |key, value|

          if( @white_list.partial_include?(key) )
            *nesting, leaf = key.split('.').map(&:to_sym)
            count = nesting.count
            if(count != 0)
              result.dig(*nesting)[leaf] = value
            else
              result[key] = value
            end
          end
        end

        result


        #with_prefix = Hash.new
        #@stats.each do |k,v|
        #  key = format_key k
        #  with_prefix[ [prefix, key].join('.')] = to_i(v)
        #end
        #with_prefix.reject { |k,v| ignored_fields.include? k }
      end

      def format_key(key)
        @replacements.inject(key) do |modified_key, kvp|
          modified_key.gsub(kvp[0], kvp[1])
        end
      end

      def prefix
        return @prefix_callback.call(@stats) unless @prefix_callback.nil?
        nil
      end

      def to_i(v)
        return v.to_i if v.respond_to?('to_i')
        case v
        when TrueClass
          1
        when FalseClass
          0
        else
          nil
        end
      end

      def ignored_fields
        @fields_to_ignore.map { |f| [prefix,f].join('.') }
      end

      def connection
        @connection ||= Mongo::Client.new([ "#{@host}:#{@port}" ] , connect_timeout: 5)
      end

      def database_names
        puts connection.database_names
        db = connection.use("test")
        puts db.command({'serverStatus' => 1})
        db.command({"dbstats" => 1}).documents[0].each do |key, value|
          puts "#{key}: #{value}"
        end
      end

      def stats
        db = connection.use("test")
        db.command({'serverStatus' => 1})
      end

      def to_hash
        s = stats

        if s.ok?
          @process = s.documents.first['process']
  #        pp s.documents.first.class
          p = json_descent([], s.documents.first) # .flatten
          return p.flatten.reduce( :merge )
        end

        return {}
      end

      def json_descent(pre, json)
        json.map do |k,v|
          # pp k.class
          # next if @fields_to_ignore.include?(k.downcase)

          key = pre + [k]
          if v.is_a? BSON::Document
            json_descent(key, v)
          else
            # pp key
            { key.join('.') => v }
          end
        end
      end
    end
  end

end

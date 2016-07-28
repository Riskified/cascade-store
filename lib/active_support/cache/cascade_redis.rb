require 'active_support/cache/cascade_base'
module ActiveSupport
  module Cache
    class CascadeRedis < CascadeBase
      attr_reader :local_store
      attr_reader :redis_store

      def initialize(options = nil, &blk)
        options ||= {}
        super(options)
        local_store_options =  options.delete(:local_store) || {}
        redis_store_options =  options.delete(:redis_store) || {}
        @local_store = ActiveSupport::Cache.lookup_store(*[:memory_store, local_store_options])
        @redis_store = ActiveSupport::Cache.lookup_store(*[:redis_store, redis_store_options])
      end

      def read_multi(*names)
        results = @local_store.read_multi(*names)
        missing_keys = names - results.keys
        if missing_keys.empty?
          results
        else
          redis_results = results.merge @redis_store.read_multi(*missing_keys)
          redis_results.each do |key, value|
            @local_store.write_entry(key, value)
          end
          results.merge redis_results
        end
      end

      protected

      def cascade(method, *args)
        @local_store.send(method, *args)
        @redis_store.send(method, *args)
      end

      def read_entry(key, options)
        entry = @local_store.send(:read_entry, key, options)
        if entry && entry.expired?
          @local_store.send(:delete_entry, key)
          entry = nil
        end
        if entry.nil?
          agent.record_metric('Custom/CascadeStore/local-MISS', 1)
          entry = @redis_store.send(:read_entry, key, options)
          if entry.present?
            agent.record_metric('Custom/CascadeStore/redis-HIT', 1)
            @local_store.send(:write_entry, key, entry, options)
          else
            agent.record_metric('Custom/CascadeStore/redis-MISS', 1)
          end
        else
          agent.record_metric('Custom/CascadeStore/local-HIT', 1)
        end
        entry
      end

      def write_entry(key, entry, options)
        cascade(:write_entry, key, entry, options)
        true
      end

      def delete_entry(key, options)
        cascade_delete(:delete_entry, key, options)
        true
      end
    end
  end
end
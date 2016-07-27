require 'naught'

module ActiveSupport
  module Cache
    class CascadeRedis < Store
      attr_reader :local_store
      attr_reader :redis_store
      def initialize(options = nil, &blk)
        options ||= {}
        super(options)
        raise Exception 'race_condition_ttl options is currently not supported in cascade store' if options.key? :race_condition_ttl
        local_store_options =  options.delete(:local_store) || {}
        redis_store_options =  options.delete(:redis_store) || {}
        @enable_custom_metrics = options.delete(:fire_custom_metrics)
        @local_store = ActiveSupport::Cache.lookup_store(*[:memory_store, local_store_options])
        @redis_store = ActiveSupport::Cache.lookup_store(*[:redis_store, redis_store_options])
      end

      def increment(name, amount = 1, options = nil)
        nums = cascade(:increment, name, amount, options)
        nums.detect { |n| !n.nil? }
      end

      def decrement(name, amount = 1, options = nil)
        nums = cascade(:decrement, name, amount, options)
        nums.detect { |n| !n.nil? }
      end

      def delete_matched(matcher, options = nil)
        cascade(:delete_matched, matcher, options)
        nil
      end

      def read_multi(*names)
        results = @local_store.read_multi(*names)
        missing_keys = names - results.keys
        missing_keys.empty? ? results : results.merge @redis_store.read_multi(*missing_keys)
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

      private

      def expired?(entry)
        entry.respond_to?(:expired?) ? entry.expired? : false
      end

      def agent
        @agent ||= if (defined? ::NewRelic::Agent) && @enable_custom_metrics
                     ::NewRelic::Agent
                   else
                     Naught.build.new
                   end
      end
    end
  end
end
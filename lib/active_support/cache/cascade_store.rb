require 'naught'

module ActiveSupport
  module Cache
    # Most of the code is taken from https://github.com/jch/activesupport-cascadestore with
    # some adjustments to fit our use case
    #
    # A thread-safe cache store implementation that cascades
    # operations to a list of other cache stores.
    #
    # Cache operation behavior:
    #
    # Read: returns first cache hit from :stores and backfills previous stores in the chain, nil if none found
    #
    # Write/Delete: write/delete through to each cache store in
    # :stores
    #
    # Increment/Decrement: increment/decrement each store, returning
    # the new number if any stores was successfully
    # incremented/decremented, nil otherwise
    class CascadeStore < Store
      attr_reader :stores

      # Initialize a CascadeStore with +options[:stores]+, an array of
      # options to initialize other ActiveSupport::Cache::Store
      # implementations.  If options is a symbol, top level
      # CascadeStore options are used for cascaded stores. If options
      # is an array, they are passed on unchanged.
      def initialize(options = nil, &blk)
        options ||= {}
        super(options)
        raise Exception 'race_condition_ttl options is currently not supported in cascade store' if options.key? :race_condition_ttl
        store_options = options.delete(:stores) || []
        @agent = if (defined? ::NewRelic::Agent) && (options.delete(:fire_custom_metrics) == true)
                   ::NewRelic::Agent
                 else
                   Naught.build.new
                 end
        @read_multi_store = nil
        @stores = store_options.map do |o|
          o = o.is_a?(Symbol) ? [o, options] : o
          store = ActiveSupport::Cache.lookup_store(*o)
          @read_multi_store = store if store.method(:read_multi).owner == store.class && @read_multi_store.nil?
          store
        end
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
        if @read_multi_store.present?
          @read_multi_store.read_multi(*names)
        else
          super *names
        end
      end

      protected
      def cascade(method, *args)
        @stores.map do |store|
          store.send(method, *args) rescue nil
        end
      end

      def read_entry(key, options)
        entry = nil
        empty_stores = []
        @stores.detect do |store|
          entry = store.send(:read_entry, key, options)
          if entry.nil? || entry.expired?
            @agent.increment_metric("Custom/CascadeStore/#{store.class}-MISS")
            empty_stores << store
            entry = nil
          else
            @agent.increment_metric("Custom/CascadeStore/#{store.class}-HIT")
          end
          store.send(:delete_entry, key, options) if entry.present? && entry.expired?
          entry
        end
        unless entry.nil? || empty_stores.empty?
          empty_stores.each do |store|
            store.send(:write_entry, key, entry, options)
          end
        end
        entry
      end

      def write_entry(key, entry, options)
        cascade(:write_entry, key, entry, options)
        true
      end

      def delete_entry(key, options)
        cascade(:delete_entry, key, options)
        true
      end
    end
  end
end
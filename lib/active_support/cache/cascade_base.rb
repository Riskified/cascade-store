require 'naught'

module ActiveSupport
  module Cache
    class CascadeBase < Store
      def initialize(options = nil, &blk)
        options ||= {}
        super(options)
        raise Exception.new 'race_condition_ttl options is currently not supported in cascade store' if options.key? :race_condition_ttl
        @enable_custom_metrics = options.delete(:fire_custom_metrics)
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

      def clear(options = nil)
        cascade(:clear, options)
      end

      protected

      def cascade(method, *args)
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
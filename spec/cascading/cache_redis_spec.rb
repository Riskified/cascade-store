require 'active_support/cache'
require 'active_support/cache/memory_store'
require 'spec_helper'

RSpec.describe 'CascadeRedis' do

  @cache = ActiveSupport::Cache.lookup_store(:cascade_redis, expires_in: 60.seconds)
  @store1 = @cache.local_store
  @store2 = @cache.redis_store
  include_examples 'a cascading cache', @cache, @store1, @store2
end

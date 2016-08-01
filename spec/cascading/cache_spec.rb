require 'spec_helper'
require 'active_support/cache'
require 'active_support/cache/memory_store'

RSpec.describe 'CascadeCache' do
    @cache = ActiveSupport::Cache.lookup_store(:cascade_store, {
        :expires_in => 60,
        :stores => [
            :memory_store,
            [:memory_store, :expires_in => 60]
        ]
    })
  include_examples 'a cascading cache', @cache, @cache.stores.first, @cache.stores.last
end

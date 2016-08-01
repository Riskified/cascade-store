$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
Dir['./spec/support/**/*.rb'].sort.each { |f| require f}
require 'fakeredis/rspec'
require 'active_support'
require 'active_support/cache/cascade_base'
require 'active_support/cache/cascade_store'
require 'active_support/cache/cascade_redis'

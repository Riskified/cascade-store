require 'active_support/cache'
require 'active_support/cache/memory_store'
require 'spec_helper'

RSpec.describe 'CascadeCache' do

  before(:each) do
    @cache = ActiveSupport::Cache.lookup_store(:cascade_store, {
        :expires_in => 60,
        :stores => [
            :memory_store,
            [:memory_store, :expires_in => 60]
        ]
    })
    @store1 = @cache.stores[0]
    @store2 = @cache.stores[1]
  end

# Tests the base functionality that should be identical across all cache stores.
  it 'test_should_read_and_write_strings' do
    expect(@cache.write('foo', 'bar')).to be true
    expect('bar').to eq @cache.read('foo')
  end

  it 'test_should_overwrite' do
    @cache.write('foo', 'bar')
    @cache.write('foo', 'baz')
    expect('baz').to eq @cache.read('foo')
  end

  it 'test_fetch_without_cache_miss' do
    @cache.write('foo', 'bar')
    expect(@cache).not_to receive(:write)
    expect('bar').to eq @cache.fetch('foo') { 'baz' }
  end

  it 'test_fetch_with_cache_miss' do
    expect(@cache).to receive(:write).with('foo', 'baz', @cache.options)
    expect('baz').to eq @cache.fetch('foo') { 'baz' }
  end

  it 'test_fetch_with_forced_cache_miss' do
    @cache.write('foo', 'bar')
    expect(@cache).not_to receive(:read)
    expect(@cache).to receive(:write).with('foo', 'bar', @cache.options.merge(:force => true))
    @cache.fetch('foo', :force => true) { 'bar' }
  end

  it 'test_fetch_with_cached_nil' do
    @cache.write('foo', nil)
    expect(@cache).to_not receive(:write)
    expect(@cache.fetch('foo') { 'baz' }).to be_nil
  end

  it 'test_should_read_and_write_hash' do
    expect(@cache.write('foo', {:a => "b"})).to be true
    expect({:a => 'b'}).to eq @cache.read('foo')
  end

  it 'test_should_read_and_write_integer' do
    expect(@cache.write('foo', 1)).to be true
    expect(1).to eq @cache.read('foo')
  end

  it 'test_should_read_and_write_nil' do
    expect(@cache.write('foo', nil)).to be true
    expect(@cache.read('foo')).to be nil
  end

  it 'test_should_read_and_write_false' do
    expect(@cache.write('foo', false)).to be true
    expect(@cache.read('foo')).to be false
  end

  it 'test_read_multi' do
    @cache.write('foo', 'bar')
    @cache.write('fu', 'baz')
    @cache.write('fud', 'biz')
    expect({'foo' => 'bar', 'fu' => 'baz'}).to eq @cache.read_multi('foo', 'fu')
  end

  it 'test_read_multi_with_expires' do
    @cache.write('foo', 'bar', :expires_in => 0.001)
    @cache.write('fu', 'baz')
    @cache.write('fud', 'biz')
    sleep(0.002)
    expect({"fu" => "baz"}).to eq @cache.read_multi('foo', 'fu')
  end

  it 'test_read_and_write_compressed_nil' do
    @cache.write('foo', nil, :compress => true)
    expect(@cache.read('foo')).to be nil
  end

  it 'test_array_as_cache_key' do
    @cache.write([:fu, "foo"], "bar")
    expect('bar').to eq @cache.read('fu/foo')
  end

  it 'test_hash_as_cache_key' do
    @cache.write({foo: 1, fu: 2}, 'bar')
    expect('bar').to eq @cache.read('foo=1/fu=2')
  end

  it 'test_keys_are_case_sensitive' do
    @cache.write('foo', 'bar')
    expect(@cache.read('FOO')).to be nil
  end

  it 'test_exist' do
    @cache.write('foo', 'bar')
    expect(@cache.exist?('foo')).to be true
    expect(@cache.exist?('bar')).to be false
  end

  it 'test_nil_exist' do
    @cache.write('foo', nil)
    expect(@cache.exist?('foo')).to be true
  end

  it 'test_delete' do
    @cache.write('foo', 'bar')
    expect(@cache.exist?('foo')).to be true
    expect(@cache.delete('foo')).to be true
    expect(@cache.exist?('foo')).to be false
  end

  it 'test_original_store_objects_should_not_be_immutable' do
    bar = 'bar'
    @cache.write('foo', bar)
    expect{ bar.gsub!(/.*/, 'baz') }.not_to raise_error
  end

  it 'test_expires_in' do
    time = Time.local(2008, 4, 24)
    allow(Time).to receive(:now).and_return(time)

    @cache.write('foo', 'bar')
    expect('bar').to eq @cache.read('foo')

    allow(Time).to receive(:now).and_return(time + 30)
    expect('bar').to eq @cache.read('foo')

    allow(Time).to receive(:now).and_return(time + 61)
    expect(@cache.read('foo')).to be nil
  end

  it 'test race condition ttl is not supported' do
    expect{ActiveSupport::Cache.lookup_store(:cascade_store, {
        :expires_in => 60,
        :race_condition_ttl => 10,
        :stores => [
            :memory_store,
            [:memory_store, :expires_in => 60]
        ]
    })}.to raise_exception 'race_condition_ttl options is currently not supported in cascade store'
  end

  xit 'test_race_condition_protection' do
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    allow(Time).to receive(:now).and_return(time + 61)
    result = @cache.fetch('foo', :race_condition_ttl => 10) do
      expect('bar').to eq @cache.read('foo')
      'baz'
    end
    expect('baz').to eq result
  end

  xit 'test_race_condition_protection_is_limited' do
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    allow(Time).to receive(:now).and_return(time + 71)
    result = @cache.fetch('foo', :race_condition_ttl => 10) do
      expect(@cache.read('foo')).to be nil
      'baz'
    end
    expect(result).to eq 'baz'
  end

  xit 'test_race_condition_protection_is_safe' do
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    allow(Time).to receive(:now).and_return(time + 61)
    begin
      @cache.fetch('foo', :race_condition_ttl => 10) do
        expect(@cache.read('foo')).to eq 'bar'
        raise ArgumentError.new
      end
    rescue ArgumentError
    end
    expect(@cache.read('foo')).to eq 'bar'
    allow(Time).to receive(:now).and_return(time + 71)
    expect(@cache.read('foo')).to be nil
  end

  it 'test_crazy_key_characters' do
    crazy_key = "#/:*(<+=> )&$%@?;'\"\'`~-"
    expect(@cache.write(crazy_key, "1", :raw => true)).to be true
    expect(@cache.read(crazy_key)).to eq '1'
    expect(@cache.fetch(crazy_key)).to eq '1'
    expect(@cache.delete(crazy_key)).to be true
    expect(@cache.fetch(crazy_key, :raw => true) { '2' }).to eq '2'
    expect(@cache.increment(crazy_key)).to eq 3
    expect(@cache.decrement(crazy_key)).to eq 2
  end

  it 'test_really_long_keys' do
    key = ""
    900.times{key << "x"}
    expect(@cache.write(key, 'bar')).to be true
    expect(@cache.read(key)).to eq 'bar'
    expect(@cache.fetch(key)).to eq 'bar'
    expect(@cache.read("#{key}x")).to be nil
    expect({key => "bar"}).to eq @cache.read_multi(key)
    expect(@cache.delete(key)).to be true
  end

  it 'test_delete_matched' do
    @cache.write("foo", "bar")
    @cache.write("fu", "baz")
    @cache.write("foo/bar", "baz")
    @cache.write("fu/baz", "bar")
    @cache.delete_matched(/oo/)
    expect(@cache.exist?("foo")).to be false
    expect(@cache.exist?("fu")).to be true
    expect(@cache.exist?("foo/bar")).to be false
    expect(@cache.exist?("fu/baz")).to be true
  end

  it 'test_increment' do
    @cache.write('foo', 1, :raw => true)
    expect(@cache.read('foo').to_i).to eq 1
    expect(@cache.increment('foo')).to eq 2
    expect(@cache.read('foo').to_i).to eq 2
    expect(@cache.increment('foo')).to eq 3
    expect(@cache.read('foo').to_i).to eq 3
  end

  it 'test_decrement' do
    @cache.write('foo', 3, :raw => true)
    expect(@cache.read('foo').to_i).to eq 3
    expect(@cache.decrement('foo')).to eq 2
    expect(@cache.read('foo').to_i).to eq 2
    expect(@cache.decrement('foo')).to eq 1
    expect(@cache.read('foo').to_i).to eq 1
  end

  it 'test_default_child_store_options' do
    expect(@store1.options[:expires_in]).to eq 60
  end

  it 'test_empty_store_cache_miss' do
    cache = ActiveSupport::Cache.lookup_store(:cascade_store)
    expect(cache.write('foo', 'bar')).to be true
    expect(cache.fetch('foo')).to be nil
  end

  it 'test_cascade_write' do
    @cache.write('foo', 'bar')
    expect(@store1.read('foo')).to eq 'bar'
    expect(@store2.read('foo')).to eq'bar'
  end

  it 'test_cascade_read_returns_first_hit' do
    @store1.write('foo', 'bar')
    expect(@store2).not_to receive(:read_entry)
    expect(@cache.read('foo')).to eq'bar'
  end

  it 'test_cascade_read_fallback' do
    @store1.delete('foo')
    @store2.write('foo', 'bar')
    expect(@cache.read('foo')).to eq 'bar'
  end

  it 'test_cascade_read_not_found' do
    expect(@cache.read('foo')).to be nil
  end

  it 'test_cascade_delete' do
    @store1.write('foo', 'bar')
    @store2.write('foo', 'bar')
    @cache.delete('foo')
    expect(@store1.read('foo')).to be nil
    expect(@store2.read('foo')).to be nil
  end

  it 'test_cascade_increment_partial_returns_num' do
    @store2.write('foo', 0)
    expect(@cache.increment('foo', 1)).to eq 1
    expect(@cache.read('foo')).to eq 1
  end

  it 'test_cascade_decrement_partial_returns_num' do
    @store2.write('foo', 1)
    expect(@cache.decrement('foo', 1)).to eq 0
    expect(@cache.read('foo')).to eq 0
  end
end

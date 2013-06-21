# encoding: UTF-8

require 'vines/services'
require 'minitest/autorun'

describe Vines::Services::Storage::CouchDB do
  def teardown
    FileUtils.rm(Dir.glob('localhost-*.db'))
  end

  def test_init
    assert_raises(RuntimeError) { Vines::Services::Storage::CouchDB.new {} }
    assert_raises(RuntimeError) { Vines::Services::Storage::CouchDB.new { host 'localhost' } }
    assert_raises(RuntimeError) do
      Vines::Services::Storage::CouchDB.new do
        host 'localhost'
        port '5984'
        database 'test'
        index_dir "./bogus/#{rand(1_000_000)}"
      end
    end
    # shouldn't raise an error
    Vines::Services::Storage::CouchDB.new do
      host 'localhost'
      port '5984'
      database 'test'
      index_dir '.'
    end
  end
end

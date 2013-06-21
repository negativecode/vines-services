# encoding: UTF-8

require 'vines/services'
require 'minitest/autorun'

describe Vines::Services::Config do
  def teardown
    FileUtils.rm(Dir.glob('localhost-*.db'))
    %w[data uploads].each do |dir|
      FileUtils.remove_dir(dir) if File.exist?(dir)
    end
  end

  def test_missing_host_raises
    assert_raises(RuntimeError) do
      Vines::Services::Config.new do
        # missing domain
      end
    end
  end

  def test_multiple_domains_raises
    assert_raises(RuntimeError) do
      Vines::Services::Config.new do
        host 'vines.wonderland.lit', 'vines.wonderland.lit' do
          upstream 'localhost', 5347, 'secr3t'
          storage 'couchdb' do
            host 'localhost'
            port 5984
            database 'wonderland_lit'
            tls false
            username ''
            password ''
            index_dir '.'
          end
        end
      end
    end
  end

  def test_configure
    config = Vines::Services::Config.configure do
      host 'vines.wonderland.lit' do
        upstream 'localhost', 5347, 'secr3t'
        storage 'couchdb' do
          host 'localhost'
          port 5984
          database 'wonderland_lit'
          tls false
          username ''
          password ''
          index_dir '.'
        end
      end
    end
    refute_nil config
    assert_same config, Vines::Services::Config.instance
  end

  def test_default_upload_directory
    config = Vines::Services::Config.configure do
      host 'vines.wonderland.lit' do
        upstream 'localhost', 5347, 'secr3t'
        storage 'couchdb' do
          host 'localhost'
          port 5984
          database 'wonderland_lit'
          tls false
          username ''
          password ''
          index_dir '.'
        end
      end
    end
    assert File.exist?('data/upload')
  end

  def test_custom_upload_directory
    config = Vines::Services::Config.configure do
      host 'vines.wonderland.lit' do
        upstream 'localhost', 5347, 'secr3t'
        uploads 'uploads'
        storage 'couchdb' do
          host 'localhost'
          port 5984
          database 'wonderland_lit'
          tls false
          username ''
          password ''
          index_dir '.'
        end
      end
    end
    assert File.exist?('uploads')
  end

  def test_missing_upstream_raises
    assert_raises(RuntimeError) do
      Vines::Services::Config.new do
        host 'vines.wonderland.lit' do
          storage 'couchdb' do
            host 'localhost'
            port 5984
            database 'wonderland_lit'
            tls false
            username ''
            password ''
            index_dir '.'
          end
        end
      end
    end
  end

  def test_invalid_upstream_raises
    assert_raises(RuntimeError) do
      Vines::Services::Config.new do
        host 'vines.wonderland.lit' do
          upstream 'localhost', 5347, nil
          storage 'couchdb' do
            host 'localhost'
            port 5984
            database 'wonderland_lit'
            tls false
            username ''
            password ''
            index_dir '.'
          end
        end
      end
    end
  end

  def test_missing_storage_raises
    assert_raises(RuntimeError) do
      Vines::Services::Config.new do
        host 'vines.wonderland.lit' do
          upstream 'localhost', 5347, 'secr3t'
        end
      end
    end
  end

  def test_duplicate_storage_raises
    assert_raises(RuntimeError) do
      Vines::Services::Config.new do
        host 'vines.wonderland.lit' do
          upstream 'localhost', 5347, 'secr3t'
          storage 'couchdb' do
            host 'localhost'
            port 5984
            database 'wonderland_lit'
            tls false
            username ''
            password ''
            index_dir '.'
          end
          storage 'couchdb' do
            host 'localhost'
            port 5984
            database 'wonderland_lit'
            tls false
            username ''
            password ''
            index_dir '.'
          end
        end
      end
    end
  end

  def test_multiple_domains
    config = Vines::Services::Config.new do
      host 'vines.wonderland.lit' do
        upstream 'localhost', 5347, 'secr3t'
        storage 'couchdb' do
          host 'localhost'
          port 5984
          database 'wonderland_lit'
          tls false
          username ''
          password ''
          index_dir '.'
        end
      end
      host 'vines.verona.lit' do
        upstream 'localhost', 5347, 'secr3t'
        storage 'couchdb' do
          host 'localhost'
          port 5984
          database 'verona_lit'
          tls false
          username ''
          password ''
          index_dir '.'
        end
      end
    end
    assert_equal 2, config.vhosts.size
    assert_equal 'vines.wonderland.lit', config.vhosts['vines.wonderland.lit'].name
    assert_equal 'vines.verona.lit', config.vhosts['vines.verona.lit'].name
  end

  def test_invalid_log_level
    assert_raises(RuntimeError) do
      config = Vines::Services::Config.new do
        log 'bogus'
        host 'vines.wonderland.lit' do
          upstream 'localhost', 5347, 'secr3t'
          storage 'couchdb' do
            host 'localhost'
            port 5984
            database 'wonderland_lit'
            tls false
            username ''
            password ''
            index_dir '.'
          end
        end
      end
    end
  end

  def test_valid_log_level
    config = Vines::Services::Config.new do
      log :error
      host 'vines.wonderland.lit' do
        upstream 'localhost', 5347, 'secr3t'
        storage 'couchdb' do
          host 'localhost'
          port 5984
          database 'wonderland_lit'
          tls false
          username ''
          password ''
          index_dir '.'
        end
      end
    end
    assert_equal Logger::ERROR, Class.new.extend(Vines::Log).log.level
  end
end

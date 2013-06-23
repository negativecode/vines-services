require 'rake'
require 'rake/clean'
require 'rake/testtask'
require './lib/vines/services/version'

CLOBBER.include('pkg', 'public/assets')

directory 'pkg'

desc 'Build distributable packages'
task :build => [:pkg, :assets] do
  system 'gem build vines-services.gemspec && mv vines-*.gem pkg/'
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

desc 'Compile web assets'
task :assets do
  require 'sprockets'
  require 'vines/web'

  env = Sprockets::Environment.new
  env.cache = Sprockets::Cache::FileStore.new(Dir.tmpdir)
  env.append_path 'app/assets/javascripts'
  env.append_path 'app/assets/stylesheets'
  Vines::Web.paths.each {|path| env.append_path path }
  env.js_compressor = :uglifier

  assets = %w[application.js application.css]
  assets.each do |asset|
    env[asset].write_to "public/assets/#{asset}"
  end
end

task :default => [:clobber, :test, :build]

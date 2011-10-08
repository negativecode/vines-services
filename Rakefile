require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rubygems/package_task'
require 'nokogiri'
require_relative 'lib/vines/services/version'

CLOBBER.include('pkg', 'web/javascripts', 'web/stylesheets/app.css')

spec = Gem::Specification.new do |s|
  s.name    = "vines-services"
  s.version = Vines::Services::VERSION

  s.summary     = "An XMPP component that broadcasts shell commands to many agents."
  s.description = "Vines Services are dynamically updated groups of systems based
on criteria like hostname, installed software, operating system, etc. Send a
command to the service and it runs on every system in the group. Services, files
and permissions are managed via the bundled web application."

  s.authors      = ["David Graham"]
  s.email        = %w[david@negativecode.com]
  s.homepage     = "http://www.getvines.com"

  s.test_files   = FileList["test/**/*"]
  s.executables  = %w[vines-services]
  s.require_path = "lib"

  s.add_dependency "bcrypt-ruby", "~> 3.0.1"
  s.add_dependency "blather", "~> 0.5.7"
  s.add_dependency "citrus", "~> 2.4.0"
  s.add_dependency "couchrest_model", "~> 1.1.2"
  s.add_dependency "em-http-request", "~> 0.3.0"
  s.add_dependency "sqlite3", "~> 1.3.4"
  s.add_dependency "vines", "~> 0.3"

  s.add_development_dependency "minitest"
  s.add_development_dependency "rake"

  s.required_ruby_version = '>= 1.9.2'
end

# Set gem file list after CoffeeScripts have been compiled, so web/javascripts/
# is included in the gem.
task :gemprep do
  spec.files = FileList['[A-Z]*', '{bin,lib,conf,web}/**/*']
  Gem::PackageTask.new(spec).define
  Rake::Task['gem'].invoke
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

# Return an array of local, non-library, js includes.
def scripts(doc)
  scripts = []
  doc.css('script').each do |node|
    file = node['src'].split('/').last()
    if node['src'].start_with?('javascripts/')
      scripts << file
    end
  end
  scripts
end

# Replace script tags with combined and minimized files.
def rewrite_js(doc)
  doc.css('script').each {|node| node.remove }
  doc.css('head').each do |node|
    %w[/lib/javascripts/base.js javascripts/app.js].each do |src|
      script = doc.create_element('script',
        'type' => 'text/javascript',
        'src' => src)
      node.add_child(script)
      node.add_child(doc.create_text_node("\n"))
    end
  end
end

def stylesheets(doc)
  sheets = []
  doc.css('link[rel="stylesheet"]').each do |node|
    file = node['href'].split('/').last()
    if node['href'].start_with?('stylesheets/')
      sheets << file
    end
  end
  sheets
end

def rewrite_css(doc)
  doc.css('link[rel="stylesheet"]').each {|node| node.remove }
  doc.css('head').each do |node|
    %w[/lib/stylesheets/base.css /lib/stylesheets/login.css stylesheets/app.css].each do |file|
      link = doc.create_element('link',
        'rel' => 'stylesheet',
        'href' => file)
      node.add_child(link)
      node.add_child(doc.create_text_node("\n"))
    end
  end
end

task :compile do
  index = 'web/index.html'
  doc = Nokogiri::HTML(File.read(index))
  scripts, sheets = scripts(doc), stylesheets(doc)

  rewrite_js(doc)
  rewrite_css(doc)

  # save index.html before rewriting
  FileUtils.cp(index, '/tmp/index.html')
  File.open(index, 'w') {|f| f.write(doc.to_xml(:indent => 2)) }

  js_files = scripts.map {|f| "web/javascripts/#{f}"}.join(' ')
  css_files = sheets.map {|f| "web/stylesheets/#{f}"}.join(' ')

  sh %{coffee -c -b -o web/javascripts web/coffeescripts/*.coffee}
  sh %{cat #{js_files} | uglifyjs -nc > web/javascripts/app.js}
  sh %{cat #{css_files} > web/stylesheets/app.css}
end

task :cleanup do
  # move index.html back into place after gem packaging
  FileUtils.cp('/tmp/index.html', 'web/index.html')
  File.delete('/tmp/index.html')
end

task :default => [:clobber, :test, :compile, :gemprep, :cleanup]

require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'nokogiri'
require './lib/vines/services/version'

CLOBBER.include('pkg', 'web/javascripts', 'web/stylesheets/app.css')

directory 'pkg'

desc 'Build distributable packages'
task :build => [:pkg] do
  system 'gem build vines-services.gemspec && mv vines-*.gem pkg/'
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

task :default => [:clobber, :test, :compile, :build, :cleanup]

require 'sprockets'
require 'vines/web'

use Rack::Static, urls: ['/images'], root: 'public', index: 'index.html'

map '/assets' do
  env = Sprockets::Environment.new
  env.append_path 'app/assets/javascripts'
  env.append_path 'app/assets/stylesheets'
  Vines::Web.paths.each {|path| env.append_path path }
  run env
end

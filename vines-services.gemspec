require './lib/vines/services/version'

Gem::Specification.new do |s|
  s.name    = "vines-services"
  s.version = Vines::Services::VERSION

  s.summary     = %q[An XMPP component that broadcasts shell commands to many agents.]
  s.description = %q[Vines Services are dynamically updated groups of systems based
on criteria like hostname, installed software, operating system, etc. Send a
command to the service and it runs on every system in the group. Services, files
and permissions are managed via the bundled web application.]

  s.authors      = ['David Graham']
  s.email        = %w[david@negativecode.com]
  s.homepage     = 'http://www.getvines.org'
  s.license      = 'MIT'

  s.files        = Dir['[A-Z]*', 'vines-services.gemspec', '{bin,lib,conf}/**/*'] - ['Gemfile.lock']
  s.test_files   = Dir['test/**/*']

  s.executables  = %w[vines-services]
  s.require_path = 'lib'

  s.add_dependency 'bcrypt-ruby', '~> 3.0.1'
  s.add_dependency 'blather', '~> 0.8.5'
  s.add_dependency 'citrus', '~> 2.4.0'
  s.add_dependency 'couchrest_model', '~> 1.1.2'
  s.add_dependency 'em-http-request', '~> 1.0.3'
  s.add_dependency 'sqlite3', '~> 1.3.7'
  s.add_dependency 'vines', '>= 0.4.6'

  s.add_development_dependency 'minitest', '~> 5.0.5'
  s.add_development_dependency 'rake', '~> 10.1.0'

  s.required_ruby_version = '>= 1.9.3'
end

$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name = 'git-review'
  s.version = '2.0.0.beta.1'
  s.date = Time.now.strftime('%F')
  s.summary = 'Facilitates GitHub code reviews'
  s.homepage = 'http://github.com/b4mboo/git-review'
  s.email = 'bamberger.dominik@gmail.com'
  s.authors = ['Dominik Bamberger']

  s.files = %w( LICENSE )
  s.files += Dir.glob('lib/**/*')
  s.files += Dir.glob('bin/**/*')

  s.executables = %w( git-review )
  s.description = 'Manage review workflow for projects hosted on GitHub (using pull requests).'

  s.add_runtime_dependency 'launchy'
  s.add_runtime_dependency 'yajl-ruby'
  s.add_runtime_dependency 'hashie'
  s.add_runtime_dependency 'faraday'
  s.add_runtime_dependency 'faraday_middleware'
  s.add_runtime_dependency 'oauth'
  s.add_runtime_dependency 'gli', '~> 2.8.0'
  s.add_runtime_dependency 'octokit', '~> 2.7.2'
  s.add_development_dependency 'rspec', '>= 2.13.0'
  s.add_development_dependency 'guard', '>= 2.0.3'
  s.add_development_dependency 'guard-rspec', '>= 3.1.0'
end

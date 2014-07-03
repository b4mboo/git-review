$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name = 'git-review'
  s.version = open('VERSION').read().strip
  s.date = Time.now.strftime('%F')

  s.summary = 'Facilitates GitHub code reviews'
  s.description = 'Manage review workflow for projects hosted on GitHub.'

  s.homepage = 'http://github.com/b4mboo/git-review'
  s.email = 'bamberger.dominik@gmail.com'
  s.authors = ['Dominik Bamberger']

  s.license = 'MIT'
  s.files = %w( LICENSE )

  s.files += Dir.glob('lib/**/*')
  s.files += Dir.glob('bin/**/*')
  s.executables = %w( git-review )

  s.add_runtime_dependency 'launchy'
  s.add_runtime_dependency 'yajl-ruby'
  s.add_runtime_dependency 'hashie'
  s.add_runtime_dependency 'gli', '~> 2.8.0'
  s.add_runtime_dependency 'octokit', '~> 2.7.2'
end

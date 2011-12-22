$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name     = "git-review"
  s.version  = "0.8.5"
  s.date     = Time.now.strftime('%F')
  s.summary  = "facilitates GitHub code reviews"
  s.homepage = "http://github.com/b4mboo/git-review"
  s.email    = "bamberger.dominik@gmail.com"
  s.authors  = ["Dominik Bamberger, Cristian Messel"]

  s.files    = %w( LICENSE )
  s.files    += Dir.glob("lib/**/*")
  s.files    += Dir.glob("bin/**/*")

  s.executables = %w( git-review )
  s.description = "Manage review workflow for projects hosted on GitHub (using pull requests)."

  s.add_runtime_dependency 'launchy'
  s.add_runtime_dependency 'octokit'
  s.add_runtime_dependency 'yajl-ruby'
end

$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name     = "git-review"
  s.version  = "0.4.1"
  s.date     = Time.now.strftime('%Y-%m-%d')
  s.summary  = "facilitates github code reviews"
  s.homepage = "http://github.com/b4mboo/git-review"
  s.email    = "bamberger.dominik@gmail.com"
  s.authors  = ["Cristian Messel, Dominik Bamberger"]

  s.files    = %w( LICENSE )
  s.files    += Dir.glob("lib/**/*")
  s.files    += Dir.glob("bin/**/*")

  s.executables = %w( git-review )
  s.description = "git-review facilitates github code reviews."

  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'launchy'
  s.add_runtime_dependency 'octokit', "= 0.5.1"
end

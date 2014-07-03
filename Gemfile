source 'http://rubygems.org'
gemspec

group :debug do
  gem 'byebug' if RUBY_VERSION =~ /^2/
  gem 'ruby-debug' if RUBY_VERSION =~ /^1.9/
end

group :test do
  gem 'rake'
  gem 'rspec', '= 2.14.1'
  gem 'guard', '>= 2.0.3'
  gem 'guard-rspec', '>= 3.1.0'
end

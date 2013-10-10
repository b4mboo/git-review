source 'http://rubygems.org'
gemspec

group :debug do
  gem 'byebug' if RUBY_VERSION =~ /^2/
  gem 'ruby-debug' if RUBY_VERSION =~ /^1.9/
end

group :test do
  gem 'rake'
end

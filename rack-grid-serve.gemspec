require File.join(File.dirname(__FILE__), 'lib/rack/grid_serve')

Gem::Specification.new do |s| 

  s.authors = ["Mickael Riga"]
  s.email = ["mig@mypeplum.com"]
  s.homepage = "https://github.com/mig-hub/rack-grid-serve"
  s.licenses = ['MIT']

  s.name = 'rack-grid-serve'
  s.version = Rack::GridServe::VERSION
  s.summary = "Rack middleware for serving files stored in MongoDB GridFS"
  s.description = "Rack::GridServe is a Rack middleware for serving files stored in MongoDB GridFS. It is meant as a simple replacement for Rack::GridFS until it is ready for Mongo driver version 2.0 and above."

  s.platform = Gem::Platform::RUBY
  s.files = `git ls-files`.split("\n").sort
  s.test_files = 'test.rb'
  s.require_paths = ['lib']

  s.add_dependency('rack', '~> 2.0')
  s.add_dependency('mongo', '~> 2.0')

  s.add_development_dependency('minitest', '~> 5.8')
  s.add_development_dependency('rack-test', '~> 0.6')

end


# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'cascade-store'
  spec.version       = '1.0.1'
  spec.authors       = ['danielkman']
  spec.email         = ['daniel.kalman@riskified.com']

  spec.summary       = %q{In-memory to redis cascading}
  spec.description   = %q{This Gem adds a new rails cache store for cascading between in memory and redis cache.}
  spec.homepage      = 'http://www.riskified.com'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.17.3'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'fakeredis', '~> 0.7.0'
  spec.add_runtime_dependency 'activesupport', '~> 5'
  spec.add_runtime_dependency 'naught', '~> 1.1.0'
  spec.add_runtime_dependency 'redis', '~> 4.1.2'
  spec.add_runtime_dependency 'redis-rails', '~> 5.0.2'
end

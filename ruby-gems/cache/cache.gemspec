# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cache/version'

Gem::Specification.new do |spec|

  spec.name          = 'cache'
  spec.version       = Cache::VERSION
  spec.date          = '2017-10-26'
  spec.authors       = ['Bodo Schulz']
  spec.email         = ['bodo.schulz@coremedia.com']
  spec.summary       = 'Cache is a lightweight, in-memory key-value store for Ruby objects'
  spec.description   = 'A lightweight, in-memory cache for Ruby objects'
  spec.homepage      = 'http://moebius.express'
  spec.license       = 'Nonstandard'

  spec.files         = Dir[
    'lib/**/*'
  ]

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

#  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
#  spec.bindir        = "exe"
#  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  begin

    if( RUBY_VERSION = '2.1' )
      spec.required_ruby_version = '~> 2.1'
    elsif( RUBY_VERSION <= '2.2' )
      spec.required_ruby_version = '~> 2.2'
    elsif( RUBY_VERSION <= '2.3' )
      spec.required_ruby_version = '~> 2.3'
    end

  rescue => e
    warn "#{$0}: #{e}"
    exit!
  end

  spec.add_development_dependency('rake', '~> 0')
  spec.add_development_dependency('rake-notes', '~> 0')
  spec.add_development_dependency('rubocop', '~> 0')
  spec.add_development_dependency('rubocop-checkstyle_formatter', '~> 0')
  spec.add_development_dependency('rspec', '~> 0')
  spec.add_development_dependency('rspec_junit_formatter', '~> 0')
  spec.add_development_dependency('rspec-nc', '~> 0')

end

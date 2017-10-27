# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'storage/version'

Gem::Specification.new do |spec|

  spec.name          = 'storage'
  spec.version       = Storage::VERSION
  spec.date          = '2017-10-27'
  spec.authors       = ['Bodo Schulz']
  spec.email         = ['bodo.schulz@coremedia.com']
  spec.summary       = 'Storage ist a small wrapper Module over a set of Database Engines'
  spec.description   = 'small wrapper Module over a set of Database Engines'
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
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

#  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
#  spec.bindir        = "exe"
#  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  begin

    if( RUBY_VERSION = '2.1' )
      spec.required_ruby_version = '~> 2.1'
    elsif( RUBY_VERSION <= '2.2' )
      spec.required_ruby_version = '~> 2.2'
      spec.add_dependency('redis', '~> 3.3')
    elsif( RUBY_VERSION <= '2.3' )
      spec.required_ruby_version = '~> 2.3'
      spec.add_dependency('redis', '~> 4.0')
    end

    spec.add_dependency('json', '~> 2.1')
    # spec.add_dependency('logger', '~> 1.2')
    # spec.add_dependency('semantic_logger', '~> 4.2')

    # memcached
    spec.add_dependency('dalli', '~> 2.7')
    # mysqld
    spec.add_dependency('mysql2', '~> 0.4')
    # redis
    # spec.add_dependency('redis', '~> 3.3')
    # sqlite
    # spec.add_dependency('', '~> 2.7')

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

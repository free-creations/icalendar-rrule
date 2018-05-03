
# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'icalendar/rrule/version'

Gem::Specification.new do |gem_spec|
  gem_spec.name          = 'icalendar-rrule'
  gem_spec.version       = Icalendar::Rrule::VERSION
  gem_spec.authors       = ['Harald Postner']
  gem_spec.email         = ['harald@free-creations.de']

  gem_spec.summary       = 'Use this module if you want to iterate over an ICalendars with recurring events. '
  gem_spec.description   = 'This Gem adds a view to ICalendar class which expands ' \
                       'all recurring events.'
  gem_spec.homepage      = 'https://github.com/free-creations/icalendar-rrule'
  gem_spec.license       = 'MIT'

  gem_spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  gem_spec.bindir        = 'exe'
  gem_spec.executables   = gem_spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  gem_spec.require_paths = ['lib']

  gem_spec.add_dependency 'activesupport', '~> 5.1'
  gem_spec.add_dependency 'icalendar', '~> 2.4'

  gem_spec.add_development_dependency 'bundler', '~> 1.16'
  gem_spec.add_development_dependency 'rake', '~> 10.0'
  gem_spec.add_development_dependency 'rspec', '~> 3.7'
  gem_spec.add_development_dependency 'rubocop', '~> 0.55.0'
  gem_spec.add_development_dependency 'rubocop-rspec', '~> 1.24'
end

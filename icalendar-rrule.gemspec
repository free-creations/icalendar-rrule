
# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
# note: requiring the version file here, will make this file invisible to 'SimpleCov' the code coverage analysis tool.
require 'icalendar/rrule/version'

Gem::Specification.new do |gem_spec|
  gem_spec.name          = 'icalendar-rrule'
  gem_spec.version       = Icalendar::Rrule::VERSION
  gem_spec.authors       = ['Harald Postner']
  gem_spec.email         = ['harald-LB@free-creations.de']

  gem_spec.summary       = 'Helper for ICalendars with recurring events. '
  gem_spec.description   = 'An add-on to the iCalendar GEM ' \
                           'that helps to handle repeating events (recurring events) in a consistent way.'
  gem_spec.homepage      = 'https://github.com/free-creations/icalendar-rrule'
  gem_spec.license       = 'MIT'

  gem_spec.metadata['homepage_uri'] = gem_spec.homepage
  gem_spec.metadata['source_code_uri'] = gem_spec.homepage
  gem_spec.metadata['bug_tracker_uri'] = 'https://github.com/free-creations/icalendar-rrule/issues'

  gem_spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  gem_spec.executables   = gem_spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  gem_spec.require_paths = ['lib']

  gem_spec.required_ruby_version = '>= 2.5'

  gem_spec.add_dependency 'activesupport', '>= 5.1'
  gem_spec.add_dependency 'icalendar', '>= 2.4'
  gem_spec.add_dependency 'ice_cube', '= 0.16'

  gem_spec.add_development_dependency 'bundler', '>= 2'
  gem_spec.add_development_dependency 'rake', '>= 12.3.3'
  gem_spec.add_development_dependency 'rspec', '~> 3.7'
  gem_spec.add_development_dependency 'rubocop', '~> 0.55.0'
  gem_spec.add_development_dependency 'rubocop-rspec', '~> 1.24'
  gem_spec.add_development_dependency 'simplecov', '~> 0.16'
end

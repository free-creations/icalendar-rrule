# frozen_string_literal: true

module Icalendar
  ##
  # Refines the  Icalendar::Calendar class by adding
  # the `scan` function to this class.
  #
  # @note [Refinement](https://ruby-doc.org/core-2.5.0/doc/syntax/refinements_rdoc.html)
  # is a _Ruby core feature_ since Ruby 2.0
  #
  module Scannable
    ##
    # Provides _mixin_ methods for the
    # Icalendar::Calendar class
    refine Icalendar::Calendar do # rubocop:disable Metrics/BlockLength
      using Icalendar::Schedulable
      ##
      # @param[date_time] begin_time
      # @param[date_time] closing_time
      # @param [Set] component_types a list of components that shall be retrieved these can be
      # - :events
      # - :todos
      # Note: `:journals` and `:freebusys` are currently not tested.
      #
      # @return [Array] all occurrences between begin_time and closing_time
      def scan(begin_time, closing_time, component_types = Set[:events])
        component_types = component_types.to_set
        result = []
        component_types.each do |component_type|
          result += _occurrences_between(_components(component_type), begin_time, closing_time)
        end
        result ||= [] # stop RubyMine to complain about uninitialized result.
        result.sort!
      end

      private def _components(component_type)
        # note: events(), todos(), journals(), freebusys() are attributes added
        # to Icalendar::Calendar by meta-programming.
        case component_type
        when :events then events
        when :todos then todos
          # :nocov:
        when :journals then journals
        when :freebusys then freebusys
          # :nocov:
        else
          raise ArgumentError, "Unknown Component type: `#{component_type}`."
        end
      end

      private def _occurrences_between(components, begin_time, closing_time)
        # ice_cube does not support timezones well, so we have to convert the given timezones to UTC.
        result = []
        components.each do |base_component|
          ice_cube_occurrences = base_component.schedule.occurrences_between(begin_time.to_time.utc, closing_time.to_time.utc)

          ice_cube_occurrences.each do |ice_oc|
            # retrieve start and end for this ice_cube occurrence and convert into the
            # target timezones
            ice_comp_start_time = ice_oc.start_time
            # we assert that ice_comp_start_time is UTC here.
            fail "expected UTC-time for ice_start_time" unless  ice_comp_start_time.utc?
            start_tz = ice_comp_start_time.in_time_zone(base_component._timezone_for_start)

            ice_end_time = ice_oc.end_time
            # we assert that ice_end_time is UTC here.
            fail "expected UTC-time for ice_end_time" unless ice_end_time.utc?
            end_tz = ice_end_time.in_time_zone(base_component._timezone_for_end)

            new_oc = Icalendar::Rrule::Occurrence.new(self, base_component, start_tz, end_tz)
            result << new_oc
          end
        end
        result
      end
    end
  end
end

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
        result = []
        components.each do |comp|
          occurrences = comp.schedule.occurrences_between(begin_time, closing_time)
          occurrences.each do |oc|
            # Convert IceCube times back to TimeWithZone in correct timezone
            start_tz = oc.start_time.in_time_zone(comp.start_time.time_zone)
            end_tz = oc.end_time.in_time_zone(comp.end_time.time_zone)

            new_oc = Icalendar::Rrule::Occurrence.new(self, comp, start_tz, end_tz)
            result << new_oc
          end
        end
        result
      end
    end
  end
end

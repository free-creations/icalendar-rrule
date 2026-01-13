# frozen_string_literal: true

# frozen_string_literal: true

module Icalendar
  module Rrule
    ##
    # Refinements for Ruby's Time class to support iCalendar time concepts.
    #
    # This module provides extensions for handling:
    # - Floating time (wall-clock time without timezone)
    # - Timezone conversions (planned)
    #
    # @example
    #   using Icalendar::Rrule::TimeRefinements
    #
    #   time = Time.new(2026, 1, 7, 14, 30, 0, 0)
    #   time.floating?  # => true
    #
    module TimeRefinements
      refine Time do
        ##
        # Checks if this Time object represents "floating time".
        #
        # Floating time is wall-clock time without timezone information,
        # represented as a Time with zone == nil.
        #
        # In iCalendar terms, floating time is a DATETIME without TZID
        # and without the "Z" suffix (e.g., "20260107T143000").
        #
        # This is semantically different from UTC:
        # - UTC is a real timezone (the world reference)
        # - Floating time means "interpret locally" (like a photo of a clock)
        #
        # @return [Boolean] true if this is floating time (zone is nil)
        #
        # @example Floating time
        #   Time.new(2026, 1, 1, 12, 0, 0, 0).floating?  # => true
        #
        # @example UTC is NOT floating
        #   Time.utc(2026, 1, 1, 12, 0, 0).floating?     # => false
        #
        # @example Zoned time is NOT floating
        #   Time.new(2026, 1, 1, 12, 0, 0, "+01:00").floating?  # => false
        #
        def floating?
          zone.nil? && utc_offset.zero?
        rescue
          false
        end
      end
    end
  end
end
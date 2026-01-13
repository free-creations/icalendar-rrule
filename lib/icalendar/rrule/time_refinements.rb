# frozen_string_literal: true

require 'time'
require 'active_support/time_with_zone'
require 'active_support/values/time_zone'

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
        rescue StandardError
          false
        end

        ##
        # Converts to floating time. No questions asked.
        # @return [Time] floating time
        def to_floating
          return self if floating?
          Time.new(year, month, day, hour, min, sec, 0)
        end

        ##
        # Ensures this is floating-time, warns if conversion needed.
        # @return [Time] floating time
        def ensure_floating
          return self if floating?

          Icalendar::Rrule.logger.warn do
            "[icalendar-rrule] Time should be floating but has offset: '#{inspect}' - converting"
          end

          to_floating
        end


        ##
        # Embeds floating time into a specific timezone.
        #
        # Interprets the wall-clock components (year, month, day, hour, min, sec)
        # as local time in the given timezone, creating a TimeWithZone.
        #
        # This is the inverse operation to `to_floating`.
        #
        # @param [ActiveSupport::TimeZone, String] timezone the target timezone
        # @return [ActiveSupport::TimeWithZone] the time embedded in the given timezone
        # @raise [ArgumentError] if called on non-floating time (to prevent accidental misuse)
        #
        # @example Embed floating time in Berlin timezone
        #   floating = Time.new(2026, 3, 30, 10, 0, 0, 0)  # 10:00 floating
        #   berlin_time = floating.into_timezone('Europe/Berlin')
        #   # => 2026-03-30 10:00:00 +0200 (CEST, because DST active)
        #
        # @example Embed the same floating time in New York
        #   ny_time = floating.into_timezone('America/New_York')
        #   # => 2026-03-30 10:00:00 -0400 (EDT, because DST active)
        #
        def into_timezone(timezone)
          unless floating?
            raise ArgumentError, "Time::into_timezone can only be called on floating time, got: #{inspect}"
          end

          # Ensure we have an ActiveSupport::TimeZone object
          tz = if timezone.is_a?(ActiveSupport::TimeZone)
                 timezone
               else
                 ActiveSupport::TimeZone[timezone]
               end

          unless tz
            Icalendar::Rrule.logger.warn do
              "[icalendar-rrule] Invalid timezone '#{timezone.inspect}' in Time::into_timezone - falling back to UTC"
            end
            tz = ActiveSupport::TimeZone['UTC']
          end

          # Interpret wall-clock components as local time in target timezone
          tz.local(year, month, day, hour, min, sec)
        end

      end
    end
  end
end
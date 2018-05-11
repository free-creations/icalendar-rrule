# frozen_string_literal: true

require 'ice_cube'
require 'active_support/time_with_zone'

module Icalendar
  ##
  # Refines the  Icalendar::Component class by adding
  # some method to this class.
  #
  # @note [Refinement](https://ruby-doc.org/core-2.5.0/doc/syntax/refinements_rdoc.html)
  # is a _Ruby core feature_ since Ruby 2.0
  #
  module Schedulable
    NULL_DATE = Icalendar::Values::DateTime.new('00000101T000000Z')
    ##
    # Provides _mixin_ methods for the
    # Icalendar::Component class
    refine Icalendar::Component do # rubocop:disable Metrics/BlockLength
      ##
      # Make sure, that we can always query for a _dtstart_ time.
      # @return[Icalendar::Values::DateTime] a valid DateTime object or nil.
      private def _dtstart
        dtstart
      rescue StandardError
        nil
      end
      ##
      # Make sure, that we can always query for a _dtend_ time.
      # @return[Icalendar::Values::DateTime] a valid DateTime object or nil.
      private def _dtend
        dtend
      rescue StandardError
        nil
      end
      ##
      # Make sure, that we can always query for a _due_ date.
      # @return[Icalendar::Values::DateTime] a valid DateTime object or nil.
      private def _due
        due
      rescue StandardError
        nil
      end

      ##
      # @return[Rational] the number of days (or a fraction of days) this task will last.
      #                   If no duration for this task is specified, this function returns zero.
      private def duration_days # rubocop:disable Metrics/AbcSize
        return 0 unless (respond_to? :duration) && duration.is_a?(Icalendar::Values::Duration)
        d = duration
        duration_days = d.weeks * 7 +
                        d.days +
                        Rational(d.hours, 24) +
                        Rational(d.minutes, 24 * 60) +
                        Rational(d.seconds, 24 * 60 * 60)
        duration_days
      end

      ##
      # The time when the event or task shall start.
      # @return[Icalendar::Values::DateTime] a valid DateTime object
      def start_time
        if _dtstart
          _dtstart
        elsif _due
          Icalendar::Values::DateTime.new(_due.to_datetime - duration_days, _due.ical_params)
        else
          NULL_DATE
        end
      end

      ##
      # The time when the event or task shall end.
      # @return[Icalendar::Values::DateTime] a valid DateTime object
      def end_time # rubocop:disable Metrics/AbcSize
        if _due
          _due
        elsif _dtend
          _dtend
        elsif _dtstart
          Icalendar::Values::DateTime.new(_dtstart.to_datetime + duration_days, _dtstart.ical_params)
        else
          Icalendar::Values::DateTime.new(NULL_DATE.to_datetime + duration_days, NULL_DATE.ical_params)
        end
      end

      ##
      # Make sure, that we can always query for a _rrule_ array.
      # @return[array] an array of _ical repeat-rules_ (or an empty array
      #                if no repeat-rules are defined for this component).
      def _rrules
        Array(rrule)
      rescue StandardError
        []
      end

      ##
      # Creates a schedule for this event
      # @return[IceCube::Schedule]
      def schedule
        schedule = IceCube::Schedule.new
        schedule.start_time = _ensure_with_time_zone(start_time)
        schedule.end_time = _ensure_with_time_zone(end_time)
        raise NotImplementedError
      end

      ##
      # Make sure, that the given date_time is of type
      # `ActiveSupport::TimeWithZone`.  Make further sure, that all the times are defined in the same timezone.
      # The timezone is arbitrarily chosen to be the first zone that this method encounters.
      #
      # @return[ActiveSupport::TimeWithZone] if the given object satisfies all conditions it is returned.
      #                                     Otherwise the method attempts to "correct" the given Object.
      #
      def _ensure_with_time_zone(date_time) # rubocop:disable Metrics/MethodLength
        if date_time.is_a?(ActiveSupport::TimeWithZone)
          # OK, the class is correct
          # on first invocation of this routine, we'll record the time-zone for future use.
          @schedule_time_zone ||= date_time.time_zone

          # OK, if the timezone is also correct, we'll give back the input object.
          result = if date_time.time_zone == @schedule_time_zone
                     date_time
                   else
                     # we have to convert to the expected time zone
                     date_time.in_time_zone(@schedule_time_zone)
                   end

          return result

        elsif date_time.respond_to?(:to_time)
          # The given class is not absolutely what we want, but at least it is some kind of Time-class.
          # On first invocation of this routine, we'll have to settle on a time-zone.
          @schedule_time_zone ||= ActiveSupport::TimeZone['UTC']
          return @schedule_time_zone.at(date_time.to_time.to_i)
        end
        # Oops, the given object is unusable, we'll give back the NULL_DATE
        @schedule_time_zone ||= ActiveSupport::TimeZone['UTC']
        @schedule_time_zone.at(0)
      end
    end
  end
end

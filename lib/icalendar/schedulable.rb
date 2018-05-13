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
    NULL_TIME = Time.at(0)

    SEC_MIN  = 60 # the number of seconds in a minute
    SEC_HOUR = 60 * SEC_MIN # the number of seconds in an hour
    SEC_DAY  = 24 * SEC_HOUR # the number of seconds in a day
    SEC_WEEK = 7 * SEC_DAY # the number of seconds in a week
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
      # @return[Integer] the number of seconds this task will last.
      #                   If no duration for this task is specified, this function returns zero.
      def _duration_seconds # rubocop:disable Metrics/AbcSize
        return 0 unless respond_to? :duration
        d = duration
        return 0 unless d.is_a?(Icalendar::Values::Duration)
        d.seconds + (d.minutes * SEC_MIN) + (d.hours * SEC_HOUR) + (d.days * SEC_DAY) + (d.weeks * SEC_WEEK)
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
        schedule.start_time = _to_time_with_zone(start_time)
        schedule.end_time = _to_time_with_zone(end_time)
        raise NotImplementedError
      end

      ##
      # Transform the given time into an object of type `ActiveSupport::TimeWithZone`.
      #
      # Further, make sure, that all such time-objects are defined in the same timezone.
      # The timezone is arbitrarily chosen to be the first zone that this method encounters.
      #
      # @return[ActiveSupport::TimeWithZone] if the given object satisfies all conditions it is returned unchanged.
      #                                     Otherwise the method attempts to "correct" the given Object.
      #
      def _to_time_with_zone(date_time)
        # on first invocation of this routine, we'll record the timezone for future use.
        _unique_timezone

        if date_time.is_a?(ActiveSupport::TimeWithZone)
          # the class is correct
          #  if the timezone is also correct, we'll give back the input object.
          return date_time if date_time.time_zone == @_unique_timezone

          # convert to the unique timezone and return it.
          return date_time.in_time_zone(@_unique_timezone)

        elsif date_time.respond_to?(:to_time)
          # The given class is not absolutely what we want, but at least it is some kind of Time-class.
          return @_unique_timezone.at(date_time.to_time.to_i)
        end
        # Oops, the given object is unusable, we'll give back the NULL_DATE
        @_unique_timezone.at(NULL_TIME)
      end

      ##
      # Set the `@_unique_timezone` instance variable to the timezone that shall be used in this component.
      # If the `@_unique_timezone` is already set, this method will do noting.
      # @return[ActiveSupport::TimeZone] the unique timezone used in this component
      def _unique_timezone
        return @_unique_timezone if @_unique_timezone # nothing to do if @@_unique_timezone is already set

        # let's try sequentially, the first wins.
        @_unique_timezone ||= _extract_timezone(_dtend)
        @_unique_timezone ||= _extract_timezone(_dtstart)
        @_unique_timezone ||= _extract_timezone(_due)

        # as a last resort we'll use the Coordinated Universal Time (UTC).
        @_unique_timezone ||= ActiveSupport::TimeZone['UTC']
      end

      ##
      # Set the `@@_unique_timezone` instance variable to the timezone used by the given date_time value.
      # If the `@@_unique_timezone` is already set, this method will do noting.
      # @param[Object] date_time the object from which we shall determine the time zone.
      # @return[ActiveSupport::TimeZone] the unique timezone used in this component
      def _extract_timezone(date_time)
        return date_time.time_zone if date_time.is_a?(ActiveSupport::TimeWithZone)
        return _extract_ical_time_zone(date_time) if date_time.is_a?(Icalendar::Value)
        nil
      end

      ##
      # Tries to find a time zone object that best matches the timezone-identifier given in the params of an ical value.
      # @param[Icalendar::Values::DateTime] ical_value an ical value that (probably) supports a time zone identifier.
      # @return [ActiveSupport::TimeZone] the time zone referred to by the ical_value or nil.
      def _extract_ical_time_zone(ical_value)
        return nil unless ical_value.respond_to?(:ical_params)
        ugly_tzid = ical_value.ical_params.fetch('tzid', nil)
        return nil if ugly_tzid.nil?
        tzid = Array(ugly_tzid).first.to_s.gsub(/^(["'])|(["'])$/, '')
        ActiveSupport::TimeZone[tzid]
      end
    end
  end
end

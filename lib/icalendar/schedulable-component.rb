# frozen_string_literal: true

require 'ice_cube'
require 'active_support/time_with_zone'

module Icalendar
  ##
  # Refines the  Icalendar::Component class by adding
  # an interface between the IceCube Gem  and the the Icalendar::Component-class.
  #
  # __Note:__ _Refinement_  is a Ruby core feature since Ruby 2.0.
  # @see: https://ruby-doc.org/core-2.5.0/doc/syntax/refinements_rdoc.html
  #
  # There are some shortcomings, the
  # [documentation](http://ruby-doc.org/core-2.2.2/doc/syntax/refinements_rdoc.html#label-Indirect+Method+Calls)
  # says:
  #
  # >When using indirect method access such as Kernel#send, Kernel#method or Kernel#respond_to?
  # >refinements are not honored for the caller context during method lookup.
  # >
  # >This behavior may be changed in the future.
  #
  # The purpose of this module is:
  #
  # - normalise the handling of date and time by using ActiveSupport::TimeWithZone everywhere.
  # - provide the methods *start_time* and *end_time* that always return something sensible, no matter
  #   how these times were defined in the original component.
  # - provide a schedule for repeating events created by the so called **rrule**.
  #
  #
  module Schedulable
    ##
    # @!method start_time()
    #   The time when the event or task shall start.
    #   @return [ActiveSupport::TimeWithZone] a valid DateTime object
    #
    #
    # @!method end_time()
    #   The time when the event or task shall end.
    #   @return [ActiveSupport::TimeWithZone] a valid DateTime object
    #

    # The start of the Unix Epoch (January 1, 1970 00:00 UTC).
    NULL_TIME = 0

    # the number of seconds in a minute
    SEC_MIN  = 60
    # the number of seconds in an hour
    SEC_HOUR = 60 * SEC_MIN
    # the number of seconds in a day
    SEC_DAY  = 24 * SEC_HOUR
    # the number of seconds in a week
    SEC_WEEK = 7 * SEC_DAY
    ##
    # Provides _mixin_ methods for the
    # Icalendar::Component class
    refine Icalendar::Component do # rubocop:disable Metrics/BlockLength
      ##
      # Make sure, that we can always query for a _dtstart_ time.
      # @return [Icalendar::Value, nil] a valid DateTime object or nil.
      # @api private
      private def _dtstart
        dtstart
      rescue StandardError
        nil
      end
      ##
      # Make sure, that we can always query for a _dtend_ time.
      # @return [Icalendar::Value, nil] a valid DateTime object or nil.
      # @api private
      private def _dtend
        dtend
      rescue StandardError
        nil
      end
      ##
      # Make sure, that we can always query for a _due_ date.
      # @return [Icalendar::Value, nil] a valid DateTime object or nil.
      # @api private
      private def _due
        due
      rescue StandardError
        nil
      end
      ##
      # Make sure, that we can always query for a _the duration value.
      # @return [Icalendar::Values::Duration, nil] a valid Duration object or nil.
      # @api private
      def _duration
        duration
      rescue StandardError
        nil
      end

      ##
      # @return [Integer] the number of seconds this task will last.
      #                   If no duration for this task is specified, this function returns zero.
      # @api private
      def _duration_seconds # rubocop:disable Metrics/AbcSize
        return _guessed_duration unless _duration
        d = _duration
        return _guessed_duration unless d.is_a?(Icalendar::Values::Duration)
        d.seconds + (d.minutes * SEC_MIN) + (d.hours * SEC_HOUR) + (d.days * SEC_DAY) + (d.weeks * SEC_WEEK)
      end

      ##
      # Make an educated guess how long this event might last according to the following definition from RFC 5545:
      #
      #   > For cases where a "VEVENT" calendar component
      #   > specifies a "DTSTART" property with a DATE value type but no
      #   > "DTEND" nor "DURATION" property, the event's duration is taken to
      #   >  be one day.
      #
      # @return [Integer] the number of seconds this task might last.
      # @api private
      def _guessed_duration
        if _dtstart.is_a?(Icalendar::Values::Date) && _dtend.nil? && _duration.nil? && _due.nil?
          SEC_DAY
        else
          0
        end
      end

      ##
      # The time when the event or task shall start.
      # @return [ActiveSupport::TimeWithZone] a valid DateTime object
      def start_time
        if _dtstart
          _to_time_with_zone(_dtstart)
        elsif _due
          _to_time_with_zone(_due.to_i - _duration_seconds)
        else
          _to_time_with_zone(NULL_TIME)
        end
      end

      ##
      # The time when the event or task shall end.
      # @return [ActiveSupport::TimeWithZone] a valid DateTime object
      def end_time # rubocop:disable Metrics/AbcSize
        if _due
          _to_time_with_zone(_due)
        elsif _dtend
          _to_time_with_zone(_dtend)
        elsif _dtstart
          _to_time_with_zone(_dtstart.to_i + _duration_seconds)
        else
          _to_time_with_zone(NULL_TIME + _duration_seconds)
        end
      end

      ##
      # Heuristic to determine whether the event is scheduled
      # for a date without precising the exact time of day.
      # @return [Boolean] true if the component is scheduled for a date, false otherwise.
      def all_day?
        _dtstart.is_a?(Icalendar::Values::Date) ||
          (start_time == start_time.beginning_of_day && end_time == end_time.beginning_of_day)
      end

      ##
      # @return [Boolean] true if the duration of the event spans more than one day.
      def multi_day?
        start_time.next_day.beginning_of_day < end_time
      end

      ##
      # Make sure, that we can always query for a _rrule_ array.
      # @return [array] an array of _ical repeat-rules_ (or an empty array
      #                if no repeat-rules are defined for this component).
      # @api private
      def _rrules
        Array(rrule).flatten.map(&:value_ical)
      rescue StandardError
        []
      end

      ##
      # Make sure, that we can always query for an _exdate_ array.
      # @return [array<ActiveSupport::TimeWithZone>] an array of _ical exdates_ (or an empty array
      #                if no repeat-rules are defined for this component).
      # @api private
      def _exdates
        Array(exdate).flatten
      rescue StandardError
        []
      end

      ##
      # Make sure, that we can always query for the Recurrence ID.
      #
      # From RFC 5545:
      #
      # ```
      #   3.8.4.4.  Recurrence ID
      #
      #   This property is used in conjunction with the "UID" and
      #       "SEQUENCE" properties to identify a specific instance of a
      #       recurring "VEVENT", "VTODO", or "VJOURNAL" calendar component.
      #
      # ```
      #
      # @return [ActiveSupport::TimeWithZone] the original value of the "DTSTART" property
      #       of the recurrence instance.
      # @api private
      def _recurrence_id
        recurrence_id
      rescue StandardError
        nil
      end

      ##
      # Is this component a replacement for a certain repeat- occurrence.
      # @return [Boolean] true if this component replaces a repeat- occurrence.
      # @api private
      def _is_substitute?
        !_recurrence_id.nil?
      end

      ##
      # @return [Array<Icalendar::Component>] the container that holds this component.
      # @api private
      def _parent_set
        return [] unless respond_to?(:parent)
        return [] unless parent.is_a?(Icalendar::Calendar)

        case self
        when Icalendar::Event then parent.events
        when Icalendar::Todo then parent.todos
        when Icalendar::Journal then parent.journals
        else
          []
        end
      end

      ##
      # Like the for _exdates, also for these dates do not schedule recurrence items.
      #
      # @return [array<ActiveSupport::TimeWithZone>] an array of dates.
      # @api private
      def _overwritten_dates
        result = []
        _parent_set.each do |event|
          next unless uid == event.uid
          next unless event._is_substitute?
          result << event._recurrence_id
        end
        result
      end

      ##
      # Make sure, that we can always query for an rdate(Recurrence Date) array.
      # @return [array] an array of _ical rdates_ (or an empty array
      #                if no repeat-rules are defined for this component).
      # @api private
      def _rdates
        Array(rdate).flatten
      rescue StandardError
        []
      end

      ##
      # Creates a schedule for this event
      # @return [IceCube::Schedule]
      def schedule # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        schedule = IceCube::Schedule.new
        schedule.start_time = start_time
        schedule.end_time = end_time
        _rrules.each do |rrule|
          ice_cube_recurrence_rule = IceCube::Rule.from_ical(rrule)
          schedule.add_recurrence_rule(ice_cube_recurrence_rule)
        end

        _exdates.each do |time|
          schedule.add_exception_time(_to_time_with_zone(time))
        end

        _overwritten_dates.each do |time|
          schedule.add_exception_time(_to_time_with_zone(time))
        end

        rdates = _rdates
        rdates.each do |time|
          schedule.add_recurrence_time(_to_time_with_zone(time))
        end
        schedule
      end

      ##
      # Transform the given object into an object of type `ActiveSupport::TimeWithZone`.
      #
      # Further, try to make sure, that all time-objects of this component are defined in the same timezone.
      #
      # @param [Object] date_time an object that represents a time.
      # @param [ActiveSupport::TimeZone] timezone the timezone to be used. If nil, the timezone will be guessed.
      # @return [ActiveSupport::TimeWithZone] if the given object satisfies all conditions it is returned unchanged.
      #                                     Otherwise the method attempts to "correct" the given Object.
      #
      # rubocop:disable Metrics/MethodLength,Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      def _to_time_with_zone(date_time, timezone = nil)
        timezone ||= component_timezone

        # For Icalendar::Values::DateTime, we can extract the ical value. Which probably is already what we want.
        date_time_value = if date_time.is_a?(Icalendar::Values::DateTime)
                            date_time.value
                          else
                            date_time
                          end

        if date_time_value.is_a?(ActiveSupport::TimeWithZone)
          # the class is correct
          #  if the timezone is also correct, we'll give back the input object.
          return date_time_value if date_time_value.time_zone == timezone

          # convert to the requested timezone and return it.
          return date_time_value.in_time_zone(timezone)

        elsif date_time_value.is_a?(DateTime)
          return date_time_value.in_time_zone(timezone)

        elsif date_time_value.is_a?(Icalendar::Values::Date)
          return _date_to_time_with_zone(date_time_value, timezone)

        elsif date_time_value.is_a?(Date)
          return _date_to_time_with_zone(date_time_value, timezone)

        elsif date_time_value.respond_to?(:to_time)
          return timezone.at(date_time_value.to_time)

        elsif date_time_value.respond_to?(:to_i)
          # lets interpret the given value as the number of seconds since the Epoch (January 1, 1970 00:00 UTC).
          return timezone.at(date_time_value.to_i)

        end
        # Oops, the given object is unusable, we'll give back the NULL_DATE
        timezone.at(NULL_TIME)
      end
      # rubocop:enable Metrics/MethodLength,Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

      ##
      # Convert a date into the corresponding TimeWithZone value.
      # @param [#to_date] date a calendar date.
      # @param [ActiveSupport::TimeZone] timezone the timezone to be used.
      # @return [ActiveSupport::TimeWithZone] mid-night in the given timezone at the given date.
      def _date_to_time_with_zone(date, timezone)
        d = date.to_date
        timezone.local(d.year, d.month, d.day)
      end

      ##
      # Heuristic to determine the best timezone that shall be used in this component.
      # @return [ActiveSupport::TimeZone] the unique timezone used in this component
      def component_timezone
        # let's try sequentially, the first non-nil wins.
        timezone ||= _extract_timezone(_dtend)
        timezone ||= _extract_timezone(_dtstart)
        timezone ||= _extract_timezone(_due)

        # as a last resort we'll use the Coordinated Universal Time (UTC).
        timezone || ActiveSupport::TimeZone['UTC']
      end

      ##
      # Get the timezone from the given object trying different methods to find an indication in the object.
      # @param [Object] date_time an object from which we shall determine the time zone.
      # @return [ActiveSupport::TimeZone, nil] the timezone used by the parameter or nil if no timezone has been set.
      # @api private
      def _extract_timezone(date_time)
        timezone ||= _extract_ical_time_zone(date_time) # try with ical parameter
        timezone ||= _extract_act_sup_timezone(date_time) # is the given value already ActiveSupport::TimeWithZone?
        timezone || _extract_value_time_zone(date_time) # is the ical.value of type ActiveSupport::TimeWithZone?
      end

      ##
      # Get the timezone from the given object, assuming it is an ActiveSupport::TimeWithZone.
      # @param [Object] date_time an object from which we shall determine the time zone.
      # @return [ActiveSupport::TimeZone, nil] the timezone or nil if the operation could not be performed.
      # @api private
      def _extract_act_sup_timezone(date_time)
        return nil unless date_time.is_a?(ActiveSupport::TimeWithZone)
        date_time.time_zone
      end

      ##
      # Get the timezone from the given object, assuming it can be extracted from `ical_value.value.time_zone`
      # @param [Object] ical_value an object from which we shall determine the time zone.
      # @return [ActiveSupport::TimeZone, nil] the timezone used by the parameter
      #                                  or nil if the operation could not be performed.
      # @api private
      def _extract_value_time_zone(ical_value)
        return nil unless ical_value.is_a?(Icalendar::Value)
        return nil unless ical_value.value.is_a?(ActiveSupport::TimeWithZone)
        ical_value.value.time_zone
      end

      ##
      # Get the timezone from the given object, assuming it can be extracted from ical params.
      # @param [Icalendar::Value] ical_value an ical value that (probably) supports a time zone identifier.
      # @return [ActiveSupport::TimeZone, nil] the timezone referred to by the ical_value or nil.
      # @api private
      def _extract_ical_time_zone(ical_value)
        return nil unless ical_value.is_a?(Icalendar::Value)
        return nil unless ical_value.respond_to?(:ical_params)
        ugly_tzid = ical_value.ical_params.fetch('tzid', nil)
        return nil if ugly_tzid.nil?
        tzid = Array(ugly_tzid).first.to_s.gsub(/^(["'])|(["'])$/, '')
        ActiveSupport::TimeZone[tzid]
      end
    end
  end
end

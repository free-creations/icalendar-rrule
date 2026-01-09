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
      # Returns the explicit duration from DURATION property or guessed duration.
      #
      # WARNING: This does NOT compute the actual duration between start_time and end_time!
      # For events with DTEND but no DURATION property, this returns 0 or the guessed duration,
      # even though the actual duration may be longer.
      #
      # To get the actual duration, use: (end_time.to_i - start_time.to_i)
      #
      # @return [Integer] explicit duration in seconds, or 0 if not specified
      # @api private
      def _duration_seconds # rubocop:disable Metrics/AbcSize
        return _guessed_duration unless _duration
        d = _duration
        return _guessed_duration unless d.is_a?(Icalendar::Values::Duration)
        d.seconds + (d.minutes * SEC_MIN) + (d.hours * SEC_HOUR) + (d.days * SEC_DAY) + (d.weeks * SEC_WEEK)
      end

      # Check if dtstart looks like an all-day event (starts at midnight)
      # This is used internally to determine if we should apply the 1-day duration rule
      # @return [Boolean] true if dtstart is a Date or starts at midnight
      # @api private
      def _dtstart_is_all_day?
        # Only apply the 1-day rule to Events, not Tasks
        return false unless self.is_a?(Icalendar::Event)

        return true if _dtstart.is_a?(Icalendar::Values::Date)

        # If it's a DateTime, check if it's at midnight (00:00:00)
        if _dtstart.respond_to?(:to_time) || _dtstart.respond_to?(:to_datetime)
          time = _to_time_with_zone(_dtstart)
          return time == time.beginning_of_day
        end

        false
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
        if _dtstart_is_all_day? && _dtend.nil? && _duration.nil? && _due.nil?
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
        elsif _due && _duration_seconds > 0
          _to_time_with_zone(_due.to_i - _duration_seconds)
        elsif _due
          # Task with only DUE, no duration: start == end (zero-duration/deadline-only)
          _to_time_with_zone(_due)
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
          # Special handling for all-day events without explicit end
          if _dtstart_is_all_day? && _dtend.nil?
            # Stay in date space: add days to the date, not seconds to timestamp
            start_date = _dtstart_all_day_event_as_date
            end_date = start_date + (_duration_seconds / SEC_DAY).days
            _date_to_time_with_zone(end_date, component_timezone)
          else
            _to_time_with_zone(start_time.to_i + _duration_seconds)
          end
        else
          _to_time_with_zone(NULL_TIME + _duration_seconds)
        end
      end

      # Extract the date component from dtstart, assuming it's an all-day event
      # @return [Date]
      # @api private
      def _dtstart_all_day_event_as_date
        raise ArgumentError, "dtstart is not an all-day event" unless _dtstart_is_all_day?

        if _dtstart.is_a?(Icalendar::Values::Date)
          _dtstart.to_date
        elsif _dtstart.respond_to?(:to_date)
          _dtstart.to_date
        else
          # Fallback: convert via TimeWithZone
          time_with_zone = _to_time_with_zone(_dtstart)
          raise ArgumentError, "Cannot convert dtstart to date" unless time_with_zone.respond_to?(:to_date)
          time_with_zone.to_date
        end
      end

      ##
      # Heuristic to determine whether the event is scheduled
      # for a date without specifying the exact time of day.
      #
      # Note: This method always returns false for tasks (VTODOs),
      # as the all-day concept only applies to events (VEVENTs).
      #
      # @return [Boolean] true if the component is an Event scheduled for an entire day,
      #                   false for tasks or timed events
      def all_day?
        #todo: determine timezone purely from input parameters (i.e from _dtstart, _dtend, _due)
        return false unless self.is_a?(Icalendar::Event)

        _dtstart.is_a?(Icalendar::Values::Date) ||
          (start_time == start_time.beginning_of_day && end_time == end_time.beginning_of_day)
      end

      ##
      # @return [Boolean] true if the duration of the event spans more than one day.
      def multi_day?
        start_time.next_day.beginning_of_day < end_time
      end

      ##
      # Indicates whether this component represents a single point in time
      # rather than a time range. Common for:
      # - Open-ended events (e.g., concert start time without known end)
      # - Tasks with only a deadline (no start time specified)
      #
      # @return [Boolean] true if the component has no duration
      def single_timestamp?
        #todo: determine timezone purely from input parameters (i.e from _dtstart, _dtend, _due)
        return false if start_time.nil? || end_time.nil? # <--- ???? are never nil ????
        # Compare at second precision (ignore potential microsecond differences)
        start_time.to_i == end_time.to_i
      end

      ##
      # Make sure that we can always query for a _rrule_ array.
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
          next if _recurrence_id == event._recurrence_id # do not add myself
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
        # Calculate the duration of this base event in seconds
        duration_seconds = (end_time.to_i - start_time.to_i)  # Integer seconds

        # Create a schedule with start_time and duration
        # Convert to Ruby Time for IceCube compatibility
        schedule = IceCube::Schedule.new(start_time.to_time.utc, duration: duration_seconds)

        _rrules.each do |rrule|
          ice_cube_recurrence_rule = IceCube::Rule.from_ical(rrule)
          schedule.add_recurrence_rule(ice_cube_recurrence_rule)
        end

        _exdates.each do |ex_time|
          schedule.add_exception_time(ex_time.to_time.utc)
        end

        _overwritten_dates.each do |overwritten_time|
          schedule.add_exception_time(overwritten_time.to_time.utc)
        end

        rdates = _rdates
        rdates.each do |recurrence_time|
          schedule.add_recurrence_time(recurrence_time.to_time.utc)
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
        # Try to extract timezone from the date_time parameter first
        timezone ||= _extract_explicit_timezone(date_time)
        # Fall back to component timezone if no timezone could be extracted
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
          # If DateTime has offset 0, treat it as "floating time" in the target timezone
          # rather than converting from UTC
          if date_time_value.offset.zero?
            return timezone.local(
              date_time_value.year,
              date_time_value.month,
              date_time_value.day,
              date_time_value.hour,
              date_time_value.min,
              date_time_value.sec
            )
          end
          # DateTime with explicit non-zero offset: convert to target timezone
          return date_time_value.in_time_zone(timezone)

        elsif date_time_value.is_a?(Icalendar::Values::Date)
          return _date_to_time_with_zone(date_time_value, timezone)

        elsif date_time_value.is_a?(Date)
          return _date_to_time_with_zone(date_time_value, timezone)

        elsif date_time_value.is_a?(Time)
          # Preserve Time's timezone by converting to UTC first, then to target timezone
          return timezone.at(date_time_value.getutc)

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
      # Converts any time representation to "floating time" (a Time object with UTC-offset=0).
      #
      # Floating time represents "wall clock time" without timezone information,
      # useful for DST-safe recurrence calculations. The time components (year, month, day,
      # hour, minute, second) are preserved, but timezone information is stripped.
      #
      # @param [Object] date_or_time any object representing a time (Icalendar::Values::DateTime,
      #   ActiveSupport::TimeWithZone, Date, Time, Integer, etc.)
      # @param [ActiveSupport::TimeZone,String] target_tz the timezone to interpret the time in
      #   before converting to floating time.
      # @return [Time] a Ruby Time object with UTC offset 0 (floating time)
      # @api private
      #
      # @example Convert a UTC timestamp to floating time in Berlin
      #   # UTC: 2018-01-01 15:00 UTC → Berlin: 2018-01-01 16:00 CET
      #   floating = _to_floating_time(utc_time, ActiveSupport::TimeZone['Europe/Berlin'])
      #   # => 2018-01-01 16:00:00 +0000 (floating)
      def _to_floating_time(date_or_time, target_tz )
        active_target_tz = _active_timezone(target_tz)

        # Convert to TimeWithZone in the target timezone first
        time_with_zone = _to_time_with_zone(date_or_time, active_target_tz)

        # Extract wall-clock components and create floating time (offset 0)
        Time.new(
          time_with_zone.year,
          time_with_zone.month,
          time_with_zone.day,
          time_with_zone.hour,
          time_with_zone.min,
          time_with_zone.sec,
          0  # UTC offset 0 = floating time
        )
      end

      ##
      # Ensures the given `tz` is an ActiveSupport::TimeZone object.
      #
      # If the given timezone name is invalid, logs a warning and returns UTC.
      #
      # @param [ActiveSupport::TimeZone,String] tz a timezone object or timezone name string
      # @return [ActiveSupport::TimeZone] the given timezone object, the timezone with the given name,
      #   or UTC if the given timezone-name is invalid
      # @api private
      def _active_timezone(tz)
        # If already a TimeZone object, return it
        return tz if tz.is_a?(ActiveSupport::TimeZone)

        # Try to lookup by name/value
        result = ActiveSupport::TimeZone[tz]
        return result if result

        # Invalid timezone - log warning and return UTC
        Icalendar::Rrule.logger.warn do
          "[icalendar-rrule] Invalid timezone '#{tz.inspect}' - falling back to UTC"
        end

        # Fallback to UTC
        # Use offset 0 as fallback if even 'UTC' lookup fails (should never happen)
        ActiveSupport::TimeZone['UTC'] || ActiveSupport::TimeZone[0]
      end


      ##
      # Heuristic to determine the best timezone that shall be used in this component.
      # @return [ActiveSupport::TimeZone] the unique timezone used in this component
      # @deprecated there is no unique timezone for a component. Use `timezone_for_start` or `timezone_for_end` instead.
      def component_timezone
        # let's try sequentially, the first non-nil wins.
        timezone ||= _extract_explicit_timezone(_dtend)
        timezone ||= _extract_explicit_timezone(_dtstart)
        timezone ||= _extract_explicit_timezone(_due)
        timezone ||= _extract_calendar_timezone
        timezone ||= _guess_system_timezone

        # as a last resort we'll use the Coordinated Universal Time (UTC).
        timezone || ActiveSupport::TimeZone['UTC']
      end

      ##
      # Determine the timezone that shall be used for `start_time` this component
      # @return [ActiveSupport::TimeZone] the unique timezone used for the start_time of this component
      def _timezone_for_start
        #todo: determine timezone purely from input parameters (i.e from _dtstart, _dtend, _due)
        start_time.time_zone
      end

      ##
      # Determine the timezone that shall be used for `end_time` this component
      # @return [ActiveSupport::TimeZone] the unique timezone used for the end_time of this component
      def _timezone_for_end
        #todo: determine timezone purely from input parameters (i.e from _dtstart, _dtend, _due)
        end_time.time_zone
      end

      ##
      # Try to determine this components time zone by inspecting the parents calendar.
      # @return[ActiveSupport::TimeZone, nil] the first valid timezone found in the
      #    parent calender or nil if none could be found.
      #
      # rubocop:disable Metrics/CyclomaticComplexity
      def _extract_calendar_timezone
        return nil unless parent
        return nil unless parent.is_a?(Icalendar::Calendar)
        calendar_timezones = parent.timezones
        calendar_timezones.each do |tz|
          ugly_tzid = tz.tzid
          break unless ugly_tzid
          tzid = Array(ugly_tzid).first.to_s.gsub(/^(["'])|(["'])$/, '')
          tz_found = ActiveSupport::TimeZone[tzid]
          return tz_found if tz_found
        end
        nil
      rescue StandardError
        nil
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      ##
      # Extracts an explicitly set timezone from the given object.
      #
      # This method only returns a timezone if it was explicitly specified through:
      # - An iCalendar TZID parameter (e.g., tzid: 'Europe/Berlin')
      # - An existing ActiveSupport::TimeWithZone object
      # - A wrapped value that is already a TimeWithZone
      #
      # Unlike _guess_timezone_from_offset, this method does NOT guess or infer
      # timezones from UTC offsets. It returns nil if no explicit timezone is found.
      #
      # @param date_time [Object] an object from which to extract the timezone.
      #   Typically, an Icalendar::Value, Time, DateTime, or ActiveSupport::TimeWithZone.
      # @return [ActiveSupport::TimeZone, nil] the explicitly set timezone, or nil if none found.
      # @api private
      def _extract_explicit_timezone(date_time)
        timezone ||= _extract_ical_time_zone(date_time)      # try with ical TZID parameter (most specific)
        timezone ||= _extract_act_sup_timezone(date_time)    # is the given value already ActiveSupport::TimeWithZone?
        timezone || _extract_value_time_zone(date_time)      # is the ical.value of type ActiveSupport::TimeWithZone?
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
      # Guesses the corresponding ActiveSupport timezone from a given time object's UTC offset.
      # This method extracts the UTC offset from objects that respond to :utc_offset
      # (such as Time, DateTime, or their wrapped values in Icalendar::Values)
      # and matches it to an equivalent ActiveSupport::TimeZone.
      #
      # Note: Since multiple timezones can share the same UTC offset (e.g., Berlin,
      # Amsterdam, Paris all use +01:00), this method returns an arbitrary timezone
      # with the matching offset - hence "guess" rather than "extract".
      #
      # If the input does not respond to :utc_offset or an error occurs during processing,
      # the method returns nil.
      #
      # @param date_time [Object] the object to extract the UTC offset from.
      #   Should respond to :utc_offset (e.g., Time, DateTime, Icalendar::Values::DateTime).
      # @return [ActiveSupport::TimeZone, nil] an ActiveSupport::TimeZone matching the UTC offset,
      #   or nil if no match is found or an error occurs.
      # @api private
      def _guess_timezone_from_offset(date_time)
        # Extract value from Icalendar::Values::DateTime if needed
        value = date_time.is_a?(Icalendar::Value) && date_time.respond_to?(:value) ? date_time.value : date_time

        return nil unless value.respond_to?(:utc_offset)

        # Get the timezone offset from the Time or DateTime object
        offset_seconds = value.utc_offset
        return nil unless offset_seconds.is_a?(Integer)

        # First try: check if the system's default timezone matches the offset
        system_tz = _guess_system_timezone

        # Return `system timezone` if it matches the offset
        return system_tz if system_tz && system_tz.now.utc_offset == offset_seconds

        # Fallback: find any timezone matching the offset
        # For offset 0, always use UTC to avoid ambiguous timezones with DST
        if offset_seconds.zero?
          ActiveSupport::TimeZone['UTC']
        else
          ActiveSupport::TimeZone[offset_seconds]
        end
      rescue StandardError
        nil
      end

      ##
      # Get the timezone from the given object, assuming it can be extracted from ical params.
      # @param [Icalendar::Value] ical_value an ical value that (probably) supports a time zone identifier.
      # @return [ActiveSupport::TimeZone, nil] the timezone referred to by the ical_value or nil.
      # @api private
      def _extract_ical_time_zone(ical_value)
        return nil unless ical_value.is_a?(Icalendar::Value)
        return nil unless ical_value.respond_to?(:ical_params)

        ical_params = ical_value.ical_params
        return nil unless ical_params

        ugly_tzid = ical_params['tzid'] || ical_params[:tzid] || ical_params['TZID'] || ical_params[:TZID]
        return nil if ugly_tzid.nil?

        tzid = Array(ugly_tzid).first.to_s.gsub(/^(["'])|(["'])$/, '')
        return nil if tzid.empty?

        ActiveSupport::TimeZone[tzid]
      rescue StandardError
        # Uncomment for debugging icalendar gem compatibility issues:
        # warn "[icalendar-rrule] Failed to extract timezone: #{e.message}"
        nil
      end

      ##
      # Attempts to determine the system's timezone.
      # Tries multiple methods in order of reliability.
      #
      # @note see also https://rubygems.org/gems/timezone_local - it does about the same as this.
      #
      # @return [ActiveSupport::TimeZone, nil] the system timezone or nil if it cannot be determined.
      # @api private
      def _guess_system_timezone
        # Method 1: Rails/ActiveSupport Time.zone (most reliable if set)
        return Time.zone if Time.zone.is_a?(ActiveSupport::TimeZone)

        # Method 2: ENV['TZ'] environment variable
        if ENV['TZ']
          tz = ActiveSupport::TimeZone[ENV['TZ']]
          return tz if tz
        end

        # Method 3: Try TZInfo if available (optional dependency)
        begin
          require 'tzinfo'
          tz_identifier = TZInfo::Timezone.default_timezone.identifier
          tz = ActiveSupport::TimeZone[tz_identifier]
          return tz if tz
        rescue LoadError, StandardError
          # TZInfo not available or failed, continue
        end

        # Method 4: Read /etc/timezone on Linux (Debian/Ubuntu style)
        if File.readable?('/etc/timezone')
          tz_name = File.read('/etc/timezone').strip
          tz = ActiveSupport::TimeZone[tz_name]
          return tz if tz
        end

        # Method 5: Parse /etc/localtime symlink (common on many Unix systems)
        if File.symlink?('/etc/localtime')
          link = File.readlink('/etc/localtime')
          # Extract timezone name from path like /usr/share/zoneinfo/Europe/Berlin
          if link =~ %r{zoneinfo/(.+)$}
            tz = ActiveSupport::TimeZone[$1]
            return tz if tz
          end
        end

        nil
      rescue StandardError
        nil
      end


    end
  end
end

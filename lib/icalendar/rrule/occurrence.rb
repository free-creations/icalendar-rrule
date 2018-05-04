# frozen_string_literal: true

module Icalendar
  module Rrule
    # A read only view on a component of an iCalendar, such
    # as an event or a task.
    #
    # The base_component can be one of the following:
    # - event
    # - todo
    #
    # The Occurrence delegates the reading of attributes to its underlying
    # base_component.
    #
    # Further it maintains a _start time_ and an _end time_ for the occurrence to happen.
    #
    #
    class Occurrence
      include Comparable

      ##
      # @return [Icalendar::Calendar] the calendar this occurrence is taken from.
      attr_reader :base_calendar
      ##
      # @return [Icalendar::Component] the calendar-component (an event or a task) this occurrence refers to.
      attr_reader :base_component
      ##
      # @return [Icalendar::Values::DateTime] the start of this occurrence.
      attr_reader :occ_start
      ##
      # @return [Icalendar::Values::DateTime] the end of this occurrence.
      attr_reader :occ_end
      ##
      # @return[String] the time-zone that `occ_start` and `occ_end` refer to.
      attr_reader :tzid
      ##
      # Create a new Occurrence instance.
      #
      # @param [Icalendar::Calendar] base_calendar the calendar that holds the component.
      # @param [Icalendar::Component] base_component the underlying calendar-component.
      # @param [Time] occ_start the start-time of this occurrence
      #                   (might be different to the start time of the base_component)
      # @param [Time]  occ_end the end-time  of this occurrence
      #                    (might be different to the end time of the base_component)
      #
      def initialize(base_calendar, base_component, occ_start, occ_end)
        raise ArgumentError, 'base_calendar has wrong class' \
          unless base_calendar.nil? || base_calendar.is_a?(Icalendar::Calendar)
        raise ArgumentError, 'base_component has wrong class' unless base_component.is_a?(Icalendar::Component)
        @base_calendar  = base_calendar
        @base_component = base_component
        @tzid           = tzid_from_component(base_component)
        @occ_start      = time_into_zone(@tzid, occ_start)
        @occ_end        = time_into_zone(@tzid, occ_end)

        super()
      end

      def time_into_zone(zone, time)
        zoned_time = time.in_time_zone(zone)
        Icalendar::Values::DateTime.new(zoned_time, tzid: zone)
      end

      def tzid_from_component(component)
        return tzid_from_dtstart(component) unless tzid_from_dtstart(component).nil?
        return tzid_from_due(component) unless tzid_from_due(component).nil?
        'UTC'
      end

      private def tzid_from_dtstart(component)
        return nil unless component.respond_to? :dtstart
        return nil if component.dtstart.nil?
        ugly_tzid = component.dtstart.ical_params.fetch('tzid', nil)
        return nil if ugly_tzid.nil?

        Array(ugly_tzid).first.to_s.gsub(/^(["'])|(["'])$/, '')
      end

      private def tzid_from_due(component)
        return nil unless component.respond_to? :due
        return nil if component.due.nil?
        ugly_tzid = component.due.ical_params.fetch('tzid', nil)
        return nil if ugly_tzid.nil?

        Array(ugly_tzid).first.to_s.gsub(/^(["'])|(["'])$/, '')
      end

      def method_missing(method_name, *arguments, &block)
        if method_name.to_s[-1, 1] == '='
          # do not allow for setter methods
          super
        else
          # delegate all other requests to the base component
          base_component.send(method_name, *arguments, &block)
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        if method_name.to_s[-1, 1] == '='
          # do not allow to set attributes
          super ## throws no method error
        else
          # delegate all read requests to the base component
          base_component.respond_to?(method_name, include_private)
        end
      end

      ##
      # Compares this occurrence to the other.
      # Comparison is on:
      # 1. occ_start
      # 2. occ_end
      def <=>(other)
        return nil unless other.respond_to? :occ_start
        start_compare = @occ_start.to_datetime <=> other.occ_start.to_datetime
        return start_compare unless start_compare.zero?
        @occ_end.to_datetime <=> other.occ_end.to_datetime
      end
    end
  end
end

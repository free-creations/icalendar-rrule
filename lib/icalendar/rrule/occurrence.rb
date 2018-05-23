# frozen_string_literal: true

module Icalendar
  module Rrule
    ##
    # An Occurrence represents the point of time where an event or any other component of an iCalendar happens.
    #
    # An component with a _repeat rule_ happens several times.
    # Such an event is represented by a set of many Occurrence objects.
    # All these occurrence objects refer to the same component called the base_component.
    #
    # The base_component can be one of the following:
    # - Icalendar::Event
    # - Icalendar::Todo
    #
    # The Occurrence delegates to its underlying
    # base_component.
    #
    # Further it maintains a _start time_ and an _end time_ for the occurrence to happen.
    #
    #
    class Occurrence
      include Comparable
      using Icalendar::Schedulable

      ##
      # @return [Icalendar::Calendar] the calendar this occurrence is taken from.
      attr_reader :base_calendar
      ##
      # @return [Icalendar::Component] the calendar-component (an event or a task) this occurrence refers to.
      attr_reader :base_component
      ##
      # @return [ActiveSupport::TimeWithZone] the start of this occurrence.
      attr_reader :start_time
      ##
      # @return [ActiveSupport::TimeWithZone] the end of this occurrence.
      attr_reader :end_time
      ##

      ##
      # Create a new Occurrence instance.
      #
      # @param [Icalendar::Calendar] base_calendar the calendar that holds the component.
      # @param [Icalendar::Component] base_component the underlying calendar-component.
      # @param [ActiveSupport::TimeWithZone] start_time the time when this occurrence starts.
      #                   (might be different to the start time of the base_component)
      # @param [ActiveSupport::TimeWithZone]  end_time the time when this occurrence starts.
      #                    (might be different to the end time of the base_component)
      #
      def initialize(base_calendar, base_component, start_time, end_time)
        raise ArgumentError, "'base_calendar' not of class 'Icalendar::Calendar'" unless
            base_calendar.nil? || base_calendar.is_a?(Icalendar::Calendar)
        raise ArgumentError, "'base_component' not of class 'Icalendar::Component'" unless
            base_component.is_a?(Icalendar::Component)
        raise ArgumentError, "'start_time' not of class 'ActiveSupport::TimeWithZone'" unless
            start_time.is_a?(ActiveSupport::TimeWithZone)
        raise ArgumentError, "'end_time' not of class 'ActiveSupport::TimeWithZone'" unless
            end_time.is_a?(ActiveSupport::TimeWithZone)

        @base_calendar  = base_calendar
        @base_component = base_component
        @start_time     = start_time
        @end_time       = end_time

        super()
      end

      ##
      # Invoked by Ruby when the Occurrence-object is sent a message it cannot handle.
      #
      # All calls will be  delegated all to the _base component_, except setter requests.
      #
      # @param [String] method_name  the symbol for the method called
      # @param [*object] arguments arguments that were passed to the method.
      # @param [] block
      def method_missing(method_name, *arguments, &block)
        if method_name.to_s[-1, 1] == '='
          # do not allow for setter methods
          super
        else
          # delegate all other requests to the base component
          base_component.send(method_name, *arguments, &block)
        end
      end

      ##
      # Returns true if the Occurrence can respond to the given method, that is, the
      # base component responds to the given method.
      #
      # @param [String] method_name  the symbol for the method called
      # @param include_private
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
      # 1. @start_time
      # 2. @end_time
      def <=>(other)
        return nil unless other.respond_to? :start_time
        return nil unless other.start_time.is_a?(ActiveSupport::TimeWithZone)
        start_compare = @start_time <=> other.start_time
        return start_compare unless start_compare.zero?

        return 0 unless other.respond_to? :end_time
        return 0 unless other.end_time.is_a?(ActiveSupport::TimeWithZone)
        @end_time <=> other.end_time
      end
    end
  end
end

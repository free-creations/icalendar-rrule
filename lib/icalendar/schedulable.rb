# frozen_string_literal: true

module Icalendar
  ##
  # Monkey-patch a constant into class Icalendar::Component.
  # (Unfortunately this cannot be done in a Refinement block)
  class Component
    # use NULL_DATE as default, when no better date is available.
    NULL_DATE = Icalendar::Values::DateTime.new('00000101T000000Z')
  end
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

      def schedule
        nil
      end
    end
  end
end

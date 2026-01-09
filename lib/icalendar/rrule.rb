# frozen_string_literal: true

require 'icalendar'
require 'icalendar/schedulable-component.rb'
require 'icalendar/scannable-calendar'

require 'icalendar/rrule/version'
require 'icalendar/rrule/occurrence'
require 'logger'

module Icalendar
  module Rrule
    class << self
      # Configurable logger for the icalendar-rrule gem.
      # By default, logs nothing (Logger to /dev/null).
      #
      # @example Enable logging to STDOUT
      #   Icalendar::Rrule.logger = Logger.new($stdout)
      #
      # @example Use Rails logger
      #   Icalendar::Rrule.logger = Rails.logger
      #
      # @return [Logger]
      attr_writer :logger

      def logger
        @logger ||= Logger.new(File::NULL)  # default: silent
      end
    end
  end
end

# frozen_string_literal: true

module Icalendar
  ##
  # Refines the  Icalendar::Calendar class by adding
  # the `scan` function to this class.
  #
  # @note [Refinement](https://ruby-doc.org/core-2.5.0/doc/syntax/refinements_rdoc.html)
  # is a _Ruby core feature_ since Ruby 2.0
  #
  module Scannable
    ##
    # Provides _mixin_ methods for the
    # Icalendar::Calendar class
    refine Icalendar::Calendar do
      ##
      # @param[date_time] begin_time
      # @param[date_time] closing_time
      # @param [Set] component_types a list of components that shall be retrieved these can be
      # - :events
      # - :todos
      # Note: `:journals` and `:freebusys` currently not implemented.
      #
      # @return [Array] all occurrences between begin_time and closing_time
      def scan(begin_time, closing_time, component_types = Set[:events])
        @begin_time = begin_time
        @closing_time = closing_time
        @component_types = component_types
        []
      end
    end
  end
end

# frozen_string_literal: true


module Icalendar
  module Scannable
    refine Icalendar::Calendar do
      # @param [Set] component_types a list of components that shall be retrieved these can be
      # - :events
      # - :todos
      # Note: `:journals` and `:freebusys` currently not implemented.
      #
      # @return [Array] all occurrences between begin_time and closing_time
      def scan(begin_time, closing_time, component_types = Set[:events])
        result = []
      end
    end
  end
end
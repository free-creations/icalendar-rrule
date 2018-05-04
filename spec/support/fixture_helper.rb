# frozen_string_literal: true

require 'icalendar'

module FixtureHelper
  ##
  # Reads a file and constructs a calendar-object from
  # the first calendar definition it finds in the given file.
  #
  # @param [String] file_name the name of a file in `spec/support/fixtures/`
  def self.parse_to_calendar(file_name)
    ics_path = File.expand_path "#{File.dirname(__FILE__)}/fixtures/#{file_name}"
    ics_string = File.read(ics_path)
    # Icalendar::Calendar.parse will wrap the calendar into an array
    calendars = Icalendar::Calendar.parse(ics_string)
    # lets make sure we really have a calendar as result.
    result = Array(calendars).first
    raise "Error parsing file #{file_name}" unless result.is_a?(Icalendar::Calendar)
    result
  end

  ##
  # Reads a file and constructs an event-object from
  # the first *event* definition it finds in the first calendar of the given file.
  #
  # @param [String] file_name the name of a file in `spec/support/fixtures/`
  def self.parse_to_first_event(file_name)
    calendar = parse_to_calendar(file_name)
    events = Array(calendar.events)
    raise "#{file_name} has has no events" if events.empty?
    result = events.first
    raise "Error parsing file #{file_name} got #{result.class}, expected Icalendar::Event" \
      unless result.is_a?(Icalendar::Event)
    result
  end

  ##
  # Reads a file and constructs an event-object from
  # the first *todo* definition it finds in the first calendar of the given file.
  #
  # @param [String] file_name the name of a file in `spec/support/fixtures/`
  def self.parse_to_first_task(file_name)
    calendar = parse_to_calendar(file_name)
    tasks = Array(calendar.todos)
    raise "#{file_name} has has no tasks" if tasks.empty?
    result = tasks.first
    raise "Error parsing file '#{file_name}' got '#{result.class}' but expected 'Icalendar::Todo'." \
      unless result.is_a?(Icalendar::Todo)
    result
  end
end

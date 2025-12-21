# frozen_string_literal: true

require 'icalendar/rrule' # the gem under test

##
# Tests for Icalendar::Rrule::Occurrence class.
#
# The Occurrence class wraps iCalendar components (Events, Todos, etc.) and provides:
# - Normalized time handling (start_time and end_time as ActiveSupport::TimeWithZone)
# - Attribute delegation to the underlying component
# - Immutability (read-only)
# - Comparability (sorting by start_time, then end_time)
#
# These tests verify that Occurrence provides a consistent interface regardless of
# the underlying component type.
RSpec.describe Icalendar::Rrule::Occurrence do
  using Icalendar::Schedulable

  zone = ActiveSupport::TimeZone['Europe/Busingen'] # the system-timezone used in the test fixtures

  # Run the same test suite for both Events and Todos to ensure consistent behavior
  # across different component types.
  [FixtureHelper.parse_to_first_event('daily_event.ics'),
   FixtureHelper.parse_to_first_task('daily_task.ics')].each do |base_component|

    context "when the base component is #{base_component.class.name}" do
      subject(:occurrence) { described_class.new(nil, base_component, time_1, time_2) }

      # Define test times in a specific timezone for consistency
      let(:time_1) { zone.parse('2018-04-01 15:30:45') }
      let(:time_2) { zone.parse('2018-04-02 15:30:45') }
      let(:time_3) { zone.parse('2018-04-03 15:30:45') }
      let(:time_4) { zone.parse('2018-04-04 15:30:45') }

      # Helper occurrences for comparison tests
      let(:start_later) { described_class.new(nil, base_component, time_3, time_4) }
      let(:end_later) { described_class.new(nil, base_component, time_1, time_4) }

      describe 'attribute delegation' do
        it 'delegates attribute reading to the base component' do
          is_expected.to have_attributes(
                           summary: base_component.summary,
                           uid: base_component.uid,
                           dtstamp: base_component.dtstamp
                         )
        end

        it 'responds to attributes inherited from the base component' do
          is_expected.to respond_to(:uid)
        end

        it 'does not respond to attributes the base component does not have' do
          is_expected.not_to respond_to(:foo)
        end

        it 'responds to optional properties such as contact' do
          is_expected.to respond_to(:contact)
        end

        it 'responds to custom properties such as x_foo' do
          is_expected.to respond_to(:x_foo)
        end
      end

      describe 'normalized time properties' do
        it 'provides start_time as ActiveSupport::TimeWithZone' do
          expect(occurrence.start_time).to be_a(ActiveSupport::TimeWithZone)
        end

        it 'provides end_time as ActiveSupport::TimeWithZone' do
          expect(occurrence.end_time).to be_a(ActiveSupport::TimeWithZone)
        end
      end

      describe 'immutability' do
        it 'does not allow setting attributes' do
          expect { occurrence.uid = 'abc' }.to raise_error(NoMethodError)
        end

        it 'does not respond to setter methods' do
          is_expected.not_to respond_to('uid=')
        end
      end

      describe 'default values for optional properties' do
        it 'returns nil for uninitialized single optional properties' do
          expect(occurrence.location).to be_nil
        end

        it 'returns empty array for uninitialized multiple optional properties' do
          expect(occurrence.contact).to eq([])
        end

        it 'returns empty array for uninitialized custom properties' do
          expect(occurrence.x_foo).to eq([])
        end
      end

      describe 'comparison and sorting' do
        it 'compares as less than an occurrence that starts later' do
          is_expected.to be < start_later
        end

        it 'compares as less than an occurrence with same start but later end time' do
          is_expected.to be < end_later
        end
      end
    end
  end

  context 'with timezone-aware events' do
    using Icalendar::Schedulable

    context 'with an event spanning multiple timezones' do
      subject(:flight) do
        calendar = Icalendar::Calendar.new
        calendar.timezone do |tz|
          tz.tzid = 'Europe/Berlin'
        end

        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::DateTime.new('20180422T100000', tzid: 'Europe/Berlin')
        event.dtend = Icalendar::Values::DateTime.new('20180422T120000', tzid: 'America/New_York')
        event.summary = 'Flight to New York'

        calendar.add_event(event)
        calendar.events.first
      end

      it 'preserves Berlin timezone for start_time' do
        expect(flight.start_time.time_zone.name).to eq('Europe/Berlin')
        expect(flight.start_time.hour).to eq(10)
      end

      it 'preserves New York timezone for end_time' do
        expect(flight.end_time.time_zone.name).to eq('America/New_York')
        expect(flight.end_time.hour).to eq(12)
      end

      it 'calculates flight duration as 8 hours' do
        duration_hours = (flight.end_time.to_i - flight.start_time.to_i) / 3600
        expect(duration_hours).to be_within(0.1).of(8.0)
      end
    end
  end

  context 'with an event without explicit timezone in a calendar with timezone' do
    subject(:meeting) do
      calendar = Icalendar::Calendar.new
      calendar.timezone do |tz|
        tz.tzid = 'America/Caracas'
      end

      # Event without tzid parameter - should inherit from calendar
      event = Icalendar::Event.new
      event.dtstart = Icalendar::Values::DateTime.new('20180422T143000') # no tzid!
      event.dtend = Icalendar::Values::DateTime.new('20180422T153000') # no tzid!
      event.summary = 'Meeting in Caracas'

      calendar.add_event(event)
      calendar.events.first
    end

    it 'inherits Caracas timezone from calendar for start_time' do
      expect(meeting.start_time.time_zone.name).to eq('America/Caracas')
      expect(meeting.start_time.hour).to eq(14)
      expect(meeting.start_time.min).to eq(30)
    end

    it 'inherits Caracas timezone from calendar for end_time' do
      expect(meeting.end_time.time_zone.name).to eq('America/Caracas')
      expect(meeting.end_time.hour).to eq(15)
      expect(meeting.end_time.min).to eq(30)
    end

    it 'calculates meeting duration as 1 hour' do
      duration_hours = (meeting.end_time.to_i - meeting.start_time.to_i) / 3600.0
      expect(duration_hours).to be_within(0.01).of(1.0)
    end
  end

  context 'with an event without explicit timezone in a calendar without timezone' do
    using Icalendar::Schedulable

    context 'when using Ruby Time.new (implicit system timezone)' do
      subject(:meeting_with_time) do
        calendar = Icalendar::Calendar.new
        # No calendar timezone set

        event = Icalendar::Event.new
        # Ruby Time.new without offset uses system timezone
        event.dtstart = Time.new(2018, 1, 1, 8, 30)
        event.dtend = Time.new(2018, 1, 1, 9, 30)
        event.summary = 'Morning Meeting'

        calendar.add_event(event)
        calendar.events.first
      end

      it 'preserves the system timezone offset for start_time' do
        input_offset = Time.new(2018, 1, 1, 8, 30).utc_offset
        output_offset = meeting_with_time.start_time.utc_offset

        expect(output_offset).to eq(input_offset)
        expect(meeting_with_time.start_time.hour).to eq(8)
        expect(meeting_with_time.start_time.min).to eq(30)
      end

      it 'preserves the system timezone offset for end_time' do
        input_offset = Time.new(2018, 1, 1, 9, 30).utc_offset
        output_offset = meeting_with_time.end_time.utc_offset

        expect(output_offset).to eq(input_offset)
        expect(meeting_with_time.end_time.hour).to eq(9)
        expect(meeting_with_time.end_time.min).to eq(30)
      end

      it 'calculates meeting duration as 1 hour' do
        duration_hours = (meeting_with_time.end_time.to_i - meeting_with_time.start_time.to_i) / 3600.0
        expect(duration_hours).to be_within(0.01).of(1.0)
      end
    end

    context 'when using DateTime.civil (implicit UTC/floating time)' do
      subject(:meeting_with_datetime) do
        calendar = Icalendar::Calendar.new
        # No calendar timezone set

        event = Icalendar::Event.new
        # DateTime.civil without offset defaults to offset 0 (treated as floating time)
        event.dtstart = DateTime.civil(2018, 1, 1, 8, 30)
        event.dtend = DateTime.civil(2018, 1, 1, 9, 30)
        event.summary = 'Morning Meeting'

        calendar.add_event(event)
        calendar.events.first
      end

      it 'uses system timezone for start_time (floating time behavior)' do
        # DateTime with offset 0 is treated as floating time and interpreted in system TZ
        expect(meeting_with_datetime.start_time.hour).to eq(8)
        expect(meeting_with_datetime.start_time.min).to eq(30)

        # Should use system timezone, not UTC
        system_tz_name = meeting_with_datetime.start_time.time_zone.name
        expect(system_tz_name).not_to eq('UTC')
      end

      it 'uses system timezone for end_time (floating time behavior)' do
        expect(meeting_with_datetime.end_time.hour).to eq(9)
        expect(meeting_with_datetime.end_time.min).to eq(30)

        # Should use system timezone, not UTC
        system_tz_name = meeting_with_datetime.end_time.time_zone.name
        expect(system_tz_name).not_to eq('UTC')
      end

      it 'calculates meeting duration as 1 hour' do
        duration_hours = (meeting_with_datetime.end_time.to_i - meeting_with_datetime.start_time.to_i) / 3600.0
        expect(duration_hours).to be_within(0.01).of(1.0)
      end
    end
  end

  context 'with recurring events (RRULE expansion)' do
    using Icalendar::Schedulable
    using Icalendar::Scannable

    context 'when event has RRULE and explicit timezone' do
      subject(:calendar_with_rrule) do
        calendar = Icalendar::Calendar.new
        calendar.timezone do |tz|
          tz.tzid = 'Europe/Berlin'
        end

        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::DateTime.new('20180101T090000', tzid: 'Europe/Berlin')
        event.dtend = Icalendar::Values::DateTime.new('20180101T110000', tzid: 'Europe/Berlin')
        event.rrule = 'FREQ=DAILY;COUNT=3'
        event.summary = 'Daily Meeting'

        calendar.add_event(event)
        calendar
      end

      let(:scan_start) { Date.new(2018, 1, 1) }
      let(:scan_end) { Date.new(2018, 1, 10) }
      let(:occurrences) { calendar_with_rrule.scan(scan_start, scan_end) }

      it 'generates 3 occurrences' do
        expect(occurrences.length).to eq(3)
      end

      [0, 1, -1].each do |i|
        describe "occurrence[#{i}]" do
          subject(:occurrence) { occurrences[i] }

          it 'preserves Berlin timezone' do
            expect(occurrence.start_time.time_zone.name).to eq('Europe/Berlin')
          end

          it 'starts at 9:00' do
            expect(occurrence.start_time.hour).to eq(9)
          end

          it 'ends at 11:00' do
            expect(occurrence.end_time.hour).to eq(11)
          end
        end
      end
    end

    context 'when event has RRULE in exotic timezone (Nepal UTC+5:45)' do
      subject(:calendar_with_rrule) do
        calendar = Icalendar::Calendar.new
        # No calendar timezone set

        event = Icalendar::Event.new
        # Nepal has UTC+5:45 offset (one of the few 45-minute offsets!)
        event.dtstart = Icalendar::Values::DateTime.new('20180101T090000', tzid: 'Asia/Kathmandu')
        event.dtend = Icalendar::Values::DateTime.new('20180101T110000', tzid: 'Asia/Kathmandu')
        event.rrule = 'FREQ=DAILY;BYDAY=MO,FR'
        event.summary = 'Monday/Friday Meeting in Nepal'

        calendar.add_event(event)
        calendar
      end

      # Scan 2025 (base event is in 2018, so NOT in scan range!)
      let(:scan_start) { Date.new(2025, 1, 1) }
      let(:scan_end) { Date.new(2025, 12, 31) }
      let(:occurrences) { calendar_with_rrule.scan(scan_start, scan_end) }

      it 'generates many occurrences' do
        expect(occurrences.length).to be > 100
      end

      # Test first, middle, and last occurrence
      [0, 50, -1].each do |i|
        describe "occurrence[#{i}] when base event not in scan range" do
          subject(:occurrence) { occurrences[i] }

          it 'preserves Kathmandu timezone with 45-minute offset' do
            expect(occurrence.start_time.time_zone.name).to eq('Asia/Kathmandu')
            # Check the unusual offset (5 hours 45 minutes = 20700 seconds)
            expect(occurrence.start_time.utc_offset).to eq(20700)
          end

          it 'starts at 9:00' do
            expect(occurrence.start_time.hour).to eq(9)
            expect(occurrence.start_time.min).to eq(0)
          end

          it 'ends at 11:00' do
            expect(occurrence.end_time.hour).to eq(11)
            expect(occurrence.end_time.min).to eq(0)
          end
        end
      end
    end

  end

  context 'with all-day events (VALUE=DATE)' do
    using Icalendar::Schedulable
    using Icalendar::Scannable

    context 'when all-day event has RRULE (yearly birthday)' do
      subject(:calendar_with_birthday) do
        calendar = Icalendar::Calendar.new

        event = Icalendar::Event.new
        # All-day event (VALUE=DATE)
        event.dtstart = Date.new(2018, 7, 4)
        event.dtend = Date.new(2018, 7, 5)
        event.rrule = 'FREQ=YEARLY'
        event.summary = 'Birthday'

        calendar.add_event(event)
        calendar
      end

      let(:scan_start) { Date.new(2020, 1, 1) }
      let(:scan_end) { Date.new(2025, 12, 31) }
      let(:occurrences) { calendar_with_birthday.scan(scan_start, scan_end) }


      it 'generates yearly occurrences' do
        expect(occurrences.length).to eq(6)  # 2020-2025
      end

      [0, 2, -1].each do |i|
        describe "occurrence[#{i}]" do
          subject(:occurrence) { occurrences[i] }

          it 'identifies as all-day event' do
            expect(occurrence.all_day?).to be true
          end

          it 'identifies as not multi-day' do
            expect(occurrence.multi_day?).to be false
          end

          it 'stays on July 4th (not shifted by timezone)' do
            expect(occurrence.start_time.month).to eq(7)
            expect(occurrence.start_time.day).to eq(4)
          end

          it 'starts at midnight' do
            expect(occurrence.start_time.hour).to eq(0)
            expect(occurrence.start_time.min).to eq(0)
          end

          it 'ends on July 5th at midnight' do
            expect(occurrence.end_time.month).to eq(7)
            expect(occurrence.end_time.day).to eq(5)
            expect(occurrence.end_time.hour).to eq(0)
          end
        end
      end
    end

    context 'when all-day event without DTEND (implicit 1-day duration)' do
      subject(:calendar_with_birthday) do
        calendar = Icalendar::Calendar.new

        event = Icalendar::Event.new
        event.dtstart = Date.new(2018, 7, 4)
        # NO dtend - RFC says duration should be 1 day
        event.rrule = 'FREQ=YEARLY'
        event.summary = 'Birthday (no end date)'

        calendar.add_event(event)
        calendar
      end

      let(:scan_start) { Date.new(2020, 1, 1) }
      let(:scan_end) { Date.new(2025, 12, 31) }
      let(:occurrences) { calendar_with_birthday.scan(scan_start, scan_end) }

      [0, 2, -1].each do |i|
        describe "occurrence[#{i}]" do
          subject(:occurrence) { occurrences[i] }

          it 'has implicit 1-day duration' do
            duration_days = (occurrence.end_time.to_i - occurrence.start_time.to_i) / 86400.0
            expect(duration_days).to eq(1.0)
          end

          it 'starts on July 4th at midnight' do
            expect(occurrence.start_time.month).to eq(7)
            expect(occurrence.start_time.day).to eq(4)
            expect(occurrence.start_time.hour).to eq(0)
          end

          it 'ends on July 5th at midnight' do
            expect(occurrence.end_time.month).to eq(7)
            expect(occurrence.end_time.day).to eq(5)
            expect(occurrence.end_time.hour).to eq(0)
          end
        end
      end
    end

    context 'when all-day event spans multiple days (vacation)' do
      subject(:calendar_with_vacation) do
        calendar = Icalendar::Calendar.new

        event = Icalendar::Event.new
        # 3-day vacation
        event.dtstart = Date.new(2025, 8, 1)
        event.dtend = Date.new(2025, 8, 4)  # Aug 1-3 (end is exclusive)
        event.summary = 'Summer Vacation'

        calendar.add_event(event)
        calendar
      end

      let(:vacation_event) { calendar_with_vacation.events.first }

      it 'identifies as all-day' do
        expect(vacation_event.all_day?).to be true
      end

      it 'identifies as multi-day' do
        expect(vacation_event.multi_day?).to be true
      end
    end
  end

      #todo: add tests for Tasks without start or end

end

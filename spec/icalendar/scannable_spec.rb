# frozen_string_literal: true

require 'icalendar/rrule'

RSpec.describe Icalendar::Scannable do
  using described_class
  context 'when the underlying calendar uses timezones' do
    subject(:calendar_scan) do
      calendar.scan(begin_time, closing_time)
    end

    let(:calendar) do
      # create an empty calendar
      cal = Icalendar::Calendar.new
      # add repeating events to this calendar
      cal.event do |e|
        # all bi-weekly meetings start at ten o'clock in the morning in time zone America/New_York
        e.dtstart = Icalendar::Values::DateTime.new('20000101T100000', tzid: 'America/New_York')
        # all bi-weekly meetings end at eleven o'clock in time zone America/New_York
        e.dtend = Icalendar::Values::DateTime.new('20000101T110000', tzid: 'America/New_York')
        e.summary = 'Monday/Friday Meeting'
        # the meetings take place every monday and every friday
        e.rrule = Icalendar::Values::Recur.new('FREQ=DAILY;BYDAY=MO,FR')
      end
      return cal
    end

    # lets iterate over the whole year 2018
    # Be aware of Daylight Saving Time for America/New_York:
    #   Start DST: Sunday, 11 March 2018 => 1 hour forward
    #   End DST: Sunday, 4 November 2018 => 1 hour backward
    let(:begin_time) { Date.new(2018, 1, 1) }
    let(:closing_time) { Date.new(2019, 1, 1) }

    it 'is has over 100 entries within the test time elapse' do
      expect(calendar_scan.size).to be > 100
    end

    [1, 60, -1].each do |i| # lets check for several entries; one at the beginning and one in the middle of the year
      describe "occurrence[#{i}] of this scan" do
        subject(:occurrence) do
          calendar_scan[i]
        end

        it 'lives in the same time-zone as its underlying calendar' do
          expect(occurrence.time_zone.name).to eq('America/New_York')
        end

        it "starts at the same time as its underlying event (eight o'clock in the morning)" do
          expect(occurrence.start_time.strftime('%H:%M')).to eq('10:00')
        end

        it "ends at the same time as its underlying event (five o'clock in the afternoon)" do
          expect(occurrence.end_time.strftime('%H:%M')).to eq('11:00')
        end
      end
    end
  end
  context 'when the underlying calendar has exclusively events' do
    subject(:calendar) { FixtureHelper.parse_to_calendar('daily_event.ics') }

    let(:begin_time) { Date.parse('2018-04-01') }
    let(:end_time) { Date.parse('2018-05-01') }

    let(:t_1) { Date.parse('2018-04-01') }
    let(:t_2) { Date.parse('2018-04-02') }

    let(:t_4) { Date.parse('2018-01-01') }
    let(:t_5) { Date.parse('2018-01-02') }

    let(:t_6) { Date.parse('2018-06-01') }
    let(:t_7) { Date.parse('2018-06-02') }

    specify 'the calendar provided by the fixture contains exactly *one* event' do
      # It may seem silly to verify the fixture. But it took me hours to discover an error in the fixture...
      expect(calendar.events.size).to eq(1)
    end

    specify 'the single event from the fixture is scheduled on 2018-03-28 noon in Berlin' do
      # It may seem silly to verify the fixture. But it took me hours to discover an error in the fixture...
      expect(calendar.events.first.dtstart.to_ical(nil)).to \
        eq(Icalendar::Values::DateTime.new('20180328T120000', tzid: 'Europe/Berlin').to_ical(nil))
    end

    specify 'the calendar provided by the fixture contains *no* tasks (todos)' do
      # It may seem silly to verify the fixture. But it took me hours to discover an error in the fixture...
      expect(calendar.todos.size).to eq(0)
    end

    specify '`#scan` always returns something enumerable (even when end comes before start)' do
      expect(calendar.scan(end_time, begin_time)).to respond_to(:each)
    end

    it 'returns zero events if the time span is before March' do
      expect(calendar.scan(t_4, t_5).size).to eq(0)
    end

    it 'returns zero tasks if the time span is before March' do
      expect(calendar.scan(t_4, t_5, %i[todos]).size).to eq(0)
    end

    it 'returns zero tasks if the time span is after April' do
      expect(calendar.scan(t_6, t_7, %i[todos]).size).to eq(0)
    end
    it 'returns one event between first and second of April' do
      expect(calendar.scan(t_1, t_2).size).to eq(1)
    end

    it 'returns 30 daily events between first of April and first of May' do
      expect(calendar.scan(begin_time, end_time).size).to eq(30)
    end
    it 'returns 30 daily events when called with `:events` and `:todos` parameter' do
      expect(calendar.scan(begin_time, end_time, %i[events todos]).size).to eq(30)
    end
    it 'returns 0 tasks when called with only `:todos` parameter' do
      expect(calendar.scan(begin_time, end_time, [:todos]).size).to eq(0)
    end
    it 'raises an error when called with wrong parameter `:foos`' do
      expect { calendar.scan(begin_time, end_time, [:foos]) }.to raise_error(ArgumentError)
    end
  end

  context 'when the underlying calendar has exclusively tasks' do
    subject(:calendar) { FixtureHelper.parse_to_calendar('daily_task.ics') }

    let(:begin_time) { Date.parse('2018-04-01') }
    let(:end_time) { Date.parse('2018-05-01') }

    let(:t_1) { Date.parse('2018-04-01') }
    let(:t_2) { Date.parse('2018-04-02') }

    let(:t_4) { Date.parse('2018-01-01') }
    let(:t_5) { Date.parse('2018-01-02') }

    let(:t_6) { Date.parse('2018-06-01') }
    let(:t_7) { Date.parse('2018-06-02') }

    specify 'the calendar provided by the fixture contains exactly *one* task (todo)' do
      # It may seem silly to verify the fixture. But it took me hours to discover an error in the fixture...
      expect(calendar.todos.size).to eq(1)
    end

    specify 'the single task from the fixture is scheduled on 2018-03-28 noon' do
      # It may seem silly to verify the fixture. But it took me hours to discover an error in the fixture...
      expect(calendar.todos.first.dtstart.to_ical(nil)).to \
        eq(Icalendar::Values::DateTime.new('20180328T120000', tzid: 'Europe/Berlin').to_ical(nil))
    end

    specify 'the calendar provided by the fixture contains *no* events' do
      # It may seem silly to verify the fixture. But it took me hours to discover an error in the fixture...
      expect(calendar.events.size).to eq(0)
    end

    specify '`#scan` always returns something enumerable (even when start comes before end)' do
      expect(calendar.scan(end_time, begin_time)).to respond_to(:each)
    end

    it 'returns zero tasks if the time span is before March' do
      expect(calendar.scan(t_4, t_5, %i[todos]).size).to eq(0)
    end

    it 'returns zero events if the time span is before March' do
      expect(calendar.scan(t_4, t_5).size).to eq(0)
    end

    it 'returns zero events if the time span is after April' do
      expect(calendar.scan(t_6, t_7, %i[events]).size).to eq(0)
    end
    it 'returns one task between first and second of April' do
      expect(calendar.scan(t_1, t_2, %i[todos]).size).to eq(1)
    end
    it 'returns 30 task occurrences between first of April and first of May' do
      expect(calendar.scan(begin_time, end_time, %i[todos]).size).to eq(30)
    end
    specify 'the first of these occurrences is on first of April  at noon' do
      expect(calendar.scan(begin_time, end_time, %i[todos]).first.start_time).to  \
        eq(Icalendar::Values::DateTime.new('20180401T120000', tzid: 'Europe/Berlin'))
    end

    specify 'the last of these occurrences is on April 30th at noon' do
      expect(calendar.scan(begin_time, end_time, %i[todos])[-1].start_time).to  \
        eq(Icalendar::Values::DateTime.new('20180430T120000', tzid: 'Europe/Berlin'))
    end
    it 'returns 30 task occurrences when called with `:events` and `:todos` parameter' do
      expect(calendar.scan(begin_time, end_time, %i[events todos]).size).to eq(30)
    end
    it 'returns 0 occurrences when called with only `:events` parameter' do
      expect(calendar.scan(begin_time, end_time, [:events]).size).to eq(0)
    end
    it 'raises an error when called with wrong parameter `:foos`' do
      expect { calendar.scan(begin_time, end_time, [:foos]) }.to raise_error(ArgumentError)
    end
  end

  context 'when the calendar has repeating events with excluded dates (two separate entries)' do
    subject(:calendar) { FixtureHelper.parse_to_calendar('exdate.ics') }

    let(:begin_time) { Date.parse('2018-05-24') }
    let(:end_time) { Date.parse('2018-06-16') }

    specify 'the calendar provided by the fixture contains exactly *one* event' do
      # ..verify the fixture.
      expect(calendar.events.size).to eq(1)
    end

    it '#scan returns two event-occurrences in the time span' do
      expect(calendar.scan(begin_time, end_time, %i[events]).size).to eq(2)
    end
  end

  context 'when the calendar has repeating events with excluded dates(one comma separated list)' do
    subject(:calendar) { FixtureHelper.parse_to_calendar('exdate_2.ics') }

    let(:begin_time) { Date.parse('2018-05-24') }
    let(:end_time) { Date.parse('2018-06-16') }

    specify 'the calendar provided by the fixture contains exactly *one* event' do
      # ..verify the fixture.
      expect(calendar.events.size).to eq(1)
    end

    it '#scan returns two event-occurrences in the time span' do
      expect(calendar.scan(begin_time, end_time, %i[events]).size).to eq(2)
    end
  end
  context 'when the calendar uses RDATE to repeat entries (one comma separated list)' do
    subject(:calendar) { FixtureHelper.parse_to_calendar('rdate_2.ics') }

    let(:begin_time) { Date.parse('2018-05-24') }
    let(:end_time) { Date.parse('2018-06-16') }

    # rubocop:disable RSpec/MultipleExpectations
    specify 'the calendar provided by the fixture contains exactly *one* event' do
      # ..verify the fixture.
      expect(calendar.events.size).to eq(1)
      expect(calendar.events[0].rdate[0]).to be_a_kind_of(Icalendar::Values::Array)
      expect(calendar.events[0].rdate[0].size).to eq(2)
    end
    # rubocop:enable RSpec/MultipleExpectations

    it '#scan returns three event-occurrences in the time span' do
      expect(calendar.scan(begin_time, end_time, %i[events]).size).to eq(3)
    end
  end
  context 'when the calendar uses RDATE to repeat entries (two separate entries)' do
    subject(:calendar) { FixtureHelper.parse_to_calendar('rdate.ics') }

    let(:begin_time) { Date.parse('2018-05-24') }
    let(:end_time) { Date.parse('2018-06-16') }

    # rubocop:disable RSpec/MultipleExpectations
    specify 'the calendar provided by the fixture contains exactly *one* event' do
      # ..verify the fixture.
      expect(calendar.events.size).to eq(1)
      expect(calendar.events[0].rdate).to be_a_kind_of(Array)
      expect(calendar.events[0].rdate.size).to eq(2)
    end
    # rubocop:enable RSpec/MultipleExpectations

    it '#scan returns three event-occurrences in the time span' do
      expect(calendar.scan(begin_time, end_time, %i[events]).size).to eq(3)
    end
  end
  context 'when the calendar uses RECURRENCE-ID to overwrite some occurrences' do
    subject(:calendar) { FixtureHelper.parse_to_calendar('exception.ics') }

    let(:begin_time) { Date.parse('2018-05-25') }
    let(:end_time)   { Date.parse('2018-06-10') }

    # rubocop:disable RSpec/MultipleExpectations
    specify 'the calendar provided by the fixture contains exactly *one* event' do
      # ..verify the fixture.
      expect(calendar.events.size).to eq(2)
      expect(calendar.events[0].rrule).to be_truthy
      expect(calendar.events[1].recurrence_id).to be_truthy # <<< the second event overwrites a regular recurrence.
    end
    # rubocop:enable RSpec/MultipleExpectations

    it '#scan returns three event-occurrences in the time span' do
      expect(calendar.scan(begin_time, end_time, %i[events]).size).to eq(3)
    end
  end
end

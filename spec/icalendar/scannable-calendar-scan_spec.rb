# frozen_string_literal: true

require 'icalendar/rrule'
using Icalendar::Scannable

RSpec.context 'when `using Icalendar::Schedulable::scan`' do

  context 'when the calendar and all it events live in the system timezone' do

    let(:time_zone) { 'Europe/Berlin' }
    let(:begin_time) { Date.parse('2018-05-24') }
    let(:end_time) { Date.parse('2018-06-16') }

    let(:calendar) do
      cal = Icalendar::Calendar.new
      cal.timezone do |tz|
        tz.tzid = time_zone
      end
      cal.event do |e|
        e.dtstart = Icalendar::Values::DateTime.new('20180525T140000', tzid: time_zone)
        e.dtend = Icalendar::Values::DateTime.new('20180525T150000', tzid: time_zone)
        e.summary = 'Event happens on 25.5.2018 and 15.6.2018. But not on 1.6.2018. and not on 8.6.2018'
        e.rrule = Icalendar::Values::Recur.new('FREQ=WEEKLY;UNTIL=20180615T120000Z')
        e.exdate = ['20180608T120000Z', '20180601T120000Z']
      end
      cal
    end

    specify 'the calendar provided contains exactly one event' do
      expect(calendar.events.size).to eq(1)
    end

    describe 'the scan' do
      let(:scan) { calendar.scan(begin_time, end_time, %i[events]) }

      it 'returns two event-occurrences in the time span' do
        expect(scan.size).to eq(2)
      end

      describe 'the first event' do
        let(:first_event) { scan.first }

        it 'has a summary' do
          expect(first_event.summary).to eq('Event happens on 25.5.2018 and 15.6.2018. But not on 1.6.2018. and not on 8.6.2018')
        end

        it 'start_time is a ActiveSupport::TimeZone' do
          expect(first_event.start_time).to be_a(ActiveSupport::TimeWithZone)
        end

        it 'happens on 25.5.2018' do
          expect(first_event.start_time.to_date).to eq(Date.parse('2018-05-25'))
        end

        it 'starts at 14:00' do
          expect(first_event.start_time.hour).to eq(14)
          expect(first_event.start_time.min).to eq(0)
        end

        it "lives in Europe/Berlin" do
          expect(first_event.start_time.time_zone.name).to eq(time_zone)
        end
      end
    end
  end

  context 'when the calendar and all it events live outside system-timezone' do

    let(:time_zone) { 'America/Caracas' }
    let(:begin_time) { Date.parse('2018-05-24') }
    let(:end_time) { Date.parse('2018-06-17') }

    let(:calendar) do
      cal = Icalendar::Calendar.new
      cal.timezone do |tz|
        tz.tzid = time_zone
      end
      cal.event do |e|
        e.dtstart = Icalendar::Values::DateTime.new('20180525T140000', tzid: time_zone)
        e.dtend = Icalendar::Values::DateTime.new('20180525T150000', tzid: time_zone)
        e.summary = 'Event happens on 25.5.2018 and 15.6.2018. But not on 1.6.2018. and not on 8.6.2018'
        e.rrule = Icalendar::Values::Recur.new('FREQ=WEEKLY;UNTIL=20180615T180000Z')
        # exclude two dates (the 1.6.2018 and 8.6.2018)
        # note: the time is in UTC so event starts at 18 UTC
        e.exdate = ['20180608T180000Z', '20180601T180000Z']
      end
      cal
    end

    specify 'the calendar provided contains exactly one base event' do
      expect(calendar.events.size).to eq(1)
    end

    describe 'the scan' do
      let(:scan) { calendar.scan(begin_time, end_time, %i[events]) }

      it 'pretty prints to', skip: 'debugging only' do
        scan.each do |occurrence|
          puts "#{occurrence.start_time} -> #{occurrence.end_time}"
        end
      end

      it 'returns two event-occurrences in the time span' do
        expect(scan.size).to eq(2)
      end

      describe 'the first event' do
        let(:first_event) { scan.first }

        it 'has a summary' do
          expect(first_event.summary).to eq('Event happens on 25.5.2018 and 15.6.2018. But not on 1.6.2018. and not on 8.6.2018')
        end

        it 'start_time is a ActiveSupport::TimeZone' do
          expect(first_event.start_time).to be_a(ActiveSupport::TimeWithZone)
        end

        it 'happens on 25.5.2018' do
          expect(first_event.start_time.to_date).to eq(Date.parse('2018-05-25'))
        end

        it 'starts at 14:00' do
          expect(first_event.start_time.hour).to eq(14)
          expect(first_event.start_time.min).to eq(0)
        end

        it "lives in America/Caracas" do
          expect(first_event.start_time.time_zone.name).to eq(time_zone)
        end
      end

      describe 'the last event' do
        let(:last_event) { scan.last }

        it 'has a summary' do
          expect(last_event.summary).to eq('Event happens on 25.5.2018 and 15.6.2018. But not on 1.6.2018. and not on 8.6.2018')
        end

        it 'start_time is a ActiveSupport::TimeZone' do
          expect(last_event.start_time).to be_a(ActiveSupport::TimeWithZone)
        end

        it 'happens on 15.6.2018' do
          expect(last_event.start_time.to_date).to eq(Date.parse('2018-06-15'))
        end

        it 'starts at 14:00' do
          expect(last_event.start_time.hour).to eq(14)
          expect(last_event.start_time.min).to eq(0)
        end

        it "lives in Europe/Berlin" do
          expect(last_event.start_time.time_zone.name).to eq(time_zone)
        end
      end
    end
  end

  context 'when the calendar has no rrule events' do

    let(:time_zone) { 'America/Caracas' }
    let(:begin_time) { Date.parse('2018-06-24') }
    let(:end_time) { Date.parse('2018-06-26') }

    let(:calendar) do
      cal = Icalendar::Calendar.new
      cal.timezone do |tz|
        tz.tzid = time_zone
      end

      cal.event do |e|
        e.dtstart = Icalendar::Values::DateTime.new('20180525T140000', tzid: time_zone)
        e.dtend = Icalendar::Values::DateTime.new('20180525T150000', tzid: time_zone)
        e.summary = 'Event 1, before the begin_time of the scan'
      end

      cal.event do |e|
        e.dtstart = Icalendar::Values::DateTime.new('20180625T140000', tzid: time_zone)
        e.dtend = Icalendar::Values::DateTime.new('20180625T150000', tzid: time_zone)
        e.summary = 'Event 2, within the scan'
      end

      cal.event do |e|
        e.dtstart = Icalendar::Values::DateTime.new('20180725T140000', tzid: time_zone)
        e.dtend = Icalendar::Values::DateTime.new('20180725T150000', tzid: time_zone)
        e.summary = 'Event 3, after the end_time of the scan'
      end

      cal
    end

    specify 'the provided calendar contains three base events' do
      expect(calendar.events.size).to eq(3)
    end

    describe 'the scan' do
      let(:scan) { calendar.scan(begin_time, end_time, %i[events]) }

      it 'returns one event-occurrences in the time span' do
        expect(scan.size).to eq(1)
      end

      it 'pretty prints to', skip: 'debugging only' do
        scan.each do |occurrence|
          puts "#{occurrence.start_time} -> #{occurrence.end_time}"
        end
      end

      describe 'the first and only event' do
        let(:first_event) { scan.first }

        it 'has a summary' do
          expect(first_event.summary).to eq('Event 2, within the scan')
        end

        it 'start_time is a ActiveSupport::TimeZone' do
          expect(first_event.start_time).to be_a(ActiveSupport::TimeWithZone)
        end

        it 'happens on 25.6.2018' do
          expect(first_event.start_time.to_date).to eq(Date.parse('2018-06-25'))
        end

        it 'starts at 14:00' do
          expect(first_event.start_time.hour).to eq(14)
          expect(first_event.start_time.min).to eq(0)
        end

        it "lives in Europe/Berlin" do
          expect(first_event.start_time.time_zone.name).to eq(time_zone)
        end
      end
    end

  end
end

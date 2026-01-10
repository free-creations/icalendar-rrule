# frozen_string_literal: true

##
# With this spec, we verify that by coding `using IcalendarWithView`,
# we get a new method patched into the Icalendar::Calendar class.
#
# Note: in the current implementation of the _ruby-refinement feature_, we cannot use `respond_to?`
# to inquire for the added method. We must check, that calling the new method, does
# not throw a `NoMethodError`.
#
# rubocop:disable RSpec/PredicateMatcher
RSpec.context 'when `using Icalendar::Schedulable`' do
  using Icalendar::Schedulable # <-- that's what we are testing here

  describe Icalendar::Component do
    subject(:component) do
      described_class.new('event_todo_or_whatsoever')
    end

    let(:ical_date_with_symbol_tzid) do
      Icalendar::Values::DateTime.new('20180101T100000', { tzid: 'America/New_York' })
    end

    let(:ical_date_with_tzid) do
      Icalendar::Values::DateTime.new('20180101T100000', tzid: 'America/New_York')
    end

    let(:ical_date_without_tzid) do
      Icalendar::Values::DateTime.new('20180509T100000')
    end

    let(:time_with_zone_date) do
      ActiveSupport::TimeZone['Hawaii'].local(2018, 11, 5, 15, 30, 45)
    end

    let(:ruby_date) do
      Date.new(2018, 5, 26)
    end

    let(:hawaii_timezone) do
      ActiveSupport::TimeZone['Hawaii']
    end

    # rubocop:disable RSpec/MultipleExpectations
    specify '._extract_ical_time_zone_with_tzid' do
      expect(component._extract_ical_time_zone(ical_date_with_tzid).name).to eq('America/New_York')
    end
    specify '._extract_ical_time_zone_with_symbol_tzid' do
      expect(component._extract_ical_time_zone(ical_date_with_symbol_tzid).name).to eq('America/New_York')
    end
    specify '._extract_ical_time_zone_without_tzid' do
      expect(component._extract_ical_time_zone(ical_date_without_tzid)).to be_nil
    end
    specify '._extract_ical_time_zone_for_ruby_date' do
      expect(component._extract_ical_time_zone(ruby_date)).to be_nil
    end

    specify '._extract_explicit_timezone' do
      expect(component._extract_explicit_timezone(ical_date_with_tzid).name).to eq('America/New_York')
      expect(component._extract_explicit_timezone(ical_date_without_tzid)).to be_nil
      expect(component._extract_explicit_timezone(time_with_zone_date).name).to eq('Hawaii')
      expect(component._extract_explicit_timezone(ruby_date)).to be_nil
      expect(component._extract_explicit_timezone(nil)).to be_nil
    end

    describe '._extract_calendar_timezone' do
      using Icalendar::Schedulable

      context 'when calendar has no timezone' do
        it 'returns nil' do
          calendar = Icalendar::Calendar.new
          event = Icalendar::Event.new
          calendar.add_event(event)

          expect(event._extract_calendar_timezone).to be_nil
        end
      end

      context 'when calendar has invalid timezone' do
        it 'returns nil for non-existent timezone' do
          calendar = Icalendar::Calendar.new
          calendar.timezone do |tz|
            tz.tzid = 'Europe/FooFoo'
          end
          event = Icalendar::Event.new
          calendar.add_event(event)

          expect(event._extract_calendar_timezone).to be_nil
        end
      end

      context 'when calendar has valid timezone' do
        it 'returns the correct timezone' do
          calendar = Icalendar::Calendar.new
          calendar.timezone do |tz|
            tz.tzid = 'America/New_York'
          end
          event = Icalendar::Event.new
          calendar.add_event(event)

          tz = event._extract_calendar_timezone
          expect(tz).not_to be_nil
          expect(tz.name).to eq('America/New_York')
        end
      end
    end

    specify '._unique_timezone of a Component (without dtstart, dtend and due) uses system timezone or UTC' do
      tz = component.component_timezone
      system_offset = Time.now.utc_offset

      expect(tz).to be_a(ActiveSupport::TimeZone)
      # Should match system offset or be UTC (offset 0)
      expect([system_offset, 0]).to include(tz.now.utc_offset)
    end
    specify('`.start_time` always returns a `ActiveSupport::TimeWithZone`') do
      expect(component.start_time).to be_a(ActiveSupport::TimeWithZone)
    end
    specify('`.end_time` always returns a `ActiveSupport::TimeWithZone`') do
      expect(component.end_time).to be_a(ActiveSupport::TimeWithZone)
    end
    specify('`._rrules` always returns an array') do
      expect(component._rrules).to eq([])
    end

    specify('._to_time_with_zone returns an `ActiveSupport::TimeWithZone` for nil') do
      expect(component._to_time_with_zone(nil)).to be_a(ActiveSupport::TimeWithZone)
    end

    specify('._to_time_with_zone returns an `ActiveSupport::TimeWithZone` for an ical_date_with_tzid') do
      expect(component._to_time_with_zone(ical_date_with_tzid)).to be_a(ActiveSupport::TimeWithZone)
      expect(component._to_time_with_zone(ical_date_with_tzid)).to eq(ical_date_with_tzid)
    end
    specify('._to_time_with_zone interprets ical_date_without_tzid as floating time in system timezone') do
      result = component._to_time_with_zone(ical_date_without_tzid)

      expect(result).to be_a(ActiveSupport::TimeWithZone)
      expect(result.hour).to eq(ical_date_without_tzid.hour) # Time is preserved
      expect(result.min).to eq(ical_date_without_tzid.min)
    end
    specify('._to_time_with_zone returns an `ActiveSupport::TimeWithZone` for an time_with_zone_date') do
      expect(component._to_time_with_zone(time_with_zone_date)).to be_a(ActiveSupport::TimeWithZone)
      expect(component._to_time_with_zone(time_with_zone_date)).to eq(time_with_zone_date)
    end
    specify('._to_time_with_zone returns an `ActiveSupport::TimeWithZone` for a ruby_date') do
      expect(component._to_time_with_zone(ruby_date)).to be_a(ActiveSupport::TimeWithZone)
      expect(component._to_time_with_zone(ruby_date).to_date).to eq(ruby_date)
    end

    # Test for Ruby Time-Objekt with local timezone
    let(:ruby_time_cet) do
      # Simulate CET timezone (UTC+1 in winter)
      Time.new(2018, 1, 1, 8, 30, 0, '+01:00')
    end

    let(:cet_timezone) do
      ActiveSupport::TimeZone['Berlin'] # CET/CEST timezone
    end

    specify('._to_time_with_zone preserves timezone from Ruby Time object') do
      result = component._to_time_with_zone(ruby_time_cet)
      expect(result).to be_a(ActiveSupport::TimeWithZone)
      # The hour should remain 8:30, not shift to 7:30
      expect(result.hour).to eq(8)
      expect(result.min).to eq(30)
    end

    specify('._to_time_with_zone with explicit target timezone converts Ruby Time correctly') do
      result = component._to_time_with_zone(ruby_time_cet, cet_timezone)
      expect(result).to be_a(ActiveSupport::TimeWithZone)
      expect(result.hour).to eq(8)
      expect(result.min).to eq(30)
      expect(result.time_zone.name).to eq('Berlin')
    end

    specify('.schedule returns an `IceCube::Schedule`') do
      expect(component.schedule).to be_a(IceCube::Schedule)
    end

    specify('#_date_to_time_with_zone converts to midnight') do
      expect(component._date_to_time_with_zone(ruby_date, hawaii_timezone)).to be_a(ActiveSupport::TimeWithZone)
      expect(component._date_to_time_with_zone(ruby_date, hawaii_timezone).to_date).to eq(ruby_date)
      expect(component._date_to_time_with_zone(ruby_date, hawaii_timezone).to_s).to eq('2018-05-26 00:00:00 -1000')
    end
    # rubocop:enable RSpec/MultipleExpectations
    it 'has method #_overwritten_dates' do
      expect(component._overwritten_dates).to be_a(Array)
    end
  end

  describe Icalendar::Event do
    subject(:event) do
      described_class.new
    end

    specify('.schedule returns an `IceCube::Schedule`') do
      expect(event.schedule).to be_a(IceCube::Schedule)
    end
  end

  describe Icalendar::Todo do
    context 'when only due-time is defined' do
      subject(:due_task) do
        t = described_class.new
        t.due = Icalendar::Values::DateTime.new('20180327T123225', tzid: 'America/New_York')
        return t
      end

      specify('.start_time equals .due') { expect(due_task.start_time).to eq(due_task.due) }
      specify('.end_time equals .due') { expect(due_task.end_time).to eq(due_task.due) }
      # rubocop:disable RSpec/MultipleExpectations
      specify('.end_time .start_time are in the expected timezone') do
        expect(due_task.end_time.time_zone.name).to eq('America/New_York')
        expect(due_task.start_time.time_zone.name).to eq('America/New_York')
      end
      # rubocop:enable RSpec/MultipleExpectations
    end

    context 'when only duration is defined' do
      subject(:duration_task) do
        t = described_class.new
        t.duration = 'P0DT0H0M30S' # A duration of 30 seconds
        return t
      end

      specify('.end_time minus .start_time equals duration') do
        expect(duration_task.end_time - duration_task.start_time).to eq(30)
      end
    end
    context 'when due-time and duration are defined' do
      subject(:due_task) do
        t = described_class.new
        t.due = Icalendar::Values::DateTime.new('20180320T140030', tzid: 'America/New_York')
        t.duration = 'P15DT5H0M20S' # A duration of 15 days, 5 hours, and 20 seconds
        return t
      end

      # note: daylight saving time began on march 11. 2018
      specify('.end_time equals .due') { expect(due_task.end_time).to eq(due_task.due) }
      specify('.start_time is 15 days, 5 hours, and 20 seconds before due(watch out daylight saving time)') do
        expect(due_task.start_time.to_s).to eq('2018-03-05 08:00:10 -0500')
      end
    end

    context 'when rrule is defined ...' do
      subject(:complex_task) do
        FixtureHelper.parse_to_first_task('complex_task.ics')
      end

      # rubocop:disable RSpec/MultipleExpectations
      specify('._rrules is equal to ...') do
        expect(complex_task._rrules.first).to eq('FREQ=YEARLY;INTERVAL=2;BYMINUTE=30;BYHOUR=8,9;BYDAY=SU;BYMONTH=1')
        expect(complex_task._rrules[1]).to eq('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR')
      end
      # rubocop:enable RSpec/MultipleExpectations
    end
  end

  context 'when the calendar uses RECURRENCE-ID to overwrite some occurrences' do
    subject(:base_event) do
      FixtureHelper.parse_to_first_event('exception.ics')
    end

    specify 'has method #_overwritten_dates' do
      expect(base_event._overwritten_dates).to be_a(Array)
    end
    specify '#_overwritten_dates contains one item (for exception.ics)' do
      expect(base_event._overwritten_dates.size).to eq(1)
    end
    specify '#_overwritten_dates contains one item for 2018-06-02 19:00:00 +0200' do
      # RECURRENCE-ID;TZID=Europe/Berlin:20180602T190000
      expect(base_event._overwritten_dates.first.to_s).to eq('2018-06-02 19:00:00 +0200')
    end

    # rubocop:disable RSpec/MultipleExpectations
    specify '#_parent_set should be an array of two events' do
      expect(base_event._parent_set).to be_an(Array)
      expect(base_event._parent_set.size).to eq(2)
      expect(base_event._parent_set.first).to be_an(Icalendar::Event)
      expect(base_event._parent_set[-1]).to be_an(Icalendar::Event)
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  context 'with an event that is part of a calendar with timezone' do
    subject(:event_with_parent_timezone) do
      FixtureHelper.parse_to_first_event('all_day-multi_day.ics')
    end

    specify 'the function `_extract_calendar_timezone`returns a timezone' do
      expect(event_with_parent_timezone._extract_calendar_timezone).to be_truthy
    end
  end

  context 'with an event that is not longer than one day and only the date is given' do
    subject(:one_full_day) do
      FixtureHelper.parse_to_first_event('all_day-multi_day.ics')
    end

    specify 'the first event in `all_day-multi_day.ics` is an all days event' do
      expect(one_full_day.all_day?).to be_truthy
    end

    specify 'the first event in `all_day-multi_day.ics` is not a multi day event' do
      expect(one_full_day.multi_day?).to be_falsey
    end
  end

  context 'with an event that lasts one hour' do
    subject(:one_hour) do
      FixtureHelper.parse_to_n_th_event('all_day-multi_day.ics', 1)
    end

    specify 'the second event in `all_day-multi_day.ics` is not an all days event' do
      expect(one_hour.all_day?).to be_falsey
    end

    specify 'the second event in `all_day-multi_day.ics` is not a multi day event' do
      expect(one_hour.multi_day?).to be_falsey
    end
  end

  context 'with an event that spans over two days' do
    subject(:two_days) do
      FixtureHelper.parse_to_n_th_event('all_day-multi_day.ics', 2)
    end

    specify 'the third event in `all_day-multi_day.ics` is not an all days event' do
      expect(two_days.all_day?).to be_falsey
    end

    specify 'the third event in `all_day-multi_day.ics` is a multi day event' do
      expect(two_days.multi_day?).to be_truthy
    end
  end
  context 'with an alternative all day event' do
    subject(:one_full_day) do
      FixtureHelper.parse_to_n_th_event('all_day-multi_day.ics', 3)
    end

    specify 'the first event in `all_day-multi_day.ics` is an all days event' do
      expect(one_full_day.all_day?).to be_truthy
    end

    specify 'the first event in `all_day-multi_day.ics` is not a multi day event' do
      expect(one_full_day.multi_day?).to be_falsey
    end
  end


  describe '#_to_floating_time' do
    using Icalendar::Schedulable

    # Use exotic timezone to avoid system-TZ interference
    let(:kathmandu_tz) { ActiveSupport::TimeZone['Asia/Kathmandu'] } # UTC+5:45, no DST
    let(:ny_tz) { ActiveSupport::TimeZone['America/New_York'] } # UTC-5/-4, has DST

    # Create a dummy event for testing
    let(:event) do
      evt = Icalendar::Event.new
      evt.dtstart = Icalendar::Values::DateTime.new('20180101T120000', tzid: 'Asia/Kathmandu')
      evt
    end

    context 'when converting a simple UTC time' do
      it 'converts to floating time preserving wall-clock time in target timezone' do
        # 2018-01-01 15:00 UTC = 2018-01-01 20:45 in Kathmandu (UTC+5:45)
        utc_time = Time.utc(2018, 1, 1, 15, 0, 0)

        floating = event._to_floating_time(utc_time, kathmandu_tz)

        # Should be floating time (offset 0)
        expect(floating).to be_a(Time)
        expect(floating.utc_offset).to eq(0)

        # Should preserve wall-clock time in Kathmandu (20:45)
        expect(floating.year).to eq(2018)
        expect(floating.month).to eq(1)
        expect(floating.day).to eq(1)
        expect(floating.hour).to eq(20) # 15:00 UTC + 5:45 = 20:45
        expect(floating.min).to eq(45)
        expect(floating.sec).to eq(0)
      end
    end

    context 'when converting across DST boundary (New York)' do
      it 'handles winter time correctly' do
        # 2018-01-01 15:00 UTC = 2018-01-01 10:00 EST (UTC-5)
        utc_winter = Time.utc(2018, 1, 1, 15, 0, 0)

        floating = event._to_floating_time(utc_winter, ny_tz)

        expect(floating.hour).to eq(10) # 15:00 UTC - 5h = 10:00 EST
        expect(floating.min).to eq(0)
      end

      it 'handles summer time correctly' do
        # 2018-07-01 14:00 UTC = 2018-07-01 10:00 EDT (UTC-4)
        utc_summer = Time.utc(2018, 7, 1, 14, 0, 0)

        floating = event._to_floating_time(utc_summer, ny_tz)

        expect(floating.hour).to eq(10) # 14:00 UTC - 4h = 10:00 EDT
        expect(floating.min).to eq(0)
      end
    end

    context 'when converting TimeWithZone from different timezone' do
      it 'reinterprets in target timezone' do
        # New York: 2018-01-01 10:00 EST = 15:00 UTC = 20:45 Kathmandu
        ny_time = ny_tz.local(2018, 1, 1, 10, 0, 0)

        floating = event._to_floating_time(ny_time, kathmandu_tz)

        expect(floating.hour).to eq(20) # converted to Kathmandu wall-clock
        expect(floating.min).to eq(45)
      end
    end

    context 'when converting Date (system-TZ independent)' do
      it 'treats date as midnight in target timezone, not system-TZ' do
        date = Date.new(2018, 1, 1)

        floating = event._to_floating_time(date, kathmandu_tz)

        expect(floating.year).to eq(2018)
        expect(floating.month).to eq(1)
        expect(floating.day).to eq(1)
        expect(floating.hour).to eq(0) # midnight in Kathmandu, NOT system-TZ
        expect(floating.min).to eq(0)
        expect(floating.utc_offset).to eq(0)
      end
    end

    context 'when converting Icalendar::Values::DateTime with TZID' do
      it 'respects TZID parameter' do
        # Explicitly in Kathmandu timezone
        ical_dt = Icalendar::Values::DateTime.new('20180701T143000', tzid: 'Asia/Kathmandu')

        floating = event._to_floating_time(ical_dt, kathmandu_tz)

        expect(floating.hour).to eq(14)
        expect(floating.min).to eq(30)
        expect(floating.utc_offset).to eq(0)
      end
    end

    context 'when converting Ruby Time with system-TZ offset' do
      it 'converts correctly regardless of system-TZ' do
        # Ruby Time.new uses system-TZ, but we convert explicitly to target-TZ
        # This should work the same in Berlin (UTC+1) or CI (UTC)
        ruby_time = Time.new(2018, 1, 1, 12, 0, 0) # 12:00 in system-TZ

        # We force interpretation in Kathmandu timezone
        floating = event._to_floating_time(ruby_time, kathmandu_tz)

        # Result should be deterministic: ruby_time → UTC → Kathmandu
        expect(floating.utc_offset).to eq(0)
        # Hour depends on system-TZ, but should be consistent with _to_time_with_zone behavior
        expect(floating).to be_a(Time)
      end
    end

    context 'when converting Integer (Unix timestamp)' do
      it 'interprets as UTC epoch, then converts to target timezone' do
        # 2018-01-01 00:00:00 UTC as Unix timestamp
        timestamp = Time.utc(2018, 1, 1, 0, 0, 0).to_i

        floating = event._to_floating_time(timestamp, kathmandu_tz)

        # 00:00 UTC = 05:45 Kathmandu
        expect(floating.hour).to eq(5)
        expect(floating.min).to eq(45)
      end
    end
  end


  describe '#_ensure_active_timezone' do
    using Icalendar::Schedulable

    let(:event) {Icalendar::Event.new}

    context 'when given a valid TimeZone object' do
      it 'returns the object unchanged' do
        tz = ActiveSupport::TimeZone['Asia/Kathmandu']
        expect(event._ensure_active_timezone(tz)).to eq(tz)
      end
    end

    context 'when given a valid timezone name' do
      it 'returns the TimeZone object' do
        result = event._ensure_active_timezone('Asia/Kathmandu')
        expect(result).to be_a(ActiveSupport::TimeZone)
        expect(result.name).to eq('Asia/Kathmandu')
      end
    end

    context 'when given an invalid timezone name' do
      it 'returns UTC and logs a warning' do
        # Capture log output
        log_output = StringIO.new
        logger = Logger.new(log_output)
        Icalendar::Rrule.logger = logger

        result = event._ensure_active_timezone('Foo/Bar')

        expect(result).to eq(ActiveSupport::TimeZone['UTC'])
        expect(log_output.string).to include('Invalid timezone')
        expect(log_output.string).to include('Foo/Bar')
        expect(log_output.string).to include('falling back to UTC')

        # Reset logger to silent
        Icalendar::Rrule.logger = Logger.new(File::NULL)
      end
    end
  end


end
# rubocop:enable RSpec/PredicateMatcher

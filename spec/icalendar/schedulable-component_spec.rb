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
    specify '._extract_ical_time_zone' do
      expect(component._extract_ical_time_zone(ical_date_with_tzid).name).to eq('America/New_York')
      expect(component._extract_ical_time_zone(ical_date_without_tzid)).to be_nil
      expect(component._extract_ical_time_zone(ruby_date)).to be_nil
    end

    specify '._extract_timezone' do
      expect(component._extract_timezone(ical_date_with_tzid).name).to eq('America/New_York')
      expect(component._extract_timezone(ical_date_without_tzid)).to be_nil
      expect(component._extract_timezone(time_with_zone_date).name).to eq('Hawaii')
      expect(component._extract_timezone(ruby_date)).to be_nil
      expect(component._extract_timezone(nil)).to be_nil
    end
    specify ' `._unique_timezone` of a Component (without dtstart, dtend and due) is UTC' do
      expect(component.component_timezone.name).to eq('UTC')
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
    specify('._to_time_with_zone returns an `ActiveSupport::TimeWithZone` for an ical_date_without_tzid') do
      expect(component._to_time_with_zone(ical_date_without_tzid)).to be_a(ActiveSupport::TimeWithZone)
      expect(component._to_time_with_zone(ical_date_without_tzid)).to eq(ical_date_without_tzid)
    end
    specify('._to_time_with_zone returns an `ActiveSupport::TimeWithZone` for an time_with_zone_date') do
      expect(component._to_time_with_zone(time_with_zone_date)).to be_a(ActiveSupport::TimeWithZone)
      expect(component._to_time_with_zone(time_with_zone_date)).to eq(time_with_zone_date)
    end
    specify('._to_time_with_zone returns an `ActiveSupport::TimeWithZone` for a ruby_date') do
      expect(component._to_time_with_zone(ruby_date)).to be_a(ActiveSupport::TimeWithZone)
      expect(component._to_time_with_zone(ruby_date).to_date).to eq(ruby_date)
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
end
# rubocop:enable RSpec/PredicateMatcher

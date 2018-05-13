# frozen_string_literal: true

##
# With this spec, we verify that by coding `using IcalendarWithView`,
# we get a new method patched into the Icalendar::Calendar class.
#
# Note: in the current implementation of the _ruby-refinement feature_, we cannot use `respond_to?`
# to inquire for the added method. We must check, that calling the new method, does
# not throw a `NoMethodError`.
#
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
      Date.new(2018, 12, 5)
    end

    specify '._extract_ical_time_zone' do # rubocop:disable RSpec/MultipleExpectations:
      expect(component._extract_ical_time_zone(ical_date_with_tzid).name).to eq('America/New_York')
      expect(component._extract_ical_time_zone(ical_date_without_tzid)).to be_nil
      expect(component._extract_ical_time_zone(ruby_date)).to be_nil
    end

    specify '._extract_timezone' do # rubocop:disable RSpec/MultipleExpectations:
      expect(component._extract_timezone(ical_date_with_tzid).name).to eq('America/New_York')
      expect(component._extract_timezone(ical_date_without_tzid)).to be_nil
      expect(component._extract_timezone(time_with_zone_date).name).to eq('Hawaii')
      expect(component._extract_timezone(ruby_date)).to be_nil
      expect(component._extract_timezone(nil)).to be_nil
    end

    specify ' `._unique_timezone` of a Component (without dtstart, dtend and due) is UTC' do
      expect(component._unique_timezone.name).to eq('UTC')
    end
    #     it('has a method `#start_time`') do
    #       expect(event.start_time).to be_a(Icalendar::Values::DateTime)
    #     end
    #
    #     it('has a method `#end_time`') do
    #       expect(event.end_time).to be_a(Icalendar::Values::DateTime)
    #     end
    #     it('has a method `#_rrules`') do
    #       expect(event._rrules).to eq([])
    #     end
    #     specify('#_to_time_with_zone returns an `ActiveSupport::TimeWithZone` for nil') do
    #       expect(event._to_time_with_zone(nil)).to be_a(ActiveSupport::TimeWithZone)
    #     end
    #     specify('#_to_time_with_zone returns an `ActiveSupport::TimeWithZone` for an ical_date') do
    #       expect(event._to_time_with_zone(ical_date)).to be_a(ActiveSupport::TimeWithZone)
    #     end
    #     specify('#_extract_ical_time_zone returns the correct time zone for an ical_date') do
    #       expect(event._extract_ical_time_zone(ical_date)).to eq('bla')
    #     end
    #     specify('#_to_time_with_zone returns the given time_with_zone') do
    #       expect(event._to_time_with_zone(time_with_zone)).to equal(time_with_zone)
    #     end
  end

  describe Icalendar::Todo do
    context 'when only due-time is defined' do
      subject(:due_task) do
        t = described_class.new
        t.due = Icalendar::Values::DateTime.new('20180327T123225Z')
        return t
      end

      specify('#start_time equals #due') { expect(due_task.start_time).to eq(due_task.due) }
      specify('#end_time equals #due') { expect(due_task.end_time).to eq(due_task.due) }
    end
    context 'when due-time and duration are defined' do
      subject(:due_task) do
        t = described_class.new
        t.due = Icalendar::Values::DateTime.new('20180320T140030', tzid: 'America/New_York')
        t.duration = 'P15DT5H0M20S' # A duration of 15 days, 5 hours, and 20 seconds
        return t
      end

      # note: dayligt saving time began on march 11. 2018
      specify('the timezone of #due is what we expect') { expect(due_task.due.time_zone.name).to eq('America/New_York') }
      specify('the time of #due is what we expect') { expect(due_task.due.to_s).to eq('2018-03-20 14:00:30 -0400') }
      specify('#end_time equals #due') { expect(due_task.end_time).to eq(due_task.due) }
      specify('#start_time is 15 days, 5 hours, and 20 seconds before due') do
        expect(due_task.start_time.to_s).to eq('2018-03-05 09:00:10 -0500')
      end
    end
  end
end

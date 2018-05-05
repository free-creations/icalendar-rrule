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

  describe Icalendar::Event do
    subject(:event) do
      described_class.new
    end

    it('has a new method `#start_time`') do
      expect(event.start_time).to be_a(Icalendar::Values::DateTime)
    end

    it('has a new method `#end_time`') do
      expect(event.end_time).to be_a(Icalendar::Values::DateTime)
    end
  end
end

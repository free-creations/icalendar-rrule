# frozen_string_literal: true

##
# With this spec, we verify that by coding `using IcalendarWithView`,
# we get a new method patched into the Icalendar::Calendar class.
#
# Note: in the current implementation of the _ruby-refinement feature_, we cannot use `respond_to?`
# to inquire for the added method. We must check, that calling the new method, does
# not throw a `NoMethodError`.
#
RSpec.describe Icalendar::Scannable do
  using described_class # <-- that's what we are testing here

  describe Icalendar::Calendar do
    subject(:calendar) { described_class.new }

    it('has a new method `#scan`') do
      expect { calendar.scan(Date.parse('2018-04-01'), Date.parse('2018-05-01')) }.not_to raise_error
    end

    it('has not a new method `foofoo`') do
      # just make sure that above test really does what ist should do.
      expect { calendar.foofoo }.to raise_error(NoMethodError)
    end
  end
end

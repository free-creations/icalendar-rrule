# frozen_string_literal: true

require 'icalendar/rrule' # the gem under test

RSpec.describe Icalendar::Rrule::Occurrence do
  zone = ActiveSupport::TimeZone['Europe/Busingen']

  # we'll run all examples with different kind of base components.
  # This could also have been done with
  # [shared examples](https://relishapp.com/rspec/rspec-core/v/3-7/docs/example-groups/shared-examples)
  [FixtureHelper.parse_to_first_event('daily_event.ics'),
   FixtureHelper.parse_to_first_task('daily_task.ics')].each do |base_component|

    context 'when the `base component` is an ' + base_component.class.name do
      subject(:occurrence) { described_class.new(nil, base_component, time_1, time_2) }

      let(:time_1) { zone.parse('2018-04-01 15:30:45') }
      let(:time_2) { zone.parse('2018-04-02 15:30:45') }
      let(:time_3) { zone.parse('2018-04-03 15:30:45') }
      let(:time_4) { zone.parse('2018-04-04 15:30:45') }

      let(:start_later) { described_class.new(nil, base_component, time_3, time_4) }
      let(:end_later)   { described_class.new(nil, base_component, time_1, time_4) }

      it 'has the same attributes as its base component' do
        is_expected.to have_attributes(
          summary: base_component.summary,
          uid: base_component.uid,
          dtstamp: base_component.dtstamp
        )
      end

      it 'has a property `@start_time` which acts like a Time object' do
        expect(occurrence.start_time).to be_a(ActiveSupport::TimeWithZone)
      end

      it 'has a property `@end_time`  which acts like a Time object' do
        expect(occurrence.end_time).to be_a(ActiveSupport::TimeWithZone)
      end

      it 'is read-only, i.e. does not allow to set any of its attributes' do
        expect { occurrence.uid = 'abc' }.to raise_error(NoMethodError)
      end

      it 'reports to `respond_to` any attribute it has "virtually inherited" from its base component' do
        is_expected.to respond_to(:uid)
      end

      it 'reports not to `respond_to` any attribute its base component does not have (for example foo)' do
        is_expected.not_to respond_to(:foo)
      end
      it 'reports not to `respond_to` any setter attribute (for example `uid=`)' do
        is_expected.not_to respond_to('uid=')
      end
      it 'responds to *optional properties* for example `contact`' do
        is_expected.to respond_to(:contact)
      end
      specify 'un-initialised *optional single properties* have the default value `nil`' do
        expect(occurrence.location).to be_nil
      end
      specify 'un-initialised *optional (multiple) properties* have the default value `[]`' do
        expect(occurrence.contact).to eq([])
      end
      it 'responds to *custom properties* for example `x_foo`' do
        is_expected.to respond_to(:x_foo)
      end
      specify 'un-initialised *custom properties* have the default value `[]`' do
        expect(occurrence.x_foo).to eq([])
      end
      it 'is always smaller than any occurrence that starts later (its natural sort order is `@start_time`)' do
        is_expected.to be < start_later
      end

      it 'is smaller than an occurrence that starts at the same time but  ends later' do
        is_expected.to be < end_later
      end

      it 'has a property `@extended_recurrence_id` ' do
        expect(occurrence.extended_recurrence_id).to be_a(Icalendar::Rrule::Occurrence::ExtendedRecurrenceID)
      end
    end
  end
end

# frozen_string_literal: true

require 'icalendar/rrule' # the gem under test
require 'date' # for parse method

RSpec.describe Icalendar::Rrule::Occurrence do
  # we'll run all examples with different kind of base components.
  # This could also have been done with
  # [shared examples](https://relishapp.com/rspec/rspec-core/v/3-7/docs/example-groups/shared-examples)
  [FixtureHelper.parse_to_first_event('daily_event.ics'),
   FixtureHelper.parse_to_first_task('daily_task.ics')].each do |base_component|

    context 'when the `base component` is an ' + base_component.class.name do
      subject(:component_view) { described_class.new(nil, base_component, time_1, time_2) }

      let(:time_1) { Date.parse('2018-04-01') }
      let(:time_2) { Date.parse('2018-04-02') }
      let(:time_3) { Date.parse('2018-04-03') }
      let(:time_4) { Date.parse('2018-04-04') }
      let(:later_component) { described_class.new(nil, base_component, time_3, time_4) }

      it 'has the same attributes as its base component' do
        is_expected.to have_attributes(
          summary: base_component.summary,
          uid: base_component.uid,
          dtstamp: base_component.dtstamp
        )
      end

      it 'has a property `@start_time` which acts like a Time object' do
        expect(component_view.start_time).to be_acts_like_time
      end

      it 'has a property `@end_time`  which acts like a Time object' do
        expect(component_view.end_time).to be_acts_like_time
      end

      it 'is read-only, i.e. does not allow to set any of its attributes' do
        expect { component_view.uid = 'abc' }.to raise_error(NoMethodError)
      end

      it 'reports to `respond_to` any attribute it has inherited from its base component' do
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
      specify 'unset *optional single properties* have the default value `nil`' do
        expect(component_view.location).to be_nil
      end
      specify 'unset *optional (multiple) properties* have the default value `[]`' do
        expect(component_view.contact).to eq([])
      end
      it 'responds to *custom properties* for example `x_foo`' do
        is_expected.to respond_to(:x_foo)
      end
      specify 'unset *custom properties* have the default value `[]`' do
        expect(component_view.x_foo).to eq([])
      end
      it 'is always smaller than a later component (its natural sort order is `@start_time`)' do
        is_expected.to be < later_component
      end
    end
  end
end

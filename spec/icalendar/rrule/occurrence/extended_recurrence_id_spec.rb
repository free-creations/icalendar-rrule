# frozen_string_literal: true

require 'icalendar/rrule' # the gem under test

RSpec.describe Icalendar::Rrule::Occurrence::ExtendedRecurrenceID do
  zone = ActiveSupport::TimeZone['Europe/Busingen']
  time1 = zone.parse('2018-04-01 15:30:45')
  uid1  = '66effd92-b8bb-43a3-958c-759a18090724'
  seq1  = 2

  time2 = zone.parse('2018-04-02 15:30:45')
  uid2  = '66effd92-b8bb-43a3-958c-759a18090725'
  seq2  = 1

  subject(:recurrence_id) { described_class.new(time1, uid1, seq1) }

  let(:recurrence_id_equal) { described_class.new(time1, uid1, seq1) }
  let(:recurrence_id_other_time) { described_class.new(time2, uid1, seq1) }
  let(:recurrence_id_other_uid)  { described_class.new(time1, uid2, seq1) }
  let(:recurrence_id_other_seq)  { described_class.new(time1, uid1, seq2) }

  it 'Compares on equality' do
    expect(recurrence_id <=> recurrence_id_equal).to eq(0)
  end

  it 'Compares on @orig_start' do
    expect(recurrence_id <=> recurrence_id_other_time).not_to eq(0)
  end
  it 'Compares on @uid' do
    expect(recurrence_id <=> recurrence_id_other_uid).not_to eq(0)
  end
  it 'Compares on @sequence' do
    expect(recurrence_id <=> recurrence_id_other_seq).to eq(-1)
  end
  it 'detects same events' do
    expect(recurrence_id).to be_same_event(recurrence_id_other_seq)
  end
end

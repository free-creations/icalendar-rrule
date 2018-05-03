# icalendar-rrule
This is an add-on to the [iCalendar Gem](https://github.com/icalendar/icalendar).
It makes it easier to iterate through a calendar with __repeating events__.

According to the [RFC 5545](https://tools.ietf.org/html/rfc5545) specification, 
repeating events are represented by one single entry, the repetitions being shown by
an attached _repeat rule_. Thus when we iterate through a calendar with, for example,
a daily repeating event, 
we'll only see one single event where for a month there would be around thirty events in reality.
The _calendar rrule_ shows all these events by unrolling the _repeat rule_ for a 
given time period.

The _calendar rrule_ is so to say a kind of "virtual calendar" which shows all 
events of the given ics-calendar, but _repeating events_ are expanded 
into multiple _occurrences_ that can be processed like normal 
calendar entries.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'icalendar-rrule'
```

and run `bundle install` from your shell.

## Usage

For explanations on how to parse and process RFC 5545 compatible calendars, please
have a look at the [iCalendar gem](http://github.com/icalendar/icalendar).

```ruby
require 'icalendar-rrule'

using IcalendarWithView

calendar = Icalendar::Calendar.new
calendar.event do |e|
  e.dtstart     =  DateTime.civil(2018, 1, 1, 8, 30)
  e.dtend       =  DateTime.civil(2018, 1, 1, 17, 00)
  e.summary     = 'Working'
  e.rrule       = 'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR'
end

begin_time =   Date.new(2018, 4, 22)
closing_time = Date.new(2018, 4, 29)

rrule = calendar.rrule(begin_time, closing_time)


rrule.each do |occurrence|
  puts "#{occurrence.occ_start.strftime('%a. %b. %d. %k:%M')}-#{occurrence.occ_end.strftime('%k:%M')}"
end
```
This will produce:
```
Mon. Apr. 23.  8:30-17:00
Tue. Apr. 24.  8:30-17:00
Wed. Apr. 25.  8:30-17:00
Thu. Apr. 26.  8:30-17:00
Fri. Apr. 27.  8:30-17:00
```
## Used Libraries

- **Active Support** see also 
  [How to Load Core Extensions](http://edgeguides.rubyonrails.org/active_support_core_extensions.html#how-to-load-core-extensions)

## Links
- [Wikipedia](https://en.wikipedia.org/wiki/ICalendar) article explaining the _iCalendar_ format.
- [RFC 5545](https://tools.ietf.org/html/rfc5545) Internet 
  Calendaring and Scheduling Core Object Specification.
- The Ruby [iCalendar gem](http://github.com/icalendar/icalendar) is used here as a base for 
  handling ical data.
- [RI_CAL](https://github.com/rubyredrick/ri_cal) is a project similar 
  to this one that aims to 
  "support important things like enumerating occurrences of repeating events".
  A newer fork is available here: [kdgm/ri_cal](https://github.com/kdgm/ri_cal)
- [The deceptively complex world of calendar events and RRULEs](https://www.nylas.com/blog/calendar-events-rrules/).
  A Blog of Jennie Lees.

# Shortcommings of Icalendar component
1. RFC 5545 compatibility. 
   - Default values for PRIORITY property. For example RFC 5545 says "Default is zero (i.e., undefined)."
     But Icalendar returns nil as default...
2. Inconsistent handling of multiple properties:
    - `CATEGORIES:MEETING` => `["MEETING"]`
    - `CATEGORIES:APPOINTMENT,EDUCATION` =>   `[["APPOINTMENT", "EDUCATION"]]`
    -  `CATEGORIES:MEETING \  CATEGORIES:BIRTHDAY` => => `["MEETING", "BIRTHDAY"]`

The RFC 5545 says:

> Some properties defined in the iCalendar object can have multiple values. The general rule for encoding multi-valued items is to simply create a new content line for each value, including the property name. However, it should be noted that some properties support encoding multiple values in a single property by separating the values with a COMMA character. Individual property definitions should be consulted for determining whether a specific property allows multiple values and in which of these two forms. Multi-valued properties MUST NOT be used to specify multiple language variants of the same value. Calendar applications SHOULD display all values.

Here is the code 
from `icalendar/has_properties.rb` line 143
```ruby
        define_method "#{prop}=" do |value|
          mapped = map_property_value value, klass, true
          if mapped.is_a? Icalendar::Values::Array
            instance_variable_set property_var, mapped.to_a.compact
          else
            instance_variable_set property_var, [mapped].compact
          end
        end
    ...
        define_method "append_#{prop}" do |value|
          send(prop) << map_property_value(value, klass, true)
        end
```

## Future Plans
Replace  `iCalendar Recurrence` by  [Ice cube](http://seejohncode.com/ice_cube/).
See [ice cube git](https://github.com/seejohnrun/ice_cube)

### Renaming
Project name:
`icalendar-rrule`

Name proposals for the rrule function:
- proxy
- delegate
- scan
- survey 
- representative
- delegate
- outline
- iterator
- Enumerable
- Range
- all_in_range
- entries
- list of planned events
- overview


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/free-creations/icalendar-rrule.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

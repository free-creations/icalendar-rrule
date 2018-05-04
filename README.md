# icalendar-rrule
This is an add-on to the [iCalendar Gem](https://github.com/icalendar/icalendar).
It makes it easier to iterate through a calendar with __repeating events__.

According to the [RFC 5545](https://tools.ietf.org/html/rfc5545) specification, 
repeating events are represented by one single entry, the repetitions being shown by
an attached _repeat rule_. Thus when we iterate through a calendar with, for example,
a daily repeating event, 
we'll only see one single event where for a month there would be many more events in reality.

The _icalendar-rrule gem_ patches an additional function called `scan` into the _iCalendar Gem_. 
The _scan_ shows all events by unrolling the _repeat rule_ for a 
given time period.

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

using Icalendar::Scannable

calendar = Icalendar::Calendar.new
calendar.event do |e|
  e.dtstart     =  DateTime.civil(2018, 1, 1, 8, 30)
  e.dtend       =  DateTime.civil(2018, 1, 1, 17, 00)
  e.summary     = 'Working'
  e.rrule       = 'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR'
end

begin_time =   Date.new(2018, 4, 22)
closing_time = Date.new(2018, 4, 29)

rrule = calendar.scan(begin_time, closing_time)


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

- [iCalendar Gem](https://github.com/icalendar/icalendar).
- [Ice cube](https://github.com/seejohnrun/ice_cube)
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


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/free-creations/icalendar-rrule.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

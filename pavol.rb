#!/usr/bin/env ruby

# Copyright 2013-2018, Raphael Reitzig
# <code@verrech.net>
#
# pavol is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# pavol is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with pavol. If not, see <http://www.gnu.org/licenses/>.

# Controls pulseaudio volume.
# Requires `pacmd`.
#
# * `pavol` outputs current volume (in percent)
# * `pavol ?` outputs if pulseaudio is muted.
# * `pavol !` (un)mutes pulseaudio depending on current state.
# * `pavol +` increases volume.
# * `pavol -` decreases volume.
#
# In case multiple sinks are defined below, add the index of the one
# you want to control as second parameter (defaults to `0`).

# Pick a unique substring of one of the names listed by `pacmd list-sinks | grep name:`
SINKS = ["Logitech_USB_Headset"#,  # headphones
        # "DigiHug_USB" # DAC
        ]
INTERVAL = 5

SINK = ARGV.size > 1 ? SINKS[ARGV[1].to_i] : SINKS[0] 

# Determine the "count index" of SOURCE (not necessarily == what index below then computes!)
sinks = IO::popen("pacmd list-sinks | grep name:").readlines
SNKINDEX = sinks.index { |l| l.include? SINK }
# puts SNKINDEX

def current
  c = IO::popen("pacmd \"list-sinks\" | grep -E '^\\s+volume:'").readlines[SNKINDEX]
  return c.split(" ").select { |s| s =~ /\d+%/ }.last.sub("%", "").strip.to_i
end

def max
  c = IO::popen("pacmd \"list-sinks\" | grep \"volume steps\"").readlines[SNKINDEX]
  return c.split(" ").last.strip.to_i - 1
end

def index
  c = IO::popen("pacmd \"list-sinks\" | grep index").readlines[SNKINDEX]
  return c.split(" ").last.strip.to_i
end

def set(v)
  IO::popen("pacmd \"set-sink-volume #{index} #{v}\"").readlines
end

def muted
  c = IO::popen("pacmd \"list-sinks\" | grep muted").readlines[SNKINDEX]
  return c.split(" ").last.strip == "yes"
end

def toggle
  t = 1
  if ( muted )
    t = 0
  end

  IO::popen("pacmd \"set-sink-mute #{index} #{t}\"").readlines
end

if ( ARGV.size == 0 )
  puts current
elsif (ARGV[0] == "?" )
  puts muted ? "muted" : current
elsif ( ARGV[0] == "+" )
  #set([current + interval, 100].min * (max / 100.0).round)
  set((current + INTERVAL) * (max / 100.0).round)
  puts current
elsif ( ARGV[0] == "-" )
  set([current - INTERVAL, 0].max * (max / 100.0).round)
  puts current
elsif ( ARGV[0] == "!" )
  toggle
  puts muted ? "muted" : current
else
  puts "Bad command '#{ARGV[0]}'"
end

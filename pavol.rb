#!/usr/bin/ruby

# Copyright 2013-2017, Raphael Reitzig
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

SOURCE = 1
INTERVAL = 5

def current
  c = IO::popen("pacmd \"list-sinks\" | grep -E '^\\s+volume:'").readlines[SOURCE]
  return c.split(" ").select { |s| s =~ /\d+%/ }.last.sub("%", "").strip.to_i
end

def max
  c = IO::popen("pacmd \"list-sinks\" | grep \"volume steps\"").readlines[SOURCE]
  return c.split(" ").last.strip.to_i - 1
end

def index
  c = IO::popen("pacmd \"list-sinks\" | grep index").readlines[SOURCE]
  return c.split(" ").last.strip.to_i
end

def set(v)
  IO::popen("pacmd \"set-sink-volume #{index} #{v}\"").readlines
end

def muted
  c = IO::popen("pacmd \"list-sinks\" | grep muted").readlines[SOURCE]
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

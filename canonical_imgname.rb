#!/usr/bin/env ruby

# Copyright 2016--2024, Raphael Reitzig
#
# canonical_imgname is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# canonical_imgname is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with canonical_imgname. If not, see <http://www.gnu.org/licenses/>.

# Depends on `exiftool`

require 'fileutils'

DEBUG = false unless Object.const_defined?(:DEBUG)

# Photos obtained directly from a camera are tagged
def date_from_exif(file)
  def line_to_datetime(line)
    #puts line if DEBUG
    parts = line.split(/\s+:\s+/)
    puts "   - #{parts.to_s}" if DEBUG

    if parts.size >= 2
      if parts[0] == "Error"
        nil
      else
        datetime = parts[1].split(/\s+/)
        puts "     -> #{datetime.to_s}" if DEBUG
        date = datetime[0].strip.gsub(":", "-")
        time = datetime[1].split(/[\D]/)[0..2].join(".")
        "#{date} #{time}"
      end
    else
      nil
    end
  end

  exif = `exiftool '#{file}' | grep -E "(Error|Create Date|Date/Time Original)"`
  if exif.strip.size > 0
    puts " - Found EXIF tags" if DEBUG
    exif_results = exif.split("\n").map { |line| line_to_datetime(line) }.reject { |e| e.nil? }
    if exif_results.empty?
      puts " - No usable EXIF tags found: #{exif}" if DEBUG
    else
      # Rationale: Prefer creation over modification date
      # Is that always the right choice, though?
      return exif_results.min
    end
  end

  return nil
end

# Images received via messengers sometimes don't have tags,
# but somewhat helpful filenames
def date_from_filename(file)
  if file =~ /(?:IMG|VID)-(\d{4})(\d{2})(\d{2})-WA(\d+)/
    puts " - Detected WhatsApp filename pattern" if DEBUG
    return "#{$~[1]}-#{$~[2]}-#{$~[3]} #{$~[4]}"
  elsif file =~ /threema-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/
    puts " - Detected Threema filename pattern" if DEBUG
    return "#{$~[1]}-#{$~[2]}-#{$~[3]} #{$~[4]}.#{$~[5]}.#{$~[6]}"
  else
    return nil
  end
end

def full_filename(file, new_base_name)
  return "#{File.dirname(file)}/#{new_base_name}#{File.extname(file)}"
end

def canonical_image_name(file)
    return [
        date_from_exif(file),
        date_from_filename(file)
    ].reject { |it| it.nil? }.first
end


if ARGV.empty?
    STDERR.puts "No file given"
    exit(false)
end
file = ARGV[0]

if File.exist?(file) && !File.directory?(file)
    if (new_name = canonical_image_name(file))
        puts full_filename(file, new_name)
    else
        STDERR.puts "Could not derive canonical filename"
        exit(false)
    end
else
    puts "No such file: #{file}"
    exit(false)
end

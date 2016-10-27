#!/usr/bin/ruby

# Copyright 2016, Raphael Reitzig
#
# rmobsraw is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# rmobsraw is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with rmobsraw. If not, see <http://www.gnu.org/licenses/>.


# When looking through a huge bunch of photos, you can usually
# delete bad shots directly from the viewing application. However,
# this will delete only the JPG, not the RAW (if you have any).
# Deleting them all manually is arduous -- hence this script.
#
# Out of all passed files, this script identifies all RAW files
# whose companion JPG has been deleted; we call these "obsolete".
# You can then choose to delete them ("Y"), list the file names ("l"),
# or abort (anything else) -- unless you passed option -f (force),
# then the script will delete without prompting you.

require 'mimemagic'
require 'fileutils'

# File endings to look for: if no matching file exists,
# the RAW file is considered obsolete.
IMGTYPES = ["JPG", "JPEG", "jpg", "jpeg"]


if ARGV.size == 0
  puts "Usage: rmobsraw [-f] file..."
  Process.exit
end

force = ARGV[0] == "-f"
# We can treat this string as a filename down below; 
# unless there's a RAW of that name, nothing will happen.

count = { :total => 0, :raw => 0, :obsolete => 0 }
obsolete_files = []

ARGV.each { |pattern|
  Dir[pattern].each { |file| # Perform shell expansions
    if File.file?(file)
      count[:total] += 1
      
      type =  MimeMagic.by_path(file)
      if !type.nil? && type.child_of?("image/x-dcraw")
        count[:raw] += 1
        
        obsolete = !IMGTYPES.map { |ext| File.exist?(file.sub(/[^.]+$/, ext)) }.any?
        if obsolete
          obsolete_files.push(file)
        end
      end
    end
  } 
}

count[:obsolete] = obsolete_files.size
puts "Found #{count[:raw]} RAWs out of #{count[:total]} files; #{count[:obsolete]} seem to be obsolete."

if count[:obsolete] > 0
  while !force
    print "Delete #{count[:obsolete]} files? [Y/l/n] "
    case $stdin.gets.strip 
    when "Y"
      force = true
    when "l"
      puts "\t" + obsolete_files.join("\n\t")
    else
      break
    end
  end
  
  if force
    obsolete_files.each { |file|
      FileUtils::rm(file)
    }
  end
end

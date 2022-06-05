#!/usr/bin/env ruby

# Copyright 2015--2018, Raphael Reitzig
#
# music2thumb is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# music2thumb is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with music2thumb. If not, see <http://www.gnu.org/licenses/>.


# Copies music files to a thumbdrive/music player, converting down to
# the best format your player supports and renaming for FAT32 compatibility.
# Takes a specification file and a target directory.
#
# Specification files are plain text files with one line per item of the form
#
#   artist/album/track
#
# where track (transfer whole album) or album and track (transfer all from
# the given artist) can be dropped. All three positions are matched as substrings,
# so
#
#   Stones/Dirty
#
# will match all tracks of Rolling Stones - Dirty Work (and maybe other albums).
# You can not drop the artist but you can use e.g.
#
#   */Dirty
#
# to match all albums with Dirty in the name, by any artist.
#
# You can cancel the process at any time by hitting CTRL+C (partial files do not 
# end up in the target directory) and re-issue the command again at a later time; 
# select do neither clean nor overwrite and the script continues where you halted 
# it earlier.
#
# Note that we silently ignore all files that do not have one of the supported 
# input formats (FLAC, OGG, MP3). 

 
# Requires ffmpeg with FLAC, Vorbis and MP3 support
# (depending on which conversions need to happen)
# as well as gem 'ruby-progressbar'
#
# For parallel conversion, install gem 'parallel' (may require 'bundler').

require 'fileutils'
gem 'ruby-progressbar'
require 'ruby-progressbar'

all_formats = ["flac", "ogg", "mp3"] # Ordered decreasingly by quality/preference
conversions = {
  "ogg->mp3"  => '"ffmpeg -v quiet -y -i \"#{infile}\" -qscale:a 6 -map_metadata 0:s:0 \"#{outfile}\""',
  "flac->mp3" => '"ffmpeg -v quiet -y -i \"#{infile}\" -qscale:a 6 -map_metadata 0:g:0 \"#{outfile}\""',
  "flac->ogg" => '"ffmpeg -v quiet -y -i \"#{infile}\" -vn -codec:a libvorbis -qscale:a 6 -map_metadata 0 \"#{outfile}\""'
}
# We only convert to the best allowed format and (hopefully) never up,
# so other directions are not necessary.
# We assume that the necessary tools are installed.
# TODO Ask for target quality, at least when downcoding from FLAC or WAV?

# We need to sanitise file names for FAT32
def sanitize(s)  
  if s.include?(".") # file
    parts = s.split(".")
    basename = parts[0..-2].join(".")
    ending = parts.last
  else # directory
    basename = s
    ending = nil
  end
  
  basename.sub!(/^[\s\.]*(.*?)[\s\.]*$/, "\\1") # Remove prefices and suffices of whitespace and periods
  basename.gsub!(/[:;\|\*\?"]/, "")             # Remove illegal characters
  basename = basename[0..50]                    # Cut off too long names TODO what's the exact limit?
  # TODO get rid of umlauts (and what else?)
  
  "#{basename}" + (if !ending.nil? then ".#{ending}" else "" end)
end

# Parameters: input file, target folder
if ( ARGV.size < 2 )
  puts "Usage: music2thumb <spec file> <target folder>"
  Process.exit
end

input  = ARGV[0]
target = ARGV[1]

if ( !File.exist?(input) )
  puts "File '#{input}' does not exist."
  Process.exit
elsif ( File.directory?(input) )
  puts "File '#{input}' is a directory."
  Process.exit
end

if ( File.exist?(target) && !File.directory?(target) )
  puts "'#{target}' is not a directory."
  Process.exit
end

# Ask for list of available formats
print "Which formats out of [#{all_formats.join(", ")}] are allowed? "
formats = $stdin.gets.strip.split(/\s+/).select { |e| all_formats.include?(e) }
if ( formats.empty? )
  puts "No supported format? That's not going to work out, sorry."
  Process.exit
else
  puts "Okay, we will use formats #{formats.join(", ")}."
end

# Read file with file/folder list
filespecs = File.open(input, "r") { |f|
  f.readlines.map { |l|
    l.strip
  }.select { |l|
    l.size > 0
  }
}

# Collect all files like this:
# "infile" => { :target -> "outfile", :conv -> (nil|"in->out") }
jobs = {}
filespecs.each { |spec|
  parts = spec.split("/")

  if ( parts.size > 3 )
    puts "\tSpecification '#{spec}' has too many components. Ignoring."
    next
  end

  # Fill up levels and wildcardify
  parts.fill("", parts.length...3).map! { |s|
    if ( s == "" )
      "*"
    else
      "*#{s}*"
    end
  }
  
  # We only want to consider supported file types
  parts[2] = "#{parts[2]}.{#{all_formats.join(",")}}"

  Dir[parts.join("/")].each { |infile| # TODO make case insensitive?
    # Sanitise path for FAT32
    clean_infile = infile.split("/").map { |p| sanitize(p) }.join("/")
    # TODO add an option for flat hierarchy:
    #      some players may fare better with e.g. "artist - album" instead of "artist/album"
    #  --> when option is set, join all but the last element with " - ".
    
    if ( infile =~ /\.(#{formats.join("|")})$/ )
      outfile = "#{target}/#{clean_infile}"
      conv = nil
    else
      # Find best allowed format
      target_format = all_formats.drop_while { |e| !formats.include?(e) }.first
      # TODO we get bad errors if we only have bad files (e.g. source mp3 but not allowed)
      #      Treat properly!
      outfile = "#{target}/#{clean_infile.gsub(/\.(#{all_formats.join("|")})$/, ".#{target_format}")}"
      conv = "#{infile.split(".").last}->#{target_format}"
    end
    
    jobs[infile] = {:target => outfile, :conv => conv}
  }
}

if ( jobs.empty? )
  puts "We did not find any files to copy; check your specification!"
  Process.exit
end

# Check target folder
overwrite = false
if ( !File.exist?(target) )
  Dir.mkdir(target)
elsif ( Dir.entries(target).size > 2 ) # . and .. are always there
  # Ask if target dir should be cleaned
  print "Target directory '#{target}' is not empty.\n\tShould we clean it? [Y/n] "
  if ( $stdin.gets.strip == "Y" )
    Dir["#{target}/*"].each { |f| FileUtils::rm_rf(f) }
    puts "\t '#{target}' is now empty."
  else
    print "\tOkay, no cleaning. But should we overwrite existing files? [Y/n] "
    if ( $stdin.gets.strip == "Y" )
      overwrite = true
    end
  end
end

# Reduce job list to those we actually have to do
if ( !overwrite )
  jobs.select! { |infile, spec|
    !File.exist?(spec[:target])
  }
end

if ( jobs.empty? )
  puts "All files are already there, so there is nothing left to do!"
  Process.exit
end

puts "We will transfer #{jobs.size} files, #{jobs.select { |k,v| v[:conv] != nil }.size} of which will be converted first."
print "This may take a while. Continue? [Y/n] "
if ( $stdin.gets.strip != "Y" )
  Process.exit
end

begin
  # Copy to target folder
  # Do this separately and first in order to get the quick stuff over with 
  # (more music on target should the user abort) and make time estimators
  # somewhat more robust. Also, parallelisation does not help for (I/O-bound)
  # copying.
  copyjobs = jobs.select { |k,v| v[:conv] == nil }
  
  if copyjobs.size > 0
    progress = ProgressBar.create(:title => "Copying   ", 
                                  :total => copyjobs.size,
                                  :format => "%t: [%B] [%c/%C] %E",
                                  :progress_mark => "|",
                                  :remainder_mark => ".")
    copyjobs.each { |infile, spec| 
       # TODO catch IO exceptions (in particular, target may be out of space)
      FileUtils::mkdir_p(File.dirname(spec[:target]))
      FileUtils::cp(infile, spec[:target])
      progress.increment
    }
  end


  # Convert to target folder
  convjobs = jobs.select { |k,v| v[:conv] != nil }
  
  if convjobs.size > 0
    processes = -1
    begin
      gem 'parallel'
      require 'parallel'
      gem 'system'
      require 'system'
      
      print "Looking for CPU count..."
      cores = System::CPU.count  
      print "\rHow many processes do you want us to use? [0-#{cores}] "
      processes = [[$stdin.gets.strip.to_i, 1].max, cores].min
      puts "\tOkay, using #{processes} processes."
    rescue Gem::LoadError
      puts "Hint: You can speed up conversion by installing gem 'parallel'!"
      
      # Define skeleton class for graceful sequential fallback
      module Parallel
        class << self
          def each(hash, options={}, &block)
            hash.each { |k,v| # TODO Exception thrown here
              block.call(k, v)
              options[:finish].call(nil, nil, nil)
            }
            hash
          end
        end
      end
    end

    progress = ProgressBar.create(:title => "Converting", 
                                  :total => convjobs.size,
                                  :format => "%t: [%B] [%c/%C] %E",
                                  :progress_mark => "|",
                                  :remainder_mark => ".")

    Parallel.each(convjobs,
                  in_processes: processes,
                  finish:       lambda { |e,i,r| progress.increment }) { |infile,spec|
                  #progress: "Converting") { |infile,spec|  
      begin
        # Write to /tmp first in order to avoid many writes to thumbdrive
        outfile = "/tmp/#{spec[:target].gsub("/", "")}"
    
        `#{eval(conversions[spec[:conv]])} &> /dev/null`    
        if ( !File.exist?(outfile) )
          progress.log("\tAn error occurred converting #{infile}.")
        else
          # Writing to thumbdrives can be slow, so do don't block here
          #Thread.new {
          #  begin
              FileUtils::mkdir_p(File.dirname(spec[:target]))
              FileUtils::mv(outfile, spec[:target])
          #  rescue => e
          #    progress.log("\tAn error occurred: #{e.to_s}")
              # TODO should we raise to the main Thread?
              # cf http://stackoverflow.com/a/9095369/539599
           # end
          #}
        end
      rescue Interrupt
        raise Interrupt if processes == -1 # Sequential fallback needs exception!
        # Note that some avconv process may be left running. Let's hope they
        # finish in a timely manner.
      rescue => e
        progress.log("\tAn error occurred: #{e.to_s}")
        #progress.log("\t\t#{e.backtrace.join("\n\t\t")}")
        # TODO Should we break? Let's see what kinds of errors we get...
      end
    }
  end

  # TODO some players (e.g. in cars) use file-system order. As an option, call fatsort.

  puts "Your music awaits you, have fun!"
rescue Interrupt#, Parallel::DeadWorker # TODO if there are no conversion tasks, Parallel is not defined!
  progress.stop
  puts "Cancelled"
end

# TODO some players use device order; call fatsort?

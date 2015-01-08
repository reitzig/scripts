#!/usr/bin/ruby

# Copyright 2015, Raphael Reitzig
# <code@verrech.net>
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

 
# Requires avconv with FLAC, Vorbis and MP3 support
# (depending on which conversions need to happen)
# as well as gem 'ruby-progressbar'
#
# For parallel conversion, install gems 'parallel' and 'system' (may require 'bundler').

require 'fileutils'
require 'ruby-progressbar'

all_formats = ["flac", "ogg", "mp3"] # Ordered decreasingly by quality/preference
conversions = {
  "ogg->mp3"  => '"avconv -v quiet -y -i \"#{infile}\" -qscale 6 -map_metadata 0:s:0 \"#{outfile}\""',
  "flac->mp3" => '"avconv -v quiet -y -i \"#{infile}\" -qscale 6 -map_metadata 0:g:0 \"#{outfile}\""',
  "flac->ogg" => '"avconv -v quiet -y -i \"#{infile}\" -codec libvorbis -qscale 3 -map_metadata 0 \"#{outfile}\""'
}
# We only convert to the best allowed format and (hopefully) never up,
# so other directions are not necessary.
# We assume that the necessary tools are installed.
# TODO Ask for target quality, at least when downcoding from FLAC or WAV?

# We need to sanitise paths for FAT32
def sanitize(s)
 s.sub(/^[\s\.]*(.*?)[\s\.]*$/, "\\1").gsub(/[:;\|\*\?]/, "")
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
  
    if ( infile =~ /\.(#{formats.join("|")})$/ )
      outfile = "#{target}/#{clean_infile}"
      conv = nil
    else
      # Find best allowed format
      target_format = all_formats.drop_while { |e| !formats.include?(e) }.first
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
print "This may take while. Continue? [Y/n] "
if ( $stdin.gets.strip != "Y" )
  Process.exit
end

begin
  # Copy to target folder
  # Do this separately and first in order to get the quick stuff over with 
  # (more music on target should the user abort) and make time estimators
  # somewhat more robust. Also, parallelisation does not help for (I/O-bound)
  # copying.
  progress = ProgressBar.create(:title => "Copying   ", 
                                :total => jobs.select { |k,v| v[:conv] == nil }.size,
                                :format => "%t: [%B] [%c/%C] %E",
                                :progress_mark => "|",
                                :remainder_mark => ".")
  jobs.select { |k,v| v[:conv] == nil }.each { |infile, spec| 
     # TODO catch IO exceptions (in particular, target may be out of space)
    FileUtils::mkdir_p(File.dirname(spec[:target]))
    FileUtils::cp(infile, spec[:target])
    progress.increment
  }

  # Convert to target folder
  processes = -1
  begin
    gem "system"
    require 'system'
    gem "parallel"
    require 'parallel'
    
    print "Looking for CPU count..."
    cores = System::CPU.count  
    print "\rHow many processes do you want us to use? [0-#{cores}] "
    processes = [[$stdin.gets.strip.to_i, 1].max, cores].min
    puts "\tOkay, using #{processes} processes."
  rescue Gem::LoadError
    puts "Hint: You can speed up conversion by installing gems 'parallel' and 'system'!"
    
    # Define skeleton class for graceful sequential fallback
    module Parallel
      class << self
        def each(hash, options={}, &block)
          hash.each { |k,v|
            block.call(k, v)
            options[:finish].call(nil, nil, nil)
          }
          array
        end
      end
    end
  end

  progress = ProgressBar.create(:title => "Converting", 
                                :total => jobs.select { |k,v| v[:conv] != nil }.size,
                                :format => "%t: [%B] [%c/%C] %E",
                                :progress_mark => "|",
                                :remainder_mark => ".")

  Parallel.each(jobs.select { |k,v| v[:conv] != nil },
                :in_processes => processes,
                :finish  => lambda { |e,i,r| progress.increment }) { |infile,spec| 
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
      # TODO Should we break? Let's see what kinds of errors we get...
    end
  }

  puts "Your music awaits you, have fun!"
rescue Interrupt, Parallel::DeadWorker
  progress.stop
  puts "Cancelled"
end

#!/usr/bin/ruby

# Copyright 2015, Raphael Reitzig
# <code@verrech.net>
#
# mkimgpage is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# mkimgpage is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with mkimgpage. If not, see <http://www.gnu.org/licenses/>.

# Creates image galleries from Markdown plus special image tags.
# TODO describe
 
# Requires ImageMagick, pandoc
# Requires gems 'dimensions' and 'ruby-progressbar'.
# Optionally, gems 'zip' (only for zipping) and 'parallel'.

require 'fileutils'
require 'pathname'

begin
  gem "dimensions"
  require 'dimensions'
  require 'ruby-progressbar'
rescue Gem::LoadError
  Puts "\tRequires gems 'dimensions' and 'ruby-progressbar'."
  Process.exit
end

# Defaults
thumbsize = 100
fullsize  = 2000
bannerwidth = 890 # Chosen to fit body width and padding. Height is thumbsize/2.
package   = '"#{input.sub(/\.\w+$/,"")}"'

if ARGV.size == 0
  puts "\tUsage: mkimgpage input [thumbsize] [fullsize] [package] [zip]"
  Process.exit
end

# Read Parameters
input     = ARGV[0]
package   = eval(package)
thumbsize = ARGV[1].to_i if ARGV.size > 1
fullsize  = ARGV[2].to_i if ARGV.size > 2
package   = ARGV[3]      if ARGV.size > 3
zip       = ARGV.size > 4 && ARGV[4] == "zip"

tmpdir    = "/tmp/mkimgpage_#{package}"
cssfile   = "#{File.dirname(Pathname.new(__FILE__).realpath)}/#{File.basename(__FILE__, File.extname(__FILE__))}.css"
footer = "#{File.dirname(Pathname.new(__FILE__).realpath)}/#{File.basename(__FILE__, File.extname(__FILE__))}_footer.html"

# Parse all image references
print "Scanning input file ... "
images = []
banners = []
text = nil
File.open(input,"r") { |f|
  text = f.read
  text.gsub!(/!(!|banner)\[([^\[\]]*)\]\(([^\(\)]+)\)/) { |match|
    # TODO add thumbnail weight?
    desc = match[$2]
    file = match[$3]

    type  = File.extname(file)
    name  = File.basename(file, type)
    
    if ( match[$1] == "!" )
      images.push({:file => file, :name => name,:type => type})
      "  <a class=\"imglink\" href=\"#{name}#{type}\"><img src=\"#{name}_thumb#{type}\" title=\"#{desc}\" alt=\"#{desc}\"/></a>"
    else ( match[$1] == "banner" )
      banners.push({:file => file, :name => name,:type => type})
      "  <div class=\"banner\"><img src=\"#{name}_banner#{type}\" title=\"#{desc}\" alt=\"#{desc}\"/></div>"
    end
  }
}
puts "Done"

# Make sure everything is set up
if text == nil
  puts "Could not read input; exiting."
  Process.exit 
end
Dir.mkdir(tmpdir) if !File.exist?(tmpdir)
if !File.directory?(tmpdir)
  puts "Can not write to directory #{tmpdir}; exiting."
  Process.exit
end


# Collect errors to output later
errors = []

# Parse rest with pandoc (include CSS directly?)
print "Creating HTML ... "
File.open("#{tmpdir}/index.md", "w") { |f|
  f.write(text)
}

# TODO add an option that allows to link a CSS file (default: style.css)
IO::popen("pandoc -o \"#{tmpdir}/index.html\" -t html5 -H \"#{cssfile}\" -A \"#{footer}\" -s -S \"#{tmpdir}/index.md\" 2>&1") { |p|
  out = p.readlines.join("\n").strip!
  if ( out != nil && out.length > 0 )
    errors.push(out)
  end
}

if File.exist?("#{tmpdir}/index.html")
  FileUtils.rm("#{tmpdir}/index.md")
  puts "Done"
else
  puts "Error"
  puts errors.join("\n\n")
  Process.exit
end

# Copy images, create thumbnails

# Try to load parallel gem; define sequential alternative if it is not installed
parallel = true
 begin
  gem "parallel"
  require 'parallel'
rescue Gem::LoadError
  puts "\tHint: You can speed this up by installing gem 'parallel'!"
  parallel = false
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

# Create progress bar
progressbar = ProgressBar.create(:title => "Converting images   ", 
                                 :total => images.size * 2 + banners.size,
                                 :format => "%t: [%B] [%c/%C] %E",
                                 :progress_mark => "|",
                                 :remainder_mark => ".")

# Convert normal images
errors = errors + Parallel.map(images, :finish  => lambda { |e,i,r| progressbar.progress += 2 }) { |i|
  begin
    errors = []
    if File.exist?("#{i[:file]}")
      if !File.exist?("#{tmpdir}/#{i[:name]}#{i[:type]}")
        # Shrink image so that the longer side is <= fullsize
        IO::popen("convert \"#{i[:file]}\" -resize \"#{fullsize}x#{fullsize}>\"" +
                  " \"#{tmpdir}/#{i[:name]}#{i[:type]}\"") { |p|
          out = p.readlines.join("\n").strip
          if ( out != nil && out.length > 0 )
            errors.push(out)
          end
        }
      end
      if (   !File.exist?("#{tmpdir}/#{i[:name]}_thumb#{i[:type]}") \
          || Dimensions.width("#{tmpdir}/#{i[:name]}_thumb#{i[:type]}") != thumbsize )
        # Shrink image so that the longer side is <= thumbsize and crop the other dimension down
        IO::popen("convert \"#{i[:file]}\" -resize \"#{thumbsize}x#{thumbsize}^\"" +
                  " -gravity center -extent \"#{thumbsize}x#{thumbsize}\"" +
                  " \"#{tmpdir}/#{i[:name]}_thumb#{i[:type]}\"") { |p|
          out = p.readlines.join("\n").strip
          if ( out != nil && out.length > 0 )
            errors.push(out)
          end
        }
      end
    else
      puts "\n  Image '#{i[:file]}' is not there."
    end
    errors
  rescue Interrupt
    raise Interrupt if !parallel # Sequential fallback needs exception!
  rescue => e
    puts "\tAn error occurred: #{e.to_s}"
    # TODO Should we break? Let's see what kinds of errors we get...
  end
}.flatten

# Convert banners (which need no thumbnail)
banners.each { |i| # TODO make parallel?
  if File.exist?("#{i[:file]}")
    if !File.exist?("#{tmpdir}/#{i[:name]}_banner#{i[:type]}")
      # Shrink image so that width is <= bannersize and cut to height of thumbsize/2
      IO::popen("convert \"#{i[:file]}\" -resize #{bannerwidth}" +
                " -gravity center -extent \"#{bannerwidth}x#{thumbsize}\"" +
                " \"#{tmpdir}/#{i[:name]}_banner#{i[:type]}\"") { |p|
        out = p.readlines.join("\n").strip
        if ( out != nil && out.length > 0 )
          errors.push(out)
        end
      }
    end
  else
    puts "\n\tImage '#{i[:file]}' is not there."
  end
  progressbar.increment
}

# Package the whole thing up
if zip
  require 'zip/zip'
  print "Zipping ... "
  Zip::ZipFile.open("#{package}.zip", Zip::ZipFile::CREATE) { |zipfile|
    Dir.foreach(tmpdir) { |f|
      zipfile.add(f, "#{tmpdir}/#{f}")    if ![".", ".."].include?(f)
    }
  }
  puts "Done"
else
  if File.directory?(package)
    FileUtils::rm_r(package)
  end
  FileUtils::cp_r(tmpdir, package)
end

# Print (non-critical) errors if there were any
if !errors.empty?
  puts "\nThere were errors:\n\n"
  puts errors.join("\n\n")
end

# Cleanup -- not doing it saves time when rebuilding a lot.
#FileUtils::rm_rf(tmpdir)

#!/usr/bin/ruby

# Copyright 2014, Raphael Reitzig
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
# TODO README
 
# Requires ImageMagick, pandoc
# Requires gem 'zip' for zipping

require 'fileutils'
require 'pathname'

# Defaults
thumbsize = 100
fullsize  = 2000
package   = '"#{input.sub(/\.\w+$/,"")}"'

if ARGV.size == 0
  puts "  Usage: mkimgpage input [thumbsize] [fullsize] [package] [zip]"
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
text = nil
File.open(input,"r") { |f|
  text = f.read
  text.gsub!(/!!\[([^\[\]]*)\]\(([^\(\)]+)\)/) { |match|
    # TODO add thumbnail weight?
    desc = match[$1]
    file = match[$2]

    type  = File.extname(file)
    name  = File.basename(file, type)
        
    images.push({:file => file, :name => name,:type => type})
    "  <a class=\"imglink\" href=\"#{name}#{type}\"><img src=\"#{name}_thumb#{type}\" title=\"#{desc}\" alt=\"#{desc}\"/></a>"
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
progress_prefix = "Converting images ... "
j = 0
images.each { |i| # TODO make parallel
  print "\r#{progress_prefix}[#{j}/#{images.size}]"; STDOUT.flush
  if File.exist?("#{i[:file]}")
    if !File.exist?("#{tmpdir}/#{i[:name]}#{i[:type]}")
      IO::popen("convert \"#{i[:file]}\" -resize \"#{fullsize}x#{fullsize}>\" \"#{tmpdir}/#{i[:name]}#{i[:type]}\"") { |p|
        out = p.readlines.join("\n").strip
        if ( out != nil && out.length > 0 )
          errors.push(out)
        end
      }
    end
    if !File.exist?("#{tmpdir}/#{i[:name]}_thumb#{i[:type]}")
      IO::popen("convert \"#{i[:file]}\" -resize \"#{thumbsize}x#{thumbsize}^\" -gravity center -extent \"#{thumbsize}x#{thumbsize}\" \"#{tmpdir}/#{i[:name]}_thumb#{i[:type]}\"") { |p|
        out = p.readlines.join("\n").strip
        if ( out != nil && out.length > 0 )
          errors.push(out)
        end
      }
    end
  else
    puts "\n  Image '#{i[:file]}' is not there."
  end
  j += 1
}
puts "\r#{progress_prefix}Done" + " "*10

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

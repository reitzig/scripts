#!/usr/bin/ruby

# Copyright 2013, Raphael Reitzig
# <code@verrech.net>
#
# pdfinvert is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# pdfinvert is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with pdfinvert. If not, see <http://www.gnu.org/licenses/>.

# Inverts colors in a PDF, including embedded images. Can use replacement 
# tables instead of inverting all colors. Can transform all embedded images
# or use rules to determine which remain unchanged. Can add page numbers (`-pn`).
#
# Color files have one rule per line. Each line has the format
#
#   dd #xxxxxx #xxxxxx
#
# where
#
#  * dd is an integer used for fuzzy color matching in embedded binary
#       images (see imagemagick documentation). Higher numbers mean colors
#       "farther away" from the specified source color are replaced.
#  * xxxxxx is an RGC color in hex. The first color is the source color, the
#           second the replacement color.
#
#  So, for instance, the line
#
#   30 #ffffff #000000
#
#  will replace white with black, and in embedded images also colors "30-close"
#  to white.
#  Note that rules are applied in sequence, from top to bottom.
#
# Image rule files have one line per page. Every line contains whitespace-separated
# zeros and ones; if the i-th digit is zero, the i-th embedded image on that
# page is not converted, otherwise it is. Illegal entries and missing numbers are 
# considered to be one.
#
# For example, the file
#
#   1 0 0
#   
#   1 1 0
#
# means that images two and three on page one as well as image three on page three
# remain unchanged; all other images will be converted.
#
# Additionally, you can specify a color using the `-it` option that will be trimmed
# from the border of images (before converting). For example,
#
#   -it "#000000"
#
# will cause black borders to be trimmed.
#
# Requirements:
#  * ruby
#  * inkscape
#  * imagemagick
#  * pdftk
#  * gs

require 'fileutils'

$DEBUG = false

# # # # # # # # # # # # # # # 
# Init
# # # # # # # # # # # # # # # 

if ( ARGV.size == 0 )
  puts "Usage: pdfinvert [-pn] [-c <color file>] [-i <image rule file>] [-it \"<color>\"] <input file> [output file]"
  Process.exit
end

$pagenumbers = false
$colors = ""
$trimcolor = ""
$images = ""
$input = ""

# Read in command line parameters
skip = 0
(0..ARGV.size - 1).each { |i|
  if ( skip > 0 )
    skip -= 1
    next
  end
  
  if ( ARGV[i] == "-pn" )
    $pagenumbers = true
  elsif ( ARGV[i] == "-c" )
    $colors = ARGV[i+1]
    skip = 1
  elsif ( ARGV[i] == "-i" )
    $images = ARGV[i+1]
    skip = 1
  elsif ( ARGV[i] == "-it" )
    $trimcolor = ARGV[i+1]
    skip = 1
  elsif ( $input == "" )
    $input = ARGV[i]
    $filename = File.basename($input, ".pdf")
    $output = "#{$filename}_inverted.pdf"
  else
    $output = ARGV[i];
  end
}

# Verify that input file exists
if ( $input == "" )
  puts "Please provide an input file."
  Process.exit
elsif ( !File.exists?($input) )
  puts "File '#{$input}' does not exist.";
  Process.exit;
end

$tmp = "/tmp/pdfinvert_#{$filename}"
$dir = Dir.pwd

# Ensure that temporary directory exists and is empty
if ( !Dir.exists?($tmp) )
  Dir.mkdir($tmp)
else
  Dir["#{$tmp}/*"].each { |f| File.delete(f) }
end

# Preprocess replacement colors file
$colorrules = {}
$colororder = []
if ( $colors != "" )
  if ( File.exists?($colors) )
    File.open($colors, "r") { |f|
      f.readlines.each { |line|
        entry = line.strip.split(/\s+/)
        entry[0] = Integer(entry[0])
        entry[1] = entry[1][1..6]
        entry[2] = entry[2][1..6]
        $colorrules[entry[1]] = [entry[0], entry[2]]
        $colororder.push(entry[1])
      }    
    }
  else
    puts "Color specification file '#{$colors}' does not exist. Inverting now."
    $colors = ""
  end
end

def replacecolor(color)
  if ( $colors != "" )
    if ( $colorrules.include?(color) )
      $colorrules[color][1]
    else
      color
    end
  else
    sprintf("%06x", 0xFFFFFF - Integer("0x#{color}", 16))
  end
end

# Preprocess image rule file
$imagerules = [[]]
if ( $images != "" )
  if ( File.exists?($images) )
    File.open($images, "r") { |f|
      ctr = 1
      f.readlines.each { |line|
        $imagerules[ctr] = line.strip.split(/\s+/).map { |b| Integer(b) rescue 1 }
        ctr += 1
      }    
    }
  else
    puts "Image rule file '#{$images}' does not exist. Converting all images now."
    $images = ""
  end
end

def convertimage?(page, image)
  if ( $imagerules.size > page && $imagerules[page].size > image )
    $imagerules[page][image] != 0
  else
    true
  end
end

# Function that returns page number inset for SVG
def pagenumber(nr, x, y) 
  return "  <g id=\"pagenumberg\">\n" + 
         "    <text xml:space=\"preserve\" style=\"font-size:25px;font-style:normal;font-weight:normal;line-height:125%;letter-spacing:0px;word-spacing:0px;fill:#888888;fill-opacity:1;stroke:none;font-family:Sans;\" " +
             "x=\"#{x}\" y=\"#{y}\" id=\"pagenumbert\" >\n" +
         "      <tspan  id=\"pagenumberts\" x=\"#{x}\" y=\"#{y}\" style=\"font-weight:1;font-style:normal;font-stretch:normal;font-variant:normal;font-size:25px;font-family:Sans;\">\n" +
         "        #{nr}\n" +
         "      </tspan>\n" +
         "    </text>\n" +
         "  </g>";
end

# This function processes the given file
def invert(file) 
  log = "Inverting #{file}...\n"
  basename = File.basename(file, ".pdf")
  
  p = IO::popen("inkscape -l #{basename}.svg #{file} 2>&1")
  log += p.readlines.join
  FileUtils.rm(file) if !$DEBUG

  # Change size form US Letter to A4 (may want to generalise?):
  #sed -e 's/width="765"/width="210mm"/;s/height="990"/height="297mm"/' ${1%.pdf}.svg \
  #  > ${1%.pdf}a4.svg;
  #mv ${1%.pdf}a4.svg ${1%.pdf}.svg;
  # This does not rescale/fit!
  
  svg = []
  File.open("#{basename}.svg", "r") { |f|
    svg = f.readlines
  }
  FileUtils.rm("#{basename}.svg") if !$DEBUG
  
  pnr = file.gsub(/[^0-9]/, "").to_i
  pny = nil
  pnx = nil
  imgctr = -1
  svg.map! { |line|
    # Replace colors of SVG elements as specified
    line.gsub!(/#([0-9a-f]{6})/) { |match|      
      "##{replacecolor($~[1])}"
    }
    
    # Replace colors in binary images as specified
    line.gsub!(/"data:image\/(\w+?);base64,(.*)"/) { |match|
      imgctr += 1
      
      imgtype = $~[1]
      imgname = "#{basename}_#{imgctr}"
      File.open("#{basename}_#{imgctr}.b64", "w") { |f| f.write($~[2]) }
      
      # Convert base 64 string to image
      p = IO::popen("base64 -d #{imgname}.b64 > #{imgname}.#{imgtype} 2>&1")
      log += p.readlines.join
      
      # Remove border
      if ( $trimcolor != "" )
        p = IO::popen("convert #{imgname}.#{imgtype} -bordercolor \"##{$trimcolor}\" " +
                              "-border 1 -fill none -draw 'color 0,0 floodfill' -shave 1x1 +repage " +
                              "#{imgname}.#{imgtype} 2>&1")
        log += p.readlines.join
      end
        
      # Invert/replace colors
      if ( convertimage?(pnr, imgctr) )
        if ( $colors == "" )
          p = IO::popen("convert #{imgname}.#{imgtype} -negate #{imgname}.#{imgtype} 2>&1")
          log += p.readlines.join
        else
          $colororder.each { |color|
            fuzz = $colorrules[color][0]
            p = IO::popen("convert #{imgname}.#{imgtype} -fuzz #{fuzz}% " + 
                            "-fill \"##{replacecolor(color)}\" -opaque \"##{color}\" " + 
                            "#{imgname}.#{imgtype} 2>&1")
            log += p.readlines.join
          }
        end
      end
        
      # Convert back to base 64
      p = IO::popen("base64 #{imgname}.#{imgtype} > #{imgname}.b64 2>&1")
      log += p.readlines.join
      
      result = "\"data:image/#{imgtype};base64,#{File.open("#{imgname}.b64", "r") { |f| result = f.readlines.join}}\""
      
      # Cleanup
      FileUtils.rm("#{imgname}.b64") if !$DEBUG
      FileUtils.rm("#{imgname}.#{imgtype}") if !$DEBUG
      
      result
    }
  
    # Add page number (if requested)
    if ( $pagenumbers )    
      # Find out (--> page number position) and change document height.
      # Need room for page number! No worry, we resize later, anyway.
      if ( pny == nil )
        line.gsub!(/height="(\d+)"/) { |match|
          newheight = Integer($~[1]) + 30
          pny = newheight.to_s
          "height=\"#{newheight}\""
        }
      end
      
      # Find out document width (--> page number position)
      if ( pnx == nil && /width="(\d+)"/ =~ line.strip )
        pnx = (Integer($~[1]) / 2).to_s
      end
      
      line.gsub!("</svg>", "\n#{pagenumber(pnr, pnx, pny)}\n</svg>")
    end
    line
  }
  
  File.open("#{basename}_inv.svg", "w") { |f|
    f.write(svg.join)
  }
  
  outbasename = sprintf("output_%04d", pnr)
  p = IO::popen("inkscape -A #{outbasename}.pdf #{basename}_inv.svg 2>&1")
  log += p.readlines.join
  FileUtils.rm("#{basename}_inv.svg") if !$DEBUG
  
  # Change PDF size to A4. Nasty workaround.
  p = IO::popen("gs -sOutputFile=#{outbasename}a4.pdf -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sPAPERSIZE=a4 " +
                   "-dFIXEDMEDIA -dPDFFitPage -q -f #{outbasename}.pdf 2>&1")
  log += p.readlines.join
  FileUtils.mv("#{outbasename}a4.pdf", "#{outbasename}.pdf")

  log += "Done inverting #{file}.\n";
  return log
end

# # # # # # # # # # # # # # # 
# Actual Work
# # # # # # # # # # # # # # # 

FileUtils.cp($input, $tmp)
Dir.chdir($tmp)
$input = File.basename($input)

$log = ""

p = IO::popen("pdftk #{$input} burst output #{$tmp}/input_%04d.pdf 2>&1")
$log += p.readlines.join
FileUtils.rm($input) if !$DEBUG
FileUtils.rm("doc_data.txt") if !$DEBUG # Created by pdftk

# Invert all pages
begin
  gem "parallel"
  require 'parallel'
  
  $log += Parallel.map(Dir["input_*"]) { |f|
    invert(f)
  }.join("\n")
rescue Gem::LoadError
  # Fall back to sequential processing if gem is not available
  $log += "Hint:  install gem 'parallel' to speed up jobs with many pages!\n\n"
  Dir["input_*"].each { |f|
    $log += invert(f)
  }
end

# Join pages together again
p = IO::popen("pdftk output*.pdf cat output output.pdf allow AllFeatures 2>&1")
$log += p.readlines.join
Dir["output_*"].each { |f| FileUtils.rm(f) }

# Write log (for debugging)
File.open("log", "w") { |f|
  f.write($log)
} if $DEBUG

# # # # # # # # # # # # # # # 
# Wrap-up
# # # # # # # # # # # # # # # 

Dir.chdir($dir)
FileUtils.cp("#{$tmp}/output.pdf", $output)
FileUtils.rm("#{$tmp}/output.pdf") if !$DEBUG
FileUtils.rmdir($tmp) if !$DEBUG

puts "Done. Find debug information in #{$tmp}" if $DEBUG

#!/usr/bin/env ruby

require 'mimemagic'
require 'fileutils'
# Also depends on: eyeD3, metaflac

COVER = ["cover.jpg", "cover.png"]

def coverify(file)
  cover = nil
  COVER.each { |c|
    cover = "#{File.dirname(file)}/#{c}"
    break if File.file?(cover)
  }

  type =  MimeMagic.by_path(file)

  if !type.nil? && !cover.nil? && File.file?(cover)
    case type.type
    when "audio/mpeg"
      `eyeD3 --add-image="#{cover}":FRONT_COVER "#{file}"`
      return true
    when "audio/flac"
      `metaflac --import-picture-from="#{cover}" "#{file}"`
      return true
    else
      puts "Can not deal with file of type '#{type}'"
    end
  end

  return false
end

count = 0
ARGV.each { |pattern|
  Dir[pattern].each { |file| # Perform shell expansions
    if File.file?(file)
      count += 1 if coverify(file)
    end
  }
}

puts "Coverified #{count} files."

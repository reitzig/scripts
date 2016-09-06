#!/usr/bin/ruby

table = STDIN.read.split(/\\\\/).map { |row|
          row.split("&").map{ |e| e.strip }
        }
        
puts table.to_s        
        
puts table.transpose.map { |row| row.join(" & ") }.join(" \\\\\n")

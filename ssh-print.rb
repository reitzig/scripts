#!/usr/bin/env ruby

# Copyright 2018, Raphael Reitzig
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

# A simple script that creates a printable PDF backup of an SSH key.
#
# Does currently not include any error handling.

require 'tmpdir'

if ARGV.size < 4
    puts "Usage: ssh-print.rb name passphrase key_file out_file"
    Process.exit(0)
end

name = ARGV[0]
pass = ARGV[1]
key  = ARGV[2]
out  = ARGV[3]
out += ".pdf" unless out.end_with?(".pdf")

Dir.mktmpdir { |tmpdir|
    wd = Dir.pwd
    
    fingerprint = `ssh-keygen -lf "#{key}"`    
    
    `cat "#{key}" | qrencode -o "#{tmpdir}"/qr.png`
    key_content = `cat "#{key}"`
    
    latex = <<~TEX
        \\documentclass{article}
        \\pagestyle{empty}
        \\setlength{\\parindent}{0pt}
        \\usepackage[margin=2cm]{geometry}
        \\usepackage{graphicx}
        
        \\begin{document}
            \\section*{#{name}}
            \\begin{description}
                \\item[Fingerprint:] \\texttt{#{fingerprint}}
                \\item[Passphrase:] \\texttt{#{pass}}
            \\end{description}
            \\includegraphics[width=\\linewidth]{qr.png}
            \\clearpage\\centering\\begin{verbatim}#{key_content}
            \\end{verbatim}
        \\end{document}
    TEX
    
    File.open("#{tmpdir}/bak.tex", "w") { |texfile|
        texfile.write(latex)
    }
    
    Dir.chdir(tmpdir)
    `pdflatex -file-line-error -interaction=nonstopmode bak.tex`
    FileUtils.cp("bak.pdf", "#{wd}/#{out}")
}

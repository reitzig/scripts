[![No Maintenance Intended](http://unmaintained.tech/badge.svg)](http://unmaintained.tech/)

# Assorted Shellscripts

This a just a collection of arguably useful shell scripts.

⚠️ These are updated on the basis of "do I need something right now". Use at your own risk.

### [`addcovers.rb`](https://github.com/reitzig/scripts/blob/master/addcovers.rb)

Picks up album covers from canonical local locations, and 
adds them to MP3 and FLAC files.

### [`canonical_imgname`](https://github.com/reitzig/scripts/blob/master/canonical_imgname.rb)

Derives a canonical filename for photos using EXIF data or certain filename patterns;
the format is `YYYY-MM-DD hh.mm.ss`, that is for example `2021-09-09 11.25.38`.

### [`canonify_imgnames`](https://github.com/reitzig/scripts/blob/master/canonify_imgnames)

Renames images using EXIF data or certain filename patterns so that they conform to a standard, 
datetime-based naming scheme.

### [`charge-reminder.go`](https://github.com/reitzig/scripts/blob/master/charge-reminder.go)

Periodically checks the current battery level and alerts the user if it is low (and not charging).

### [`imgs2pdf`](https://github.com/reitzig/scripts/blob/master/imgs2pdf)

Uses LaTeX to create a (portrait A4) PDF from the images passed as parameters.
Shrinks images to fit the page.

### [`mkimgpage.rb`](https://github.com/reitzig/scripts/blob/master/mkimgpage.rb)

Takes a Markdown file with special image tags and creates an image gallery from it.
Comes with a [style](https://github.com/reitzig/scripts/blob/master/mkimgpage.css) and [footer](https://github.com/reitzig/scripts/blob/master/mkimgpage_footer.html) you might want to adapt.

### [`music2thumb.rb`](https://github.com/reitzig/scripts/blob/master/music2thumb.rb)

Copies music files to a thumbdrive/music player, converting down to
the best format your player supports and renaming for FAT32 compatibility.

### [`pavol.rb`](https://github.com/reitzig/scripts/blob/master/pavol.rb)

Controls pulseaudio volume via shell. Since pulseaudio has a crappy CLI interface, this is useful
if you want to assign media hotkeys their proper function under less flashy window managers such as Fluxbox.

### [`pdfinvert`](https://github.com/reitzig/scripts/blob/master/pdfinvert)

In its basic mode, this script inverts all colors in a PDF, including embedded images.
You can also specify a more carefully chosen set of color replacement rules.

**Note:** Deprecated in favor of `pdfinvert.rb` as of [`af81254`](https://github.com/reitzig/scripts/commit/af81254a4d31690a5dd13355109d3934aa17bac7)

### [`pdfinvert.rb`](https://github.com/reitzig/scripts/blob/master/pdfinvert.rb)

In its basic mode, this script inverts all colors in a PDF, including embedded images.
You can also specify a more carefully chosen set of color replacement rules and exclude images from the conversion.

### [`pdfsplitk`](https://github.com/reitzig/scripts/blob/master/pdfsplitk)

Splits PDFs into constant-sized chunks. Useful if you create bulk letters, numbered exams or similar and need one
file per instance, e.g. for stapling printers.

### [`pullphotos`](https://github.com/reitzig/scripts/blob/master/pullphotos)

Downloads photos from [compatible](http://www.gphoto.org/doc/manual/FAQ.html#FAQ-camera-support) cameras without
resorting to mounting them as mass-storage devices. Also rotates them according to information provided by the camera.

### [`rmd2html`](https://github.com/reitzig/scripts/blob/master/rmd2html)

An elementary one-liner that compiles Rmd files into HTML.

### [`rmobsraw.rb`](https://github.com/reitzig/scripts/blob/master/rmobsraw.rb)

Removes obsolete RAW image files, i.e. such whose companion JPGs have been deleted.

### [`screen_setup`](https://github.com/reitzig/scripts/blob/master/screen_setup)

Provides a narrow interface to xrandr that allows you to switch easily between single, dual, and mirror screen setups. Tries to avoid some pitfalls like enabled but disconnected displays.

### [`shelve-photos`](https://github.com/reitzig/scripts/blob/master/shelve-photos.sh)

Interactively work through a list of photos and sort them into your folder-based collection.

### [`showqr`](https://github.com/reitzig/scripts/blob/master/showqr)

Renders and displays text as qr-code.

### [`ssh-print.rb`](https://github.com/reitzig/scripts/blob/master/ssh-print.rb)

A simple script that creates a printable PDF backup of an SSH key.
Does currently not include any error handling.

### [`switchkbl`](https://github.com/reitzig/scripts/blob/master/switchkbl)

Rotates through a set of hard-coded  (but easily changed) keyboard layouts. Useful for tying to a shortcut (or direct use)
under window managers that do not have convenient support for multiple layouts.

### [`tlwhich`](https://github.com/reitzig/scripts/blob/master/tlwhich)

Ever wondered which package provided that one LaTeX command you remember?
TeX Live Which looks for command, environment, package and document class definitions 
in your local TeX Live installation.

### [`tikz2png`](https://github.com/reitzig/scripts/blob/master/tikz2png)

Converts TikZ images specified in their own file to PNG. Check the script for quality settings.

### [`tikz2svg`](https://github.com/reitzig/scripts/blob/master/tikz2svg)

Converts TikZ images specified in their own file to SVG.

### [`transpose-latex-table.rb`](https://github.com/reitzig/scripts/blob/master/transpose-latex-table.rb)

Transposes a regular LaTeX `tabular` table.

### [`watch`](https://github.com/reitzig/scripts/blob/master/watch)

Wraps `omxplayer` to avoid a couple of usability issues, e.g.

 * hides shell background during video playback,
 * supports playlists and
 * supports (recursive) playback of multiple files and directories.

### [`xdg-mime-which`](https://github.com/reitzig/scripts/blob/master/xdg-mime-which.sh)

Determines in which file the XDG default application for the given MIME type is set.

Assorted Shellscripts
=======

This a just a collection of arguably useful shell scripts.

### [`pavol.rb`](https://github.com/akerbos/scripts/blob/master/pavol.rb)

Controls pulseaudio volume via shell. Since pulseaudio has a crappy CLI interface, this is useful
if you want to assign media hotkeys their proper function under less flashy window managers such as Fluxbox.

### [`pdfinvert`](https://github.com/akerbos/scripts/blob/master/pdfinvert)

In its basic mode, this script inverts all colors in a PDF, including embedded images.
You can also specify a more carefully chosen set of color replacement rules.

**Note:** Deprecated in favor of `pdfinvert.rb` as of [`af81254`](https://github.com/akerbos/scripts/commit/af81254a4d31690a5dd13355109d3934aa17bac7)

### [`pdfinvert.rb`](https://github.com/akerbos/scripts/blob/master/pdfinvert.rb)

In its basic mode, this script inverts all colors in a PDF, including embedded images.
You can also specify a more carefully chosen set of color replacement rules and exclude images from the conversion.

### [`pdfsplitk`](https://github.com/akerbos/scripts/blob/master/pdfsplitk)

Splits PDFs into constant-sized chunks. Useful if you create bulk letters, numbered exams or similar and need one
file per instance, e.g. for stapling printers.

### [`pullphotos`](https://github.com/akerbos/scripts/blob/master/pullphotos)

Downloads photos from [compatible](http://www.gphoto.org/doc/manual/FAQ.html#FAQ-camera-support) cameras without
resorting to mounting them as mass-storage devices. Also rotates them according to information provided by the camera.

### [`switchkbl`](https://github.com/akerbos/scripts/blob/master/switchkbl)

Rotates through a set of hard-coded  (but easily changed) keyboard layouts. Useful for tying to a shortcut (or direct use)
under window managers that do not have convenient support for multiple layouts.

### [`tikz2png`](https://github.com/akerbos/scripts/blob/master/tikz2png)

Converts TikZ images specified in their own file to PNG. Check the script for quality settings.

### [`tikz2svg`](https://github.com/akerbos/scripts/blob/master/tikz2svg)

Converts TikZ images specified in their own file to SVG.

### [`watch`](https://github.com/akerbos/scripts/blob/master/watch)

Wraps `omxplayer` to avoid a couple of usability issues, e.g.

 * hides shell background during video playback,
 * supports playlists and
 * supports (recursive) playback of multiple files and directories.

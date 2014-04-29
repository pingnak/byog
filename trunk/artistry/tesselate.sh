#!/bin/sh
size=50x50
file=./usgs.gov.coachella.jpg
path=./tiles
mkdir -p $path
# Use imagemagick to chop an image into tiles, as pngs
convert -monitor -verbose $file -crop $size -set filename:tile "%[fx:page.x]_%[fx:page.y]" +repage +adjoin "$path/ground_%[filename:tile].png"
# Now spend some quality time shrinking those images down
find $path -exec pngquant --speed=1 -v --ext .png --force \{\} \;
find $path -exec optipng -strip all -o7 -force -clobber \{\} \;


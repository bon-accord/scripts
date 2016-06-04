#!/bin/sh

# WARNING: mogrify changes the original input file!
# Quality=82 recommended to match Photoshop=60 but 20 fine in reality for us
# No need to use -strip if using -thumbnail 
# convert is for single files while mogrify is for batch processing
# convert has a bug that makes it ignore the -define jpeg:fancy-upsampling=off
# For resampling, -thumbnail achieves smaller files than just -resize and it also includes -strip
# Use -path option to save output to a different directory

#---------------------------------------------------------------------------------
# Usage
#---------------------------------------------------------------------------------

func_usage () {
          echo ""
          echo "Usage:     $(basename $0) -q quality -s size -i inputfile \n"
          echo "Example:   $(basename $0) -q 20 -s 1024 -i file.jpg \n"
          exit 3
}

[[ $# != 6 ]] && func_usage

#---------------------------------------------------------------------------------
# Variables
#---------------------------------------------------------------------------------

Suffix="opt"

BorderColour="'rgb(41,41,41)'"

BorderSize=2

#---------------------------------------------------------------------------------
# Process command-line arguments 
#---------------------------------------------------------------------------------

while getopts 'i:q:s:' option
do
   case $option in
        'i') INPUT_FILE="$OPTARG" ;;
        's') SIZE="$OPTARG" ;;
        'q') QUALITY_FACTOR="$OPTARG" ;;
     \?|h|*) func_usage ;;
   esac
done
shift $(($OPTIND -1))

#---------------------------------------------------------------------------------
# Create output file by working on a copy of the input file 
# Use double quotes to handle whitespace in filenames
#---------------------------------------------------------------------------------

# Print the name, and dimensions of the file named 300
# identify -format "Name: %f Dimensions: %P Type: %m" 300

if [[ -f $INPUT_FILE ]]; then
   NoExtension=${INPUT_FILE%.*}
   Extension=${INPUT_FILE##*.}
   # 
   OUTPUT_FILE=${NoExtension}_${Suffix}.${Extension}
   # echo "Optimising: $OUTPUT_FILE  -->  $(identify -format "%m %P" "$OUTPUT_FILE")"
   cp -p "$INPUT_FILE" "$OUTPUT_FILE"
else
   echo "Error: input file is not a jpeg or does not exist"
   exit 4
fi

# Make sure output file exists
[[ ! -f $OUTPUT_FILE ]] && exit 5

#---------------------------------------------------------------------------------
# Functions 
#---------------------------------------------------------------------------------

func_optimise_resize () {
                         mogrify \
                          -filter Triangle \
                          -define filter:support=2 \
                          -thumbnail $SIZE \
                          -unsharp 0.25x0.25+8+0.065 \
                          -dither None \
                          -posterize 136 \
                          -quality $QUALITY_FACTOR \
                          -define jpeg:fancy-upsampling=off \
                          -define png:compression-filter=5 \
                          -define png:compression-level=9 \
                          -define png:compression-strategy=1 \
                          -define png:exclude-chunk=all \
                          -interlace none \
                          -colorspace sRGB \
                          -shave 2 \
                          -bordercolor $(eval echo $BorderColour) -border $BorderSize \
                          -strip \
                          "$OUTPUT_FILE"
                        }

#---------------------------------------------------------------------------------
# Main 
#---------------------------------------------------------------------------------

func_main () {
               func_optimise_resize 

               echo "Optimised: $OUTPUT_FILE  -->  $(identify -format "%m %P" "$OUTPUT_FILE")"  
             }

func_main

# END

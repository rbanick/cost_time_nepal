#!/bin/bash

chmod u+x catchment_analysis.sh

ls *.tif > tif_list.txt

for f in *.tif

do

  if [ -e ${f%%.*}.shp ]
  then
    echo "${f%%.*}.shp already exists"
  else
    echo running $f
    bash catchment_analysis.sh $f;
  fi

done

echo "all analysis complete"

## old parallels


# echo running $f
# parallel -k -j-1 --debug j bash catchment_analysis.sh $f;
# cat tif_list.txt | parallel -k -j-1 --debug j --pipe bash catchment_analysis.sh {} :::: tif_list.txt

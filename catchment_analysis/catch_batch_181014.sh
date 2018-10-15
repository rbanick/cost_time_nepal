#!/bin/bash

chmod u+x catchment_analysis.sh

ls *.tif > tif_list.txt

for f in *.tif;

do

  echo running $f
  parallel -k -j-1 --debug j bash catchment_analysis.sh $f;

done

echo "all analysis complete"

## old parallels
# cat tif_list.txt | parallel -k -j-1 --debug j --pipe bash catchment_analysis.sh {} :::: tif_list.txt

#!/bin/bash

chmod u+x catchment_analysis.sh

for f in *.tif;

do bash catchment_analysis.sh $f;

echo "$f analysis complete"

done

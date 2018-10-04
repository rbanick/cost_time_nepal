#!/bin/bash

chmod u+x catchment_analysis.sh

chart_export_path=$1

for f in *.shp;

do bash catchment_analysis.sh $f;

echo "$f analysis complete"

done

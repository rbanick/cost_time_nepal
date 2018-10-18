#!/bin/bash

chmod u+x all_pop_analysis.sh

chart_export_path=$1

for f in *.tif;

do bash all_pop_analysis.sh $f chart_export_path;

echo "File $f analysis complete"

done

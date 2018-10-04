#!/bin/bash

chmod u+x master_lgu_pop_analysis.sh

chart_export_path=$1

for f in *.tif;

do bash master_lgu_pop_analysis_181001.sh $f chart_export_path;

echo "File $f analysis complete"

done

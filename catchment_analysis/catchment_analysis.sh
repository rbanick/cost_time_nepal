#!/bin/bash
#
# Catchment Analysis Routine
#
# Dissolve catchment areas
# Union with LGU bounds
# Select --> Delete catchment parts of LGU
# Join LGU population
# Zonal statistics for uncovered areas
# Calculate % uncovered vs. total population
#
# Output shapefile
# Output CSV
# Output chart 1 : covered vs. uncovered
# * Covered
# * Uncovered
# Output chart 2: covered, by facility

file=$1
read time <<< $(echo $file | awk 'match($0, /(over)?[0-9]+(hr|min)/) {print substr($0,RSTART,RLENGTH)}')
read type <<< $(echo $file | awk -F'[_]' '{print $1"_"$2}')

# path to GRASS binaries and libraries:

export GRASS_DB_LOC=/Volumes/TRANSCEND/GRASS/nepal
export GISBASE=/usr/local/Cellar/grass7/7.4.0/grass-7.4.0
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
export GRASS_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export PYTHONPATH="$GISBASE/etc/python:$PYTHONPATH"
export MANPATH=$MANPATH:$GISBASE/man
export GDAL_DATA=/usr/local/opt/gdal2/share/gdal/

## Grass

# remove all previous files

# grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment -f --exec g.remove name=${file%%.*}_clip type=all -f
# grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec g.remove name=${file%%.*}_cat type=all -f
# grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec g.remove name=${file%%.*}_dissolve type=all -f
# grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec g.remove name=${file%%.*}_adm2_subtract type=all -f
# grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec g.remove name=${file%%.*}_adm2_subtract_dissolve type=all -f

# polygonize files

python /Library/Frameworks/GDAL.framework/Programs/gdal_polygonize.py $file -f "ESRI Shapefile" ${file%%.*}.shp

#import file in question
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment -f --exec g.region -p
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.in.ogr input=${file%%.*}.shp output=${file%%.*} --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.clip input=${file%%.*} clip=adm0 output=${file%%.*}_clip

# adding a common background "category" that can be used to dissolve all the areas into one unit.

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.edit tool=delete map=${file%%.*}_clip where="DN='0'"

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.category input=${file%%.*}_clip option=add layer=2 output=${file%%.*}_cat cat=1 step=0 --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.dissolve input=${file%%.*}_cat layer=2 output=${file%%.*}_dissolve --overwrite

# Then subtract the dissolved catchment polygon from the administrative coverage of the country to leave the area uncovered per admin unit LGU

### provinces

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.overlay ainput=adm1 atype=area alayer=1 binput=${file%%.*}_dissolve btype=area blayer=2 out=${file%%.*}_adm1_subtract operator=not --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.dissolve input=${file%%.*}_adm1_subtract layer=1 output=${file%%.*}_adm1_subtract_dissolve col=a_STATE --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.join map=${file%%.*}_adm1_subtract_dissolve column=a_STATE layer=1 other_table=adm1 other_col=STATE subset_columns=pop_sum --overwrite

### LGU

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.overlay ainput=adm2 atype=area alayer=1 binput=${file%%.*}_dissolve btype=area blayer=2 out=${file%%.*}_adm2_subtract operator=not --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.dissolve input=${file%%.*}_adm2_subtract layer=1 output=${file%%.*}_adm2_subtract_dissolve col=a_HLCIT_CODE --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.join map=${file%%.*}_adm2_subtract_dissolve column=a_HLCIT_CODE layer=1 other_table=adm2 other_col=HLCIT_CODE subset_columns=sum --overwrite

# zonal statistics for catchment total and population coverage, then calculating the relative percentage for each admin unit

### adm1

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.rast.stats map=${file%%.*}_adm1_subtract_dissolve layer=1 raster=wp_32644 column_prefix=catch_pop_${time} method=sum --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.addcolumn map=${file%%.*}_adm1_subtract_dissolve layer=1 columns="pc_uncov_$time double precision"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.addcolumn map=${file%%.*}_adm1_subtract_dissolve layer=1 columns="trav_cat varchar"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.addcolumn map=${file%%.*}_adm1_subtract_dissolve layer=1 columns="type varchar"

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec db.execute sql="UPDATE ${file%%.*}_adm1_subtract_dissolve SET pc_uncov_$time=catch_pop_${time}_sum/pop_sum"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec db.execute sql="UPDATE ${file%%.*}_adm1_subtract_dissolve SET trav_cat='$time'"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec db.execute sql="UPDATE ${file%%.*}_adm1_subtract_dissolve SET type='$type'"

### LGU

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.rast.stats map=${file%%.*}_adm2_subtract_dissolve layer=1 raster=wp_32644 column_prefix=catch_pop_$time method=sum --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.addcolumn map=${file%%.*}_adm2_subtract_dissolve layer=1 columns="pc_uncov_$time double precision"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.addcolumn map=${file%%.*}_adm2_subtract_dissolve layer=1 columns="trav_cat varchar"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.db.addcolumn map=${file%%.*}_adm2_subtract_dissolve layer=1 columns="type varchar"

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec db.execute sql="UPDATE ${file%%.*}_adm2_subtract_dissolve SET pc_uncov_$time=catch_pop_${time}_sum/sum"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec db.execute sql="UPDATE ${file%%.*}_adm2_subtract_dissolve SET trav_cat='$time'"
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec db.execute sql="UPDATE ${file%%.*}_adm2_subtract_dissolve SET type='$type'"

# export to geopackages

mkdir ./$type

grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.out.ogr input=${file%%.*}_adm1_subtract_dissolve output=./$type/${file%%.*}_adm1_uncovered.gpkg --overwrite
grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment --exec v.out.ogr input=${file%%.*}_adm2_subtract_dissolve output=./$type/${file%%.*}_adm2_uncovered.gpkg --overwrite

# grass can't merge non-adjacent polygons with a common ID to a singlepart geometry, so gdals ogr2ogr tool has to be used for the final step

ogr2ogr ./$type/${file%%.*}_adm1_final.gpkg ./$type/${file%%.*}_adm1_uncovered.gpkg -dialect sqlite -sql "SELECT ST_Union(geom) AS geom, AVG(pop_sum) as adm_pop, AVG(catch_pop_${time}_sum) as catch_pop_$time, AVG(pc_uncov_$time) as pc_uncov_$time, a_STATE FROM ${file%%.*}_adm1_subtract_dissolve GROUP BY a_STATE" -f "GPKG"
ogr2ogr ./$type/${file%%.*}_adm2_final.gpkg ./$type/${file%%.*}_adm2_uncovered.gpkg -dialect sqlite -sql "SELECT ST_Union(geom) AS geom, AVG(sum) as adm_pop, AVG(catch_pop_${time}_sum) as catch_pop_$time, AVG(pc_uncov_$time) as pc_uncov_$time, a_HLCIT_CODE FROM ${file%%.*}_adm2_subtract_dissolve GROUP BY a_HLCIT_CODE" -f "GPKG"

ogr2ogr -f "CSV" ./$type/${file%%.*}_adm1_final.csv ./$type/${file%%.*}_adm1_final.gpkg
ogr2ogr -f "CSV" ./$type/${file%%.*}_adm2_final.csv ./$type/${file%%.*}_adm2_final.gpkg

cp csv_merge.r ./$type/csv_merge.r
cp LGU_names.csv ./$type/LGU_names.csv

## fun facts about GRASS!

### on import of the World Pop layer wp_32644, you need to set it to the same region as your vector files -- g.region vector=adm2 align=wp_32644
### grass will show things as multipart polygons on QGIS but actually they're single part when running geoprocessing routines
### this command ensures the region is properly set: grass74 /Volumes/TRANSCEND/GRASS/nepal/catchment -f --exec g.region vect=adm1@catchment align=wp_32644@catchment

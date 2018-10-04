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

# path to GRASS binaries and libraries:

export GRASS_DB_LOC=~/grassdata/test/PERMANENT
export GISBASE=/usr/local/Cellar/grass7/7.4.0/grass-7.4.0
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
export GRASS_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export PYTHONPATH="$GISBASE/etc/python:$PYTHONPATH"
export MANPATH=$MANPATH:$GISBASE/man
export GDAL_DATA=/usr/local/opt/gdal2/share/gdal/

## Grass

# remove all previous files
grass74 $GRASS_DB_LOC --exec g.remove name=${file%%.*}_cat type=vector -f
grass74 $GRASS_DB_LOC --exec g.remove name=${file%%.*}_dissolve type=vector -f
grass74 $GRASS_DB_LOC --exec g.remove name=${file%%.*}_subtract type=vector -f
grass74 $GRASS_DB_LOC --exec g.remove name=${file%%.*}_subtract_dissolve type=vector -f

#import file in question
grass74 $GRASS_DB_LOC --exec v.in.ogr input=$file output=${file%%.*} --overwrite

# adding a common background "category" that can be used to dissolve all the areas into one unit.

grass74 $GRASS_DB_LOC --exec v.category input=${file%%.*} option=add layer=2 output=${file%%.*}_cat cat=1 step=0 --overwrite

grass74 $GRASS_DB_LOC --exec v.dissolve input=${file%%.*}_cat layer=2 output=${file%%.*}_dissolve --overwrite

# Then subtract the dissolved catchment polygon from the administrative coverage of the country to leave the area uncovered per admin unit (LGU)

grass74 $GRASS_DB_LOC --exec v.overlay ainput=adm2 atype=area alayer=1 binput=${file%%.*}_dissolve btype=area blayer=2 out=${file%%.*}_subtract operator=not --overwrite

grass74 $GRASS_DB_LOC --exec v.dissolve input=${file%%.*}_subtract layer=1 output=${file%%.*}_subtract_dissolve col=a_HLCIT_CODE --overwrite

grass74 $GRASS_DB_LOC --exec v.db.join map=${file%%.*}_subtract_dissolve column=a_HLCIT_CODE layer=1 other_table=adm2 other_col=HLCIT_CODE subset_columns=sum --overwrite

# zonal statistics for population coverage, then calculating the relative percentage for each admin unit

grass74 $GRASS_DB_LOC --exec v.rast.stats map=${file%%.*}_subtract_dissolve layer=1 raster=wp_32644 column_prefix=catch_pop method=sum --overwrite

grass74 $GRASS_DB_LOC --exec v.db.addcolumn map=${file%%.*}_subtract_dissolve layer=1 columns="pc_uncov double precision"

grass74 $GRASS_DB_LOC --exec db.execute sql="UPDATE ${file%%.*}_subtract_dissolve SET pc_uncov=catch_pop_sum/sum"

# export to a geopackage
grass74 $GRASS_DB_LOC --exec v.out.ogr input=${file%%.*}_subtract_dissolve output=${file%%.*}_uncovered.gpkg --overwrite

# grass can't merge non-adjacent polygons with a common ID to a singlepart geometry, so gdal's ogr2ogr tool has to be used for the final step

ogr2ogr ${file%%.*}_final.shp ${file%%.*}_uncovered.gpkg -dialect sqlite -sql "SELECT ST_Union(geom) AS geom, AVG(sum) as adm_pop, AVG(catch_pop_sum) as catch_pop, AVG(pc_uncov) as pc_uncov, a_HLCIT_CODE FROM ${file%%.*}_subtract_dissolve GROUP BY a_HLCIT_CODE" -f "ESRI Shapefile"

# old

# grass74 $GRASS_DB_LOC --exec g.remove name=hf_ctch_subtract_dissolve type=vector -f

# grass74 $GRASS_DB_LOC --exec v.db.addtable map=hf_ctch_dissolve layer=1 columns="catch varchar"
#
# grass74 $GRASS_DB_LOC --exec v.db.update map=hf_ctch_dissolve layer=1 column=catch value="1"
#
# grass74 $GRASS_DB_LOC --exec v.edit tool=delete map=hf_ctch_union polygon=hf_ctch_dissolve
#
# grass74 $GRASS_DB_LOC --exec v.overlay ainput=adm2 binput=${file%%.*}_dissolve out=${file%%.*}_union operator=or
#
# grass74 $GRASS_DB_LOC --exec v.overlay ainput=adm2 binput=hf_ctch_dissolve out=hf_ctch_subtract operator=NOT
#
# grass74 $GRASS_DB_LOC --exec v.overlay ainput=adm2 binput=hf_ctch_dissolve blayer=2 out=hf_ctch_union2 operator=or --overwrite

#!/bin/bash

file=$1

echo "Analzying ${file%%.*}"

read type <<< $(echo ${file%%.*} | awk -F'[_]' '{print $1"_"$2}')
echo $type
mkdir $type

### gdal steps
#
# python ~/git/gdal_reclassify/gdal_reclassify.py ${file%%.*}.tif ${file%%.*}_reclass.tif -c "<0, <0.501, <1.01, <2.01, <4.01, <8.01, <16.01, <32.01, <100" -r "0, 1, 2, 3, 4, 5, 6, 7, 8" -d 0 -n true -p "COMPRESS=LZW";
#
# echo "Reclassification complete"
#
# python /Library/Frameworks/GDAL.framework/Programs/gdal_polygonize.py ${file%%.*}_reclass.tif -f "ESRI Shapefile" ${file%%.*}_cats.shp;
#
# echo "Vectorization complete"

### GRASS steps

# path to GRASS binaries and libraries:

export GRASS_DB_LOC=~/grassdata/test/PERMANENT
export GISBASE=/usr/local/Cellar/grass7/7.4.0/grass-7.4.0
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
export GRASS_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export PYTHONPATH="$GISBASE/etc/python:$PYTHONPATH"
export MANPATH=$MANPATH:$GISBASE/man
export GDAL_DATA=/usr/local/opt/gdal/share/gdal/

# GRASS commands. GRASS overlay is much faster than QGIS, ArcGIS or PostgreSQL union operations.

# grass74 -c -e -text shp/NPL_Adm2_poly_sd_32644.shp $GRASS_DB_LOC --exec v.in.ogr input=shp/NPL_Adm2_poly_sd_32644.shp output=adm2

grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT --exec v.in.ogr input=${file%%.*}_cats.shp output=${file%%.*}_cats

# grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT --exec v.overlay ainput=adm1 binput=${file%%.*}_cats out=${file%%.*}_adm1_union operator=or --overwrite

grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT --exec v.overlay ainput=adm2 binput=${file%%.*}_cats out=${file%%.*}_adm2_union operator=or

# # # grass74 $GRASS_DB_LOC --exec g.remove `type`=vector name=${file%%.*}_cats -f

# grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT -f --exec v.out.ogr input=${file%%.*}_adm1_union output=${file%%.*}_adm1.gpkg format=GPKG --overwrite
#
grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT -f --exec v.out.ogr input=${file%%.*}_adm2_union output=${file%%.*}_adm2.gpkg format=GPKG --overwrite

### PostgreSQL steps

# convert to SHP and import to PostGIS

# ogr2ogr -f "ESRI Shapefile" ${file%%.*}_adm1.shp ${file%%.*}_adm1.gpkg;
# shp2pgsql -s 32644 ${file%%.*}_adm1.shp public.${file%%.*}_adm1 > ${file%%.*}_adm1.sql;
# psql -h localhost -d poverty_analysis -f ${file%%.*}_adm1.sql;

ogr2ogr -f "ESRI Shapefile" ${file%%.*}_adm2.shp ${file%%.*}_adm2.gpkg;
shp2pgsql -s 32644 ${file%%.*}_adm2.shp public.${file%%.*}_adm2 > ${file%%.*}_adm2.sql;
psql -h localhost -d poverty_analysis -f ${file%%.*}_adm2.sql;

echo "Conversion and import done";

# SQL code

sqlfile=${file%%.*}_adm2.sql
sqlfile_popcalcs=${file%%.*}_adm2_popcalcs.sql


echo "SQL setup done";

echo "

---------

-- LGUs
ALTER TABLE ${file%%.*}_adm2 ADD COLUMN dissolve varchar;
UPDATE ${file%%.*}_adm2 SET dissolve=a_hlcit_co||'_'||b_DN;
DELETE FROM ${file%%.*}_adm2 WHERE dissolve IS NULL;

-- Optimization for queries

CREATE INDEX ${file%%.*}_adm2_gix ON ${file%%.*}_adm2 USING GIST (geom);
VACUUM ANALYZE ${file%%.*}_adm2
CLUSTER ${file%%.*}_adm2 USING ${file%%.*}_adm2_gix;

-- LGU Dissolve

CREATE TABLE ${file%%.*}_adm2_dissolve AS
SELECT
ST_Buffer(ST_Collect(p.geom),0) as geom, -- ST_Collect much faster than ST_Union, does not dissolve boundaries we want maintained. ST_Buffer with 0 parameter handles potential topology errors from ST_Collect.
p.dissolve as dissolve
FROM ${file%%.*}_adm2 p
GROUP BY p.dissolve;

-- Now add in LGU and travel category columns and populate values from the dissolve field

ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN adm_name varchar;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN adm2_code varchar;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN province varchar;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN trav_value int;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN trav_cat varchar;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN adm_pop double precision;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN cat_pop double precision;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN pc_pop double precision;

UPDATE ${file%%.*}_adm2_dissolve SET adm2_code=LEFT(dissolve,14);
UPDATE ${file%%.*}_adm2_dissolve SET province=SUBSTRING(dissolve,5,1);
UPDATE ${file%%.*}_adm2_dissolve SET trav_value=CAST(RIGHT(dissolve,1) as INTEGER);
UPDATE ${file%%.*}_adm2_dissolve SET adm_name=adm2.lu_name, adm_pop=adm2.sum FROM adm2 WHERE ${file%%.*}_adm2_dissolve.adm2_code = adm2.hlcit_code;
UPDATE ${file%%.*}_adm2_dissolve SET trav_cat = CASE
    WHEN trav_value = 1 THEN '0 to 30 minutes'
    WHEN trav_value = 2 THEN '30 minutes to 1 hour'
    WHEN trav_value = 3 THEN '1 to 2 hours'
    WHEN trav_value = 4 THEN '2 to 4 hours'
    WHEN trav_value = 5 THEN '4 to 8 hours'
    WHEN trav_value = 6 THEN '8 to 16 hours'
    WHEN trav_value = 7 THEN '16 to 32 hours'
    WHEN trav_value = 8 THEN '> 32 hours'
    END;

-- Re-optimization for future queries

CREATE INDEX ${file%%.*}_adm2_dissolve_gix ON ${file%%.*}_adm2_dissolve USING GIST (geom);
VACUUM ANALYZE ${file%%.*}_adm2_dissolve;

" >> $sqlfile;

echo "SQL part 1 writing done";

# execute SQL file

psql -h localhost -d poverty_analysis -f $sqlfile;

# perform population calculations

### command line interlude for rasterio zonalstats

# grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT --exec v.in.ogr input="PG:host=localhost port=5432 dbname='poverty_analysis' user=robert" layer=${file%%.*}_adm1_dissolve output=${file%%.*}_adm1_pop type=boundary,centroid
# grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT --exec v.rast.stats map=${file%%.*}_adm2_pop layer=1 raster=wp_32644 column_prefix=pop method=sum --overwrite
# grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT --exec v.out.ogr input=${file%%.*}_adm2_pop type=area output="PG:host=localhost dbname=poverty_analysis user=robert" output_layer=${file%%.*}_adm1_pop format=PostgreSQL
# grass74 /Volumes/TRANSCEND/GRASS/nepal/PERMANENT --exec v.out.postgis input=${file%%.*}_adm2_pop output="PG:host=localhost dbname=poverty_analysis user=robert"

pgsql2shp -f ${file%%.*}_adm2_popcalcs -h localhost -u robert poverty_analysis public.${file%%.*}_adm2_dissolve
fio cat ${file%%.*}_adm2_popcalcs.shp | rio zonalstats -r ./pop/NPL_pp_2015_adj_v2_utm44N.tif --prefix "pop_" --stats "count sum" > ${file%%.*}_adm2_pop.geojson
ogr2ogr -f "ESRI Shapefile" ${type}/${file%%.*}_adm2_pop.shp ${file%%.*}_adm2_pop.geojson
shp2pgsql -s 32644 ${type}/${file%%.*}_adm2_pop.shp public.${file%%.*}_adm2_pop > ${file%%.*}_adm2_pop.sql
psql -h localhost -d poverty_analysis -f ${file%%.*}_adm2_pop.sql

### SQL return for other population calculations

echo "
-- LGU population calculations

UPDATE ${file%%.*}_adm2_dissolve SET cat_pop=${file%%.*}_adm2_pop.pop_sum FROM ${file%%.*}_adm2_pop WHERE ${file%%.*}_adm2_dissolve.dissolve = ${file%%.*}_adm2_pop.dissolve;
UPDATE ${file%%.*}_adm2_dissolve SET pc_pop=((cat_pop/adm_pop)) WHERE adm_pop > 0;

-- Create table and export for R chart production

CREATE TABLE ${file%%.*}_adm2_r AS
  SELECT
  adm_name, adm2_code, province, trav_value, trav_cat, adm_pop,cat_pop,pc_pop
  FROM ${file%%.*}_adm2_dissolve;

COPY ${file%%.*}_adm2_r TO '/Volumes/TRANSCEND/TCR/Analysis/admin_181015/${type}/${file%%.*}_adm2.csv' WITH (FORMAT CSV, HEADER);

-- Re-optimization of spatial files for future queries

CREATE INDEX ${file%%.*}_adm2_dissolve_gix ON ${file%%.*}_adm2_dissolve USING GIST (geom);
VACUUM ANALYZE ${file%%.*}_adm2_dissolve

" >> $sqlfile_popcalcs;

echo "SQL part 2 writing done";

psql -h localhost -d poverty_analysis -f $sqlfile_popcalcs;

## export resulting shapefiles

# pgsql2shp -f ${type}/${file%%.*}_adm1_dissolve -h localhost -u robert poverty_analysis public.${file%%.*}_adm1_dissolve;
pgsql2shp -f ${type}/${file%%.*}_adm2_dissolve -h localhost -u robert poverty_analysis public.${file%%.*}_adm2_dissolve;

## Produce R charts

mkdir ${type}/charts

# Rscript R_CT_Adm1_Charts.r ${type}/${file%%.*}_adm1.csv ${type}/charts ${type}
Rscript R_CT_Adm2_Charts.r ${type}/${file%%.*}_adm2.csv ${type}/charts ${type}

## cleanup
#
# rm ${file%%.*}_adm1.*
# rm ${file%%.*}_adm2.*
# rm ${file%%.*}_adm1_popcalcs.*
# rm ${file%%.*}_adm2_popcalcs.*
# rm ${file%%.*}_adm1.sql
# rm ${file%%.*}_adm2.sql
# rm ${file%%.*}_pop.*
# rm $sqlfile
# rm $sqlfile_popcalcs
#
# ## Old Zonal Stats
#
# #### command line interlude for rasterio zonalstats
#
# # pgsql2shp -f ${file%%.*}_adm1_popcalcs -h localhost -u robert poverty_analysis public.${file%%.*}_adm1_dissolve
# # fio cat ${file%%.*}_adm1_popcalcs.shp | rio zonalstats -r ./pop/NPL_pp_2015_adj_v2_utm44N.tif --prefix "pop_" --stats "count sum" > ${file%%.*}_adm1_pop.geojson
# # ogr2ogr -f "ESRI Shapefile" ${type}/${file%%.*}_adm1_pop.shp ${file%%.*}_adm1_pop.geojson
# # shp2pgsql -s 32644 ${file%%.*}_adm1_pop.shp public.${file%%.*}_pop > ${file%%.*}_adm1_pop.sql
# # psql -h localhost -d poverty_analysis -f ${file%%.*}_adm1_pop.sql
# #
# # pgsql2shp -f ${file%%.*}_adm2_popcalcs -h localhost -u robert poverty_analysis public.${file%%.*}_adm2_dissolve
# # fio cat ${file%%.*}_adm2_popcalcs.shp | rio zonalstats -r ./pop/NPL_pp_2015_adj_v2_utm44N.tif --prefix "pop_" --stats "count sum" > ${file%%.*}_adm2_pop.geojson
# # ogr2ogr -f "ESRI Shapefile" ${file%%.*}_adm2_pop.shp ${file%%.*}_adm2_pop.geojson
# # shp2pgsql -s 32644 ${file%%.*}_adm2_pop.shp public.${file%%.*}_adm2_pop > ${file%%.*}_adm2_pop.sql
# # psql -h localhost -d poverty_analysis -f ${file%%.*}_adm2_pop.sql

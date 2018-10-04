#!/bin/bash

file=$1

echo "Analzying ${file%%.*}"

### gdal steps

python ~/git/gdal_reclassify/gdal_reclassify.py ${file%%.*}.tif ${file%%.*}_reclass.tif -c "<0, <0.501, <1.01, <2.01, <4.01, <8.01, <16.01, <32.01, <100" -r "0, 1, 2, 3, 4, 5, 6, 7, 8" -d 0 -n true -p "COMPRESS=LZW";

echo "Reclassification complete"

python /Library/Frameworks/GDAL.framework/Programs/gdal_polygonize.py ${file%%.*}_reclass.tif -f "ESRI Shapefile" ${file%%.*}_cats.shp;

echo "Vectorization complete"

### GRASS steps

# path to GRASS binaries and libraries:

export GRASS_DB_LOC=~/grassdata/test/PERMANENT
export GISBASE=/usr/local/Cellar/grass7/7.4.0/grass-7.4.0
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
export GRASS_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export PYTHONPATH="$GISBASE/etc/python:$PYTHONPATH"
export MANPATH=$MANPATH:$GISBASE/man
export GDAL_DATA=/usr/local/opt/gdal2/share/gdal/

# GRASS commands
#
# mkdir -p $GRASS_DB_LOC
#
# grass74 -c -e -text shp/NPL_Adm2_poly_sd_32644.shp $GRASS_DB_LOC --exec v.in.ogr input=shp/NPL_Adm2_poly_sd_32644.shp output=adm2
#
# grass74 $GRASS_DB_LOC --exec g.region -p
#
# grass74 $GRASS_DB_LOC --exec g.region vect=adm2

# grass74 $GRASS_DB_LOC --exec v.in.ogr input=${file%%.*}_cats.shp output=${file%%.*}_cats

grass74 $GRASS_DB_LOC --exec v.overlay ainput=adm2 binput=${file%%.*}_cats out=${file%%.*}_union operator=or

# grass74 $GRASS_DB_LOC --exec g.remove type=vector name=${file%%.*}_cats -f

grass74 $GRASS_DB_LOC --exec v.out.ogr input=${file%%.*}_union output=${file%%.*}_adm2.gpkg

### PostgreSQL steps

# convert to SHP and import to PostGIS

ogr2ogr -f "ESRI Shapefile" ${file%%.*}_adm2.shp ${file%%.*}_adm2.gpkg;
shp2pgsql -s 32644 ${file%%.*}_adm2.shp public.${file%%.*}_adm2 > ${file%%.*}_adm2.sql;
psql -h localhost -d poverty_analysis -f${file%%.*}_adm2.sql;

echo "Conversion and import done";

# SQL code

sqlfile=${file%%.*}.sql
sqlfile_popcalcs=${file%%.*}_popcalcs.sql

echo "SQL setup done";

echo "
-- LGUs
ALTER TABLE ${file%%.*}_adm2 ADD COLUMN dissolve varchar;
UPDATE ${file%%.*}_adm2 SET dissolve= a_hlcit_co||'_'||b_DN;
DELETE FROM ${file%%.*}_adm2 WHERE dissolve IS NULL;

-- Optimization for queries

CREATE INDEX ${file%%.*}_adm2_gix ON ${file%%.*}_adm2 USING GIST (geom);
VACUUM ANALYZE ${file%%.*}_adm2
CLUSTER ${file%%.*}_adm2 USING ${file%%.*}_adm2_gix;

-- LGU Dissolve

CREATE TABLE ${file%%.*}_adm2_dissolve AS
SELECT
ST_Buffer(ST_Collect(p.geom),0) as geom, -- ST_Collect much faster than ST_Union, does not dissolve boundaries we want maintained. ST_Buffer wiht 0 parameter handles potential topology errors from ST_Collect.
p.dissolve as dissolve
FROM ${file%%.*}_adm2 p
GROUP BY p.dissolve;

-- Now add in LGU and travel category columns and populate values from the dissolve field

ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN adm_name varchar;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN adm_code varchar;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN trav_value int;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN trav_cat varchar;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN adm_pop double precision;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN cat_pop double precision;
ALTER TABLE ${file%%.*}_adm2_dissolve ADD COLUMN pc_pop decimal (5,4);

UPDATE ${file%%.*}_adm2_dissolve SET adm_code=LEFT(dissolve,14);
UPDATE ${file%%.*}_adm2_dissolve SET trav_value=CAST(RIGHT(dissolve,1) as INTEGER);
UPDATE ${file%%.*}_adm2_dissolve SET adm_name=LGU.lu_name, adm_pop=LGU.sum FROM LGU WHERE ${file%%.*}_adm2_dissolve.adm_code = LGU.hlcit_code;
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

REINDEX INDEX ${file%%.*}_adm2_dissolve_gix;
VACUUM ANALYZE ${file%%.*}_adm2_dissolve
CLUSTER ${file%%.*}_adm2_dissolve USING ${file%%.*}_adm2_dissolve_gix;

" >> $sqlfile;

echo "SQL part 1 writing done";

# execute SQL file

psql -h localhost -d poverty_analysis -f $sqlfile;

## perform population calculations

#### command line interlude for rasterio zonalstats

pgsql2shp -f ${file%%.*}_adm2_popcalcs -h localhost -u robert poverty_analysis public.${file%%.*}_adm2_dissolve
fio cat ${file%%.*}_adm2_popcalcs.shp | rio zonalstats -r NPL_pp_2015_adj_v2_utm44N.tif --prefix "pop_" --stats "count sum" > ${file%%.*}_pop.geojson
ogr2ogr -f "ESRI Shapefile" ${file%%.*}_pop.shp ${file%%.*}_pop.geojson
shp2pgsql -s 32644 ${file%%.*}_pop.shp public.${file%%.*}_pop > ${file%%.*}_pop.sql
psql -h localhost -d poverty_analysis -f ${file%%.*}_pop.sql

#### SQL return for other population calculations

echo "
-- Population calculations

UPDATE ${file%%.*}_adm2_dissolve SET cat_pop=${file%%.*}_pop.pop_sum FROM ${file%%.*}_pop WHERE ${file%%.*}_adm2_dissolve.dissolve = ${file%%.*}_pop.dissolve;
UPDATE ${file%%.*}_adm2_dissolve SET pc_pop=((cat_pop/adm_pop)*100) WHERE adm_pop > 0;

-- Create table and export for R chart production

CREATE TABLE ${file%%.*}_adm2_R AS
  SELECT
  adm_name, adm_code, trav_value, trav_cat, adm_pop,cat_pop,pc_pop
  FROM ${file%%.*}_adm2_dissolve;

COPY ${file%%.*}_adm2_R TO '/Users/robert/Desktop/Staging/script_test/${file%%.*}_adm2_R.csv' WITH (FORMAT CSV, HEADER);

-- Re-optimization of spatial files for future queries

REINDEX INDEX ${file%%.*}_adm2_dissolve_gix;
VACUUM ANALYZE ${file%%.*}_adm2_dissolve
CLUSTER ${file%%.*}_adm2_dissolve USING ${file%%.*}_adm2_dissolve_gix;

" >> $sqlfile_popcalcs;

echo "SQL part 2 writing done";

psql -h localhost -d poverty_analysis -f $sqlfile_popcalcs;

## export resulting shapefile

pgsql2shp -f ${file%%.*}_adm2_dissolve -h localhost -u robert poverty_analysis public.ct_nm_med_180824_adm2_dissolve;

## Produce R charts

mkdir ${file%%.*}_charts

Rscript R_LGU_CT_Charts.r ${file%%.*}_adm2_R.csv ${file%%.*}_charts

## cleanup

rm ${file%%.*}_adm2.*
rm ${file%%.*}_adm2_popcalcs.*
rm ${file%%.*}_adm2.sql
rm ${file%%.*}_pop.*
rm $sqlfile
rm $sqlfile_popcalcs

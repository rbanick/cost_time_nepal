# Cost Time Analysis of Nepal

A scripted routine for analyzing Cost Time accessibility rasters for various facility types in Nepal. These are prepared in a separate ArcGIS Model Builder environment.

The Classification Analysis script divides the rasters into zones, polygonizes them, aggregates the population for each and creates summary charts for every local government unit from the results.

The Catchment Analysis script merges all the calculated facility catchment areas, subtracts them from administrative units, calculates the population uncovered per admin unit and returns a shapefile.

These scripts involve a lot of moving parts. This is because QGIS and ArcGIS both crashed on the Union and Dissolve operations, which involve huge datasets. Thus GRASS and PostGIS are required. My system Python is scrambled at the moment so command line was preferred, although I would like to develop this into a Python script in the future. In the shorter term I may consolidate around GRASS as I'm slowly figured out how to make it as responsive as PostGIS.

This script is a work in progress with acknowledge flaws. There are inefficiencies and ugly workarounds for my problematic Python and partial GRASS knowledge. Comments / PRs are always welcome.

## Dependencies

These scripts are designed to work on a UNIX based environment using primarily bash and command line tools.

The primary tools used are
* GRASS 7.4
* PostgreSQL / PostGIS (10.5)
* GDAL 2.3.1
* Python 2.7
* Fiona and Rasterstats python libraries
* R

I advise using `homebrew` and `pip` to install the above for consistencies sake.

## Setting up

#### GRASS
Command line GRASS unfortunately requires declaring quite a few variables ahead of time. You will need to modify the script to reflect the GRASS binary paths in your own system. Additionally, several GRASS commands used during initial setup are commented out for easy future access.

#### PostgreSQL

The bash script assumes all files are in UTM 44N projection, EPSG:32644. This can be changed.

The bash script assumes a PostgreSQL database with the PostGIS extension. Mine is named _poverty_analysis_ but another name can easily be substituted. The database should contain a WorldPop raster dataset named _wp_32644_ and an LGU dataset with population per LGU named _LGU_.

#### R

R uses the following libraries, which should be installed ahead of time
* ggplot2
* scales
* extrafont
* dplyr
* reshape2
* forcats
* quantmod
* directlabels
* grid
* gridExtra

## Using the scripts

### Isochrone (travel classification) analysis
*For a single file*
From the Terminal run
```
chmod u+x adm1_pop_analysis.sh
./adm1_pop_analysis.sh /path/to/your_raster_file /path/to/your_chart_folder
```

*For a folder of files*
From the Terminal run
```
chmod u+x all_ct_batch.sh
chmod u+x adm1_pop_analysis.sh
./master_lgu_pop_analysis.sh /path/to/your_raster_file /path/to/your_chart_folder
```

Name your rasters carefully as their names will be recycled throughout the script and determine the output shapefile name.

### Facility catchment analysis
*For a single file*
From the Terminal run
```
chmod u+x catchment_analysis.sh
./catchment_analysis.sh /path/to/catchment/shapefile/the_file.shp
```

*For a folder of files*
From the Terminal run
```
chmod u+x lgu_catch_batch.sh
./lgu_catch_batch.sh
```

## Development plans

This will be developed into a batch script shortly for easy analysis of bundles of raster files

Eventually this will be integrated with a Python script for accessibility map production via QGIS's Atlas function.

I would like to develop this into a cleaner Python script but don't have the time at the moment.

In a beautiful world we would set up a server to run these processes automatically. Whether that happens depends on observed demand and the practical feasibility of moving large raster files around over Nepali internet connections.

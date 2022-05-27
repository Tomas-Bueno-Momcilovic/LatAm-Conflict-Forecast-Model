Author: Tomas Bueno dos Santos Momcilovic
Date: 29.4.2022

This is a replication package for the final project in the (SOT863102) Machine Learning for Social Sciences (PhD) seminar at the Technical University of Munich.

The project represents an implementation of decision tree and random forest models for forecasting conflict in Latin America and Caribbean. The models use water access data and summary data on previous conflicts as the independent variables for estimating future conflict events. The model is a partial replication of Kuzma et al. (2020) implementation of the random forest model using 50 additional variables.

Run the master.R file to replicate the results, which are stored in the /results/ folder.

###### REFERENCES AND DEPENDENCIES ######

Work inspired by: 
Kuzma, S., P. Kerins, E. Saccoccia, C. Whiteside, H. Roos, & C. Iceland. (2020). Leveraging Water Data in a Machine Learning–Based Model for Forecasting Violent Conflict. Technical Note. Washington, DC: World Resources Institute. Retrieved from:www.wri.org/publication/leveraging-water-data

This work is based on the following data sources:
- ACLED data on armed conflicts and event data in Latin America (Mexico, South and Central America) and the Carribean, downloaded on 2nd May 2022 from https://acleddata.com/data-export-tool/
- International Food Policy Research Institute SPAM dataset on crop production statistics for 2010 Version, downloaded on 3rd May 2022 from https://www.mapspam.info/data/
- WHO and UNICEF data on drinking water access, downloaded on 2nd May 2022 from https://washdata.org/data/downloads
-Global Administrative Areas shapefile data on country administrative areas, downloaded on 2nd May 2022 from http://www.gadm.org

###### DATA DOWNLOAD INSTRUCTIONS AND QGIS PREPARATION ######

To export the ACLED dataset, open an account on developer.acled.org and generate an API key. To more easily load the dataset, change name to "latinamerica".

Spatial joins between GADM and SPAM have been performed in QGIS v3.16.3-Hannover. Resulting data is available in a separate qgis folder and QGIS project (QGIS_preprocessing.qgz).

Procedure to replicate the process is as follows:
1. Download GADM world shapefile (or geopackage) and SPAM world dataset;
2. Load the GADM dataset in QGIS, select Latin America and Carribbean using an expression for selecting administrative codes covered by the ACLED dataset, and save the selection as separate layer;
3. Reduce the SPAM world dataset in Excel (or R) using similar procedure for filtering, and load in QGIS as Delimited Text Layer (Projection EPSG-4326 - WGS84);
4. Use "Join attributes by location (summary)" in the Processing Toolbox to spatially combine GADM polygons and SPAM points, and select only relevant columns and indicated value for summarizing.
5. Export as CSV

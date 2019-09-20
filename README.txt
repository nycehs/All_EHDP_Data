**READ ME**

Data downloaded via the 'Build A Table' / 'Customize A Dataset' function of the NYC Department of Health and Mental Hygiene (DOHMH) Environment and Health Data Portal is currently separated into two linked data files, All_EHDP_data.csv and All_EHDP_metadata.csv.

All_EHDP_data.csv contains actual data values along with relevant information on the associated Geography, Year, Measure Type, and subject matter. The 'Indicator_ID' field designates a code number for unique subject matter, that can be joined to the source information in the other file. Many records in the Data file may be associated with a single record in the Metadata file.

Data Dictionary: 
unique_id	A number for identifying file records uniquely
indicator_id	An identification number for the named indicator (can use to join with Source metadata)
name		The indicator name spelled out
measure		How the indicator data is measured (such as count, percentage, rate)
geo_type_name	The name of the geography type - this could be Boroughs, Community Districts, or several others
geo_join_id	An identification code to be used to join the record to an area geometry for mapping
geo_place_name	The place name of the geography
time_period	The time period the data value applies to - could be a single year or multi-year estimate, or even quarterly or seasonal data
start_date	The date which the time period starts (helpful for accurate graphing)
data_value	The actual data value estimate for the indicator in this time period and geographic area
message		Notes about the data value - here is indicated warnings about data reliability for the estimate, if any
confidence_interval	When available, here are the bounds for the 95% confidence interval for the estimate


All_EHDP_metadata.csv provides metadata describing the data in the first file with the matching value in the 'Indicator_ID' field. The files can be joined or linked using this field. 


Geography notes:  For mapping purposes, download shapefiles or geoJSON files containing portal geographies on the upper right corner of the 'Build A Table' / data download page: http://a816-dohbesp.nyc.gov/IndicatorPublic/BuildATable.aspx  


Suggested Citation – Portal Data Visualizations and Downloads
New York City Department of Health and Mental Hygiene. NYC Tracking Program: Environment and Health Data Portal. [Indicator; YEAR(S) – e.g., Adults with Asthma in the Past 12 Months; 2007-2009]. [DATE VIEWED HERE]. http://nyc.gov/health/tracking  

Suggested Citation – Portal Neighborhood Reports
New York City Department of Health and Mental Hygiene. NYC Tracking Program: Environment and Health Data Portal. [REPORT TITLE: NEIGHBORHOOD NAME – e.g., Housing and Health: East Harlem]. [DATE VIEWED HERE]. http://nyc.gov/health/tracking  



NYC Department of Health and Mental Hygiene
NYC Environmental Public Health Tracking Portal
Available at: http://nyc.gov/health/tracking



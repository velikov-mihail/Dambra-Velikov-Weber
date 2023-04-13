# Dambra, Velikov, and Weber (WP, 2023)

Code and steps used to create results in Dambra, Velikov, and Weber (WP, 2023), Disclosure, Materiality Thresholds, and the Cost of Capital: Evidence from FOMC Announcements

This repository contains code used to create the results in Dambra, Velikov, and Weber (WP, 2023), Disclosure, Materiality Thresholds, and the Cost of Capital: Evidence from FOMC Announcements. This code is to be used in conjunction with the MATLAB asset pricing package that accompanies Novy-Marx and Velikov (WP, 2023), Assaying Anomalies.

The manuscript utilizes data gleaned from the following datasets:
1.	Stock return data from CRSP
2.	Accounting data from Compustat
3.	FOMC dates from the Federal Reserve
4.	FOMC surprises from Ken Kuttner’s website, from Journal of Finance data addendum for Gürkaynak, Karasoy-Can and Lee (JF, 2022), and from Silvia Miranda-Agrippino's website
5.	Institutional ownership from Thomson Reuters
6.	Mergers & acquisitions, loan issuance, and bond issuance from SDC
7.	8K data from WRDS SEC Analytics Suite – List of 8K Items
8.	Press release data from Ravenpack
9.	Analyst coverage and forecasts, and management forecast IBES Summary

The order of operations to replicate the results in Dambra, Velikov, and Weber (WP, 2023) is:

1. Download the code and follow the instructions for setting up the MATLAB asset pricing package from https://github.com/velikov-mihail/AssayingAnomalies
 	* The results in Dambra, Velikov, and Weber (2023) use the beta v0.4 version. 
2. Obtain all the necessary input datasets:
	* FOMC dates from the Federal Reserve (Excel file included, FOMC_dates.csv)
	* FOMC surprises from Kenn Kuttner's website (dailyFsurprises.xls): 
		Programatically downloaded from https://docs.google.com/spreadsheets/d/1Up04KzMYug9zyKWYFdrOgQD7S6n_Q7d7/edit?usp=sharing&ouid=109945391180428182262&rtpof=true&sd=true
	* FOMC surprises from Journal of Finance supplementary information addendum for Gürkaynak, Karasoy-Can and Lee (JF, 2022) (jofi13163-sup-0002-replicationcode.zip):
		Programatically downloaded from https://onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1111%2Fjofi.13163&file=jofi13163-sup-0002-ReplicationCode.zip
	* FOMC surprises from Silvia Miranda-Agrippino's website
		Programatically downloaded from http://silviamirandaagrippino.com/s/Instruments_web-x8wr.xlsx
	* InstOwnership - Run the institutional ownership concentration and breadth ratios code available on WRDS (io_timeseries.csv):
		Manually run from https://wrds-www.wharton.upenn.edu/pages/support/applications/institutional-ownership-research/institutional-ownership-concentration-and-breadth-ratios/
	* Expected Return Proxies (ERP) data from Lee, So, and Wang's (2022) library (erp_public_221025.csv):
		Manually downloaded from https://leesowang2021.github.io/data/
	* SDC M&A, Bond, and Loan issuance data
		Manually downloaded from SDC through Thomson One Banker and stored in .xlsx files. Screenshots of the filters used included. 
3. Download the code in this repository and run the following files:
	* Run the MATLAB file dvw.m, which calls several different sripts with the following functions:
		* download_wrds_data.m downloads the necessary datasets from WRDS
		* make_mpe.m creates the MPE indicator from Ozdagli and Velikov (2020)
		* make_io_data.m imports and stores a matrix with the institutional ownership data
		* make_erp_data.m imports and stores a structure with matrices with the ERP data
		* make_cik_cusip_link.m imports and stores the CIK/CUSIP linking data
		* make_fomc_surprises.m imports and stores the FOMC surprises
		* make_ccm_data.m imports and stores data from the CRSP/COMPUSTAT merged database and organizes the pooled FOMC/intermeeting period dataset
		* make_sdc_data.m imports and stores the data from SDC
		* make_8k_data.m imports and stores the 8K data from SEC analytics
		* make_ravenpack_data.m imports and stores the Ravenpack press release data		
		* make_8k_ravenpack_merge.m merges the 8K and Ravenpack datasets
		* make_ibes_guidance_data.m imports and stores the IBES earnings guidance/management forecast data
		* make_ibes_analyst_forecast_data.m imports and stores the IBES analyst forecast data
		* make_ibes_num_rec.m imports and stores the IBES data on number of recommendations
		* merge_data.m merges all the datasets and stores a final_data.csv file to be used for estimation
	* Run the STATA file dvw.do, which runs all the estimations and stores all the tables in the paper

		
	
		
	
	

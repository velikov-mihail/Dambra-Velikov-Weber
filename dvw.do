/* DVW April 12, 2023*/

* Set key macros for the Stata program:
set more off, permanently
clear all

import delimited "D:\Published Repos\Dambra-Velikov-Weber\Dambra-Velikov-Weber\Data\final_data.csv", numericcols(2/200) clear 

encode cusip, gen(cusip_n)

summarize netpctup_fpi1 netpctup_fpi2 

drop if instownership == .| periodreturn == .|periodilliquidity == .|roa == .|ln_mcap == .

*Dividing surprises by 100 for expositional purposes
gen targetsurprise_bp =  targetsurprisestartofperiod/100
gen pathsurprise_bp = pathsurprisestartofperiod/100
gen targetchange_bp = targetchangestartofperiod/100
gen mpisurprise1_bp = iv1startofperiod
gen mpisurprise5_bp = iv5startofperiod

local w1 "mpe ln_mcap ln_cov roa btm leverage periodreturn periodvolatility periodilliquidity instownership netshareissuance  periodreturn3wk periodilliquidity3wk periodvolatility3wk"
local w2 "nonea_8k_n ln_nonea_8k_n ln_sec_201_8k_delayed_n ln_nonea_8k_3wk_n ln_rp_nonea_3wk_n ln_any_guidance_3wk_n"
local w3 "ln_sec_material_8k_n ln_sec_nonmaterial_8k_n ln_sec201_8k_n"
local w4 "rp_total_n rp_nonea_n rp_product_n rp_mnap_n ln_rp_total ln_rp_nonea_n ln_rp_product_n ln_rp_mnap_n rp_marketing_n ln_rp_marketing_n rp_other_n ln_rp_other_n rp_labor_n ln_rp_labor_n rp_finance_n ln_rp_finance_n"
local w5 "rp_debt_n ln_rp_debt_n rp_equity_n ln_rp_equity_n rp_ea_n ln_rp_ea_n nip ess peq"
local w6 "any_guidance_n ln_any_guidance_n eps_guidance_n ln_eps_guidance_n d_meanest_fpi1 d_meanest_fpi2 d_medest_fpi1 d_medest_fpi2"
local w7 "erp_ccc erp_icca"
winsor2 `w1' `w2' `w3' `w4' `w5' `w6' `w7' ,suffix(_w) cuts(1 99) by(periodnumber) 

local file "D:\Published Repos\Dambra-Velikov-Weber\Dambra-Velikov-Weber"

rename *, lower


/*Dependent Variables*/
label variable rp_total_d  	"PR Ind."
label variable rp_total_n_w  	"No. of PRs"
label variable ln_rp_total_n_w  "Ln(1+No. of PRs)"
label variable rp_nonea_d  	"PR Ind."
label variable rp_nonea_n_w  	"No. of PRs"
label variable ln_rp_nonea_n_w  "Ln(1+No. of PRs)"
label variable eps_guidance_d 		"MEF Ind."
label variable ln_eps_guidance_n_w "Ln(1+No. of MEFs)"
label variable ln_any_guidance_n_w "Ln(1+No. of MFs)"
label variable any_guidance_d 		"MF Ind."
label variable ln_rp_nonea_3wk_n_w  "Ln(1+No. of PRs 3W)"
label variable ln_any_guidance_3wk_n_w 	"Ln(1+No. of MFs 3W)"
label variable ln_nonea_8k_3wk_n_w		"Ln(1+8Ks 3W)"
label variable any_guidance_3wk_d 		"MF 3W Ind."
label variable rp_nonea_3wk_d 		"PR 3W Ind."
label variable nonea_8k_3wk_d 		"8K 3W Ind."
label variable nonea_8k_d	"8K Ind."
label variable nonea_8k_n_w	"No. Non-EA 8Ks"
label variable ln_nonea_8k_n_w	"Ln(1+8Ks)"

/*Modifying Variables*/
label variable mpe_w  "MPE Index"
label variable mean_mpe_tv  "High MPE Ind."
label variable netshareissuance "Pct Ch in Shares"
label variable targetsurprise_bp "Target Surp."
label variable pathsurprise_bp "Path Surp."
label variable mpisurprise1_bp "MPI Surp."
label variable mpisurprise5_bp "MPI Surp."

/*Control Variables*/
label variable ln_mcap_w  "Ln(1+ Market Cap)"
label variable ln_cov_w  "Ln(1 + Analysts)"
label variable roa_w  "ROA"
label variable btm_w  "Book-to-Market"
label variable leverage_w  "Leverage"
label variable periodreturn_w  "Return"
label variable periodvolatility_w "Return Volatility"
label variable periodilliquidity_w "Illiquidity"
label variable periodreturn3wk_w  "Return 3W"
label variable periodvolatility3wk_w "Return Volatility 3W"
label variable periodilliquidity3wk_w "Illiquidity 3W"
label variable instownership_w "IO Pct."
label variable any_issue_d "Issue Ind."

/*Fixed Effects & Miscellaneous*/
label variable cusip_n  "Firm"
label variable periodnumber  "MPE Meeting No."
label variable year  "Year"

label variable erp_ccc_w "ERP ICC"
label variable erp_icca_w "ERP ICCA"



local indvar1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv"
local indvar2 "c.targetsurprise_bp#c.mean_mpe_tv c.pathsurprise_bp_w#c.mean_mpe_tv mean_mpe_tv"
est clear

gen novary = 0
replace novary = 1 if periodstart >= 20081216 & periodend <= 20151231

local yvar "nonea_8k_d ln_nonea_8k_n_w rp_nonea_d ln_rp_nonea_n_w any_guidance_d ln_any_guidance_n_w"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 

/*Table 1 - Descriptive Statistics*/
asdoc sum `yvar' targetsurprise_bp mean_mpe_tv `control' if (novary==0 & periodend >= 20040823), save(Results.doc) append stats(N min p25 mean p50 p75 max sd) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 1 - Descriptive Statistics)

/*Table 2 - Descriptive Statistics by MPE*/
bys mean_mpe_tv: asdoc sum `yvar' `control' if (novary==0 & periodend >= 20040823),  save(Results.doc) append stats(N mean p50) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 2 - Descriptive Statistics by FOMC Surp. Sensitivity)

/*Table 3 - Descriptive Statistics by FF Industry*/
bys ff10: asdoc sum nonea_8k_d if (novary==0 & periodend >= 20040823), save(Results.doc) append stats(N) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 3 - Sample Decomposition by Industry)
bys ff10: asdoc sum nonea_8k_d if (novary==0 & periodend >= 20040823), save(Results.doc) append stats(mean) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 3 - Sample Decomposition by Industry)
bys ff10: asdoc sum rp_nonea_d if (novary==0 & periodend >= 20040823), save(Results.doc) append stats(mean) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 3 - Sample Decomposition by Industry)
bys ff10: asdoc sum any_guidance_d if (novary==0 & periodend >= 20040823), save(Results.doc) append stats(mean) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 3 - Sample Decomposition by Industry)

/*Table 4 - Non-Earnings 8Ks Table*/
local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 
local file "D:\Published Repos\Dambra-Velikov-Weber\Dambra-Velikov-Weber"

eststo clear

eststo: reghdfe nonea_8k_d `indvar1' `control' if periodend >= 20040823  & novary == 0 , absorb(`fe1') cluster(`clust')
est store e1 
eststo: reghdfe ln_nonea_8k_n_w `indvar1' `control' if periodend >= 20040823 & novary == 0 , absorb(`fe1') cluster(`clust')
est store e2 
eststo: reghdfe nonea_8k_d `indvar1' `control' if periodend >= 20040823  & novary == 0 & ever_8k==1, absorb(`fe1') cluster(`clust')
est store e3 
eststo: reghdfe ln_nonea_8k_n_w `indvar1' `control' if periodend >= 20040823 & novary == 0 & ever_8k==1, absorb(`fe1') cluster(`clust')
est store e4 

esttab e1 e2 e3 e4 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 4: Effect of FOMC Meeting Surprises on 8-Ks, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 

/*Table 5 - Linear Model Non-Earnings Press Releases*/
local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 
est clear

eststo:  reghdfe rp_nonea_d `indvar1' `control' if periodend >= 20040823 & novary == 0 , absorb(`fe1') cluster(`clust')
est store e1 
eststo:  reghdfe  ln_rp_nonea_n_w `indvar1' `control' if periodend >= 20040823 & novary == 0 , absorb(`fe1') cluster(`clust')
est store e2 
eststo:  reghdfe rp_nonea_d `indvar1' `control' if periodend >= 20040823 & novary == 0 & ever_rp==1, absorb(`fe1') cluster(`clust')
est store e3 
eststo:  reghdfe  ln_rp_nonea_n_w `indvar1' `control' if periodend >= 20040823 & novary == 0 & ever_rp ==1, absorb(`fe1') cluster(`clust')
est store e4 


esttab e1 e2 e3 e4 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 5: Effect of FOMC Meeting Surprises on Press Releases, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 

/* Table 6 - Linear Model Management Forecasts*/
local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 
est clear

eststo:  reghdfe any_guidance_d `indvar1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e1 
eststo:  reghdfe  ln_any_guidance_n_w `indvar1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e2 
eststo:  reghdfe any_guidance_d `indvar1' `control' if periodend >= 20040823 & ever_guid==1 & novary == 0, absorb(`fe1') cluster(`clust')
est store e3 
eststo:  reghdfe  ln_any_guidance_n_w `indvar1' `control' if periodend >= 20040823 & ever_guid==1 & novary == 0, absorb(`fe1') cluster(`clust')
est store e4 

esttab e1 e2 e3 e4 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 6: Effect of FOMC Meeting Surprises on Management Forecasts, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 



/*Table 7 - Panel A: Materiality vs. non-materiality based 8K Items Sample Averages*/
label variable sec_material_8k_d "8K Materiality Based Other Ind."
label variable sec_nonmaterial_8k_d "8K Not Materiality Based Ind."
label variable sec_material_8k_d "L8K Materiality Based Other Ind."
label variable ln_sec_material_8k_n_w "Ln(1+Materiality Based 8Ks)"
label variable ln_sec_nonmaterial_8k_n_w "Ln(1+Non-Materiality Based 8Ks)"

gen tablex = 1
asdoc tabstat ln_sec_material_8k_n_w ln_sec_nonmaterial_8k_n_w if (novary==0 & periodend >= 20040823), save(Results.doc) append by(tablex) columns(variables) stats(mean) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 7 Panel A - 8K Materiality Descriptive Statistics)

* Column 3:
summarize ln_sec201_8k_n_w  if acquisitionscount != . & periodend >= 20040823 & novary==0


/*Table 7, Panel B: Materiality vs. non-materiality based 8K Items OLS regressions*/
est clear

local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 

eststo: reghdfe  ln_sec_material_8k_n_w `indvar1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e1
eststo: reghdfe  ln_sec_nonmaterial_8k_n_w `indvar1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e2 
eststo: reghdfe ln_sec201_8k_n_w `indvar1' `control' if acquisitionscount != . & periodend >= 20040823 & novary==0, absorb(`fe1') cluster(`clust')
est store e3 

esttab e1 e2 e3 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 7 Panel A: Materiality, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 



/*Table 7 - Panel C: Press release topics sample averages*/
label variable nip_w "NIP"
label variable ln_rp_product_n_w 	"Ln(1+Product Related PRs)"
label variable ln_rp_mnap_n_w 		"Ln(1+M&A Related PRs)"
label variable ln_rp_marketing_n_w  	"Ln(1+Marketing Related PRs)"
label variable ln_rp_other_n_w  		"Ln(1+Other PRs)"
label variable ln_rp_labor_n_w  		"Ln(1+Labor-Related PRs)"
label variable ln_rp_equity_n_w  	"Ln(1+Equity-Related PRs)"
label variable ln_rp_debt_n_w  		"Ln(1+Debt-Related PRs)"

asdoc tabstat nip ln_rp_product_n_w ln_rp_labor_n_w ln_rp_marketing_n_w ln_rp_mnap_n_w ln_rp_equity_n_w ln_rp_debt_n_w ln_rp_other_n_w if periodend >= 20040823 & novary==0, save(Results.doc) append by(tablex) columns(variables) stats(mean) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 7 Panel C PR Group Categories)



/*Table 7, Panel D: Press release topics regression analysis  */
est clear

local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 

eststo: reghdfe nip_w `indvar1' `control' if periodend >= 20040823 & novary==0, absorb(`fe1') cluster(`clust')
est store e1
eststo: reghdfe ln_rp_product_n_w `indvar1' `control'  if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e2 
eststo: reghdfe  ln_rp_labor_n_w `indvar1' `control'  if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e3 
eststo: reghdfe  ln_rp_marketing_n_w `indvar1' `control'  if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e4 
eststo: reghdfe ln_rp_mnap_n_w `indvar1' `control'  if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e5 
eststo: reghdfe  ln_rp_equity_n_w `indvar1' `control'  if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e6
eststo: reghdfe  ln_rp_debt_n_w `indvar1' `control'  if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e7 
eststo: reghdfe  ln_rp_other_n_w `indvar1' `control'  if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e8 

esttab e1 e2 e3 e4 e5 e6 e7 e8  using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 7 Panel B: Effect of FOMC Meeting Surprises on Press Releases by Group (Cont.), `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 



/* Table 8: Cross-sectional variationa of the effect of FOMC Target surprises with capital issues */
/*Equity Issuance Triple Difference*/

local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local control2 "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w" 
local 3d "c.targetsurprise_bp##c.mean_mpe_tv##c.any_issue_d"

eststo: reghdfe nonea_8k_d `3d' `control2' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e1 
eststo: reghdfe rp_nonea_d `3d' `control2' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e2 
eststo: reghdfe any_guidance_d `3d' `control2' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e3 
eststo: reghdfe ln_nonea_8k_n_w `3d' `control2' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e4 
eststo: reghdfe ln_rp_nonea_n_w `3d' `control2' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e5 
eststo: reghdfe ln_any_guidance_n_w `3d' `control2' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e6
 
esttab e1 e2 e3 e4 e5 e6 using "Results.rtf", append compress nogaps onecell b(4) varwidth(15) modelwidth(7) title("Table 8: X-S Effect of FOMC Meeting Surprises by Capital Issuance, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 



/* Table 9: FOMC Target surprises and hype */
/* Panel A: Sample averages for press release tone variables */

asdoc tabstat ess peq if periodend >= 20040823 & novary==0, append save(Results.doc) by(tablex) columns(variables) stats(mean) label font(Times New Roman) fhc(\b) compress dec(3) tzok title(Table 9 Panel A Sample averages for press release tone variables)


/* Panel B: OLS regressions for press release tone variables */
local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 

eststo: reghdfe ess_w `indvar1' `control' if periodend >= 20040823 & novary==0, absorb(`fe1') cluster(`clust')
est store e1 
eststo: reghdfe peq_w `indvar1' `control' if periodend >= 20040823 & novary==0, absorb(`fe1') cluster(`clust')
est store e2 

esttab e1 e2 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 9: Within Disclosure and Common Economic Event Analysis, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 



/* Table 10: Alternative FOMC Policy Surprise Design */
/* Panel A: Incorporate FOMC Path surprises  */
est clear
local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 
local indvar2 "c.targetsurprise_bp#c.mean_mpe_tv c.pathsurprise_bp#c.mean_mpe_tv mean_mpe_tv"

eststo: reghdfe nonea_8k_d `indvar2' `control' if periodend >= 20040823 , absorb(`fe1') cluster(`clust')
est store e1 
eststo: reghdfe rp_nonea_d `indvar2' `control' if periodend >= 20040823 , absorb(`fe1') cluster(`clust')
est store e2 
eststo: reghdfe any_guidance_d `indvar2' `control' if periodend >= 20040823  , absorb(`fe1') cluster(`clust')
est store e3 
eststo: reghdfe ln_nonea_8k_n_w `indvar2' `control' if periodend >= 20040823  , absorb(`fe1') cluster(`clust')
est store e4 
eststo: reghdfe ln_rp_nonea_n_w `indvar2' `control' if periodend >= 20040823  , absorb(`fe1') cluster(`clust')
est store e5 
eststo: reghdfe ln_any_guidance_n_w `indvar2' `control' if periodend >= 20040823  , absorb(`fe1') cluster(`clust')
est store e6
	 
esttab e1 e2 e3 e4 e5 e6 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 10 Panel A: Target and Path Surprises, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 

/* Panel B: Excluding time fixed effects  */
est clear
local clust "cusip_n"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 
local fe3  "cusip_n"
local indvar2_1 "c.targetsurprise_bp#c.mean_mpe_tv mean_mpe_tv targetsurprise_bp"

eststo: reghdfe nonea_8k_d `indvar2_1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe3') cluster(`clust')
est store e1 
eststo: reghdfe rp_nonea_d `indvar2_1' `control' if periodend >= 20040823 & novary == 0 , absorb(`fe3') cluster(`clust')
est store e2 
eststo: reghdfe any_guidance_d `indvar2_1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe3') cluster(`clust')
est store e3 
eststo: reghdfe ln_nonea_8k_n_w `indvar2_1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe3') cluster(`clust')
est store e4 
eststo: reghdfe ln_rp_nonea_n_w `indvar2_1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe3') cluster(`clust')
est store e5 
eststo: reghdfe ln_any_guidance_n_w `indvar2_1' `control' if periodend >= 20040823 & novary == 0, absorb(`fe3') cluster(`clust')
est store e6
	 
esttab e1 e2 e3 e4 e5 e6 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 10 Panel B: Dropping Time FE for Target, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 




/* Panel C: Incorporating expected changes to the FOMC Target */
gen targetexpected = targetchange_bp - targetsurprise_bp

label variable targetexpected "Expected Target Change"

est clear
local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar3 "c.targetsurprise_bp#c.mean_mpe_tv c.targetexpected#c.mean_mpe_tv mean_mpe_tv targetsurprise_bp targetexpected"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 

eststo: reghdfe nonea_8k_d `indvar3' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e1 
eststo: reghdfe rp_nonea_d `indvar3' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e2 
eststo: reghdfe any_guidance_d `indvar3' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e3 
eststo: reghdfe ln_nonea_8k_n_w `indvar3' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e4 
eststo: reghdfe ln_rp_nonea_n_w `indvar3' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e5 
eststo: reghdfe ln_any_guidance_n_w `indvar3' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e6
	 
esttab e1 e2 e3 e4 e5 e6 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 10 Panel C: Incorporating Expected Changes to the FOMC Target, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 



/* Panel D: Mirranda-Agrippino and Rico (2016) shocks */
est clear
local clust "cusip_n"
local fe1  "cusip_n periodnumber"  
local indvar4 "c.mpisurprise5_bp#c.mean_mpe_tv mean_mpe_tv"
local control "ln_mcap_w ln_cov_w roa_w btm_w leverage_w periodreturn_w periodvolatility_w periodilliquidity_w instownership_w any_issue_d" 

eststo: reghdfe nonea_8k_d `indvar4' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e1 
eststo: reghdfe rp_nonea_d `indvar4' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e2 
eststo: reghdfe any_guidance_d `indvar4' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e3 
eststo: reghdfe ln_nonea_8k_n_w `indvar4' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e4 
eststo: reghdfe ln_rp_nonea_n_w `indvar4' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e5 
eststo: reghdfe ln_any_guidance_n_w `indvar4' `control' if periodend >= 20040823 & novary == 0, absorb(`fe1') cluster(`clust')
est store e6
	 
esttab e1 e2 e3 e4 e5 e6 using "Results.rtf", append compress nogaps onecell b(3) varwidth(15) modelwidth(7) title("Table 10 Panel D: Incorporating Mirranda-Agrippino and Rico (2016) shocks, `fe1' fixed effects & clustering by `clust'.") stats(r2_a N , fmt(%9.3fc %9.0fc ) labels("Adj. R-squared" Observations ) ) label interaction(" X ") starlevels(* 0.10 ** 0.05 *** 0.01) 




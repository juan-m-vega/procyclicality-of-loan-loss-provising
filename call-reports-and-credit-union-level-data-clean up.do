cd "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning"
set more off
set type double
capture log close

global input "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Input"
global output "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Output"
global logs "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Logs"
global temp "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Temp"

/*The economic problem at hand is the procyclicality of loan loss provisioning. That is, the inverse relationship of loan loss provisions with
	real gross domestic product. When the economy experiences an expansion, given International Accounting Standard 39 and other accounting
	regulatory requirements in the United States, loan loss provisions decrease. They increase when the economy experiences a downturn, which further inhibits
	banks' ability to lend, which magnifies an economic contraction. After the financial crisis, the Basel III Accord hopes to counteract this pattern
	with a 'counter-cyclical buffer'. This counter-cyclical buffer will require higher levels of capital for all banks to be held at hand, regardless of the state
	of the economy. The higher levels of required capital by banks are expected to be translated as higher costs of capital for banks, which will be passed on
	to consumers in the forms of higher costs of credit, decreasing consumers' ability to borrow and decrease consumption.

	The federal reserve announced in late 2011 that it would apply the counter-cyclical buffer to all financial institutions with $50 or more billion.
	The Organization for Economic Cooperation and Development predicted that the cost of this counter-cyclical buffer would be a cost of 0.05 to 0.15 percent
	of world GDP, per year. When compounded, over the years such an amount can become consequential. The focus of this research effort is in the United States.

	With this background in mind, the purpose of this research is to examine the relationship between loan loss provisioning and real gross domestic product
	by bank size and lending type. The expectation is that the banks with x lending type and sizes that exhibit a stronger procyclical
	pattern may be a better target for implementing the counter cyclical buffer, instead of applying the counter-cyclical buffer uniformly with the $50 billion
	and above rule. In other words, the important result is to identify which banks are target bank based on key characteristics in order to
	minimize the adverse effect of the counter cyclical buffer on the economy, and maximize regulatory safety.*/

**********************************************
*Read in the data and clean it as appropriate*
**********************************************

/*This section of the program combines data from the Reports of Income and Condition provided by the Federal Reserve and Quarterly Call Reports
	from the National Credit Union Association. Because there is not full comparability between key regressors for the data provided by the Federal
	Reserve and the National Credit Union Association, separate regressions are run using both data sets */

insheet using "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Input\Credit Union level data.csv", comma clear
save "$input\Credit Union Level Data.dta", replace
clear
insheet using "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Input\Data in excel format 1.csv", comma clear
gen indicator=_n
sort indicator
save "$input\Data in excel format1.dta", replace
clear
insheet using "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Input\Data in excel format 2.csv", comma clear
gen indicator=_n
sort indicator
save "$input\Data in excel format2.dta", replace
clear
insheet using "C:\Users\Admin\Documents\Econometrics-Economics\Loan Loss Provisioning\Input\Data in excel format 3.csv", comma clear
gen indicator=_n
sort indicator
save "$input\Data in excel format3.dta", replace
clear
use "$input\Data in excel format1.dta", clear
merge indicator using "$input\Data in excel format2.dta"
tab _merge
drop _merge
sort indicator
merge indicator using "$input\Data in excel format3.dta"
tab _merge
drop _merge
save "$input\Call Reports Data (2003-2011).dta", replace

***********************************
*Clean the Credit Union Level Data*
***********************************
/*This section modifies and adjusts the NCUA data*/

use "$input\Credit Union Level Data.dta", clear
codebook, compact
inspect
capture drop name_plus_state _est__hausman q1 year1 bankno diffbankno
replace chargeoffsadditionoftheaccountsb= c1+ c2+ c3+ c4
rename chargeoffsadditionoftheaccountsb charge_offs
gen month=substr(cycle_date, 1, 2)
replace month="3" if month=="3/"
replace month="6" if month=="6/"
replace month="9" if month=="9/"
gen day=substr(cycle_date, 4, 2)
replace day=substr(cycle_date, 3, 2) if cycle_date!="12/31/2009 0:00" & cycle_date!="12/31/2010 0:00"
gen year=substr(cycle_date, 7, 4)
replace year=substr(cycle_date, 6, 4) if cycle_date!="12/31/2009 0:00" & cycle_date!="12/31/2010 0:00"
destring month day year, replace
gen stata_date=mdy(month, day, year)
format stata_date %td
drop month day year
sort cycle_date cu_name
bysort cu_name: gen binovation_id=_n
capture drop c1 c2 c3 c4
rename car capital_asset_ratio
capture drop totalcreditavailable homeequitylinesofcredit totaldelfixedratefirstmortgagelo totaldeladjustableratefirstmortg ///
	amountofconstructionandbusinessd agriculturalloansytd newautoloanswith4yearsmaturity usedautoloanswith3yearsmaturity ///
	v35 date quarter

replace cu_name="A" if cu_name=="" & cycle_date==cycle_date[_n+1]
replace cu_name="B" if cu_name=="" & cu_name[_n-1]=="A" & cu_name[_n+1]=="A"
replace cu_name="B" if cu_name=="" & cu_name!="A"

preserve
	keep cu_name
	drop if cu_name==cu_name[_n-1]
	gen cu_id=_n
	sort cu_name
	save "$temp\cu_id.dta", replace
restore

sort cu_name
merge cu_name using "$temp\cu_id.dta"

/*Preliminary analysis for credit unions*/

local myvars1 alll totalassets charge_offs totalloansandleases loanssecuredbyre reserves capital_asset_ratio netincome collateral roa ///
	numberoftotalcreditlines numberofmortgageloans numberofunsecuredcreditcardloans emortgage ecc recc remortgage allllag

foreach x in `myvars1' {
	summ `x', detail
	graph twoway (lowess `x' rgdp) (scatter `x' rgdp), replace
	save "$temp\rgdpvs_`x'.gph
}
*end

xtset, clear
xtset cu_id
xtreg  alll totalassets charge_offs totalloansandleases loanssecuredbyre reserves capital_asset_ratio netincome collateral roa ///
	numberoftotalcreditlines numberofmortgageloans numberofunsecuredcreditcardloans emortgage ecc rgdp  recc remortgage allllag, fe
estimates store version1
xtreg  alll totalassets charge_offs totalloansandleases loanssecuredbyre reserves capital_asset_ratio netincome collateral roa ///
	numberoftotalcreditlines numberofmortgageloans numberofunsecuredcreditcardloans emortgage ecc rgdp  recc remortgage allllag, re
estimates store version2
hausman version1 version2

/*This is a preliminary analysis to assess whether a fixed or random effects model is appropriate in estimating the allowance for loan and lease losses
	on variables such as total assets the amount of charge offs, and other variables that have been found to be key in the professional literature.
	An Arellano and Bond model was later taken into consideration. However, the data requirements needed for it were not met.*/

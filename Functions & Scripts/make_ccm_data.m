%% Prepare the CCM & surprises data

clear
clc

fprintf('Now working on making the CCM data. Run started at %s.\n\n\n', char(datetime('now')));

load ddates
load dates
load permno
load dme
load niq
load atq
load BEQ
load ltq
load dbid
load dask
load dret
load me
load rdq
load io_pct
load sic
load FF10
load FF17
load FF49
load SurpriseData
load erp

% Import the MPE index
[mpe, ~] = getAnomalySignals('mpe.csv', 'permno', 'dates');

% Define a few variables
baspread = 100*(dask-dbid)./((dask+dbid)/2);
ROA      = NIQ./ATQ;
btm      = BEQ./me;
lev      = LTQ./ATQ; 

% Clean up a few
ATQ(ATQ<=0) = nan;
me(me<=0)   = nan;

% Store some dimensions (number of meetings, stocks, and observations)
nMeet    = height(SurpriseData);
nStocks  = size(mpe,2);
nMeetObs = nMeet * nStocks;

% Initialize the indexes
meetingDailyIndex   = nan(nMeet,1);
meetingMonthlyIndex = nan(nMeet,1);

% Get the daily and monthly index of the meeting dates
for i=1:nMeet
    meetingDailyIndex(i)   = find(ddates == SurpriseData.yyyymmdd(i));
    meetingMonthlyIndex(i) = find(dates == floor(SurpriseData.yyyymmdd(i)/100));    
end

% Calculate the number of days in each period
SurpriseData.cal_days = days([SurpriseData.date(2:end); NaT]-SurpriseData.date);
SurpriseData.bus_days = lead(meetingDailyIndex, 1 ,nan)-meetingDailyIndex;

% Initialize matrices for the variables from daily data
vol      = nan(nMeet, nStocks);
vol3wk   = nan(nMeet, nStocks);
ret      = nan(nMeet, nStocks);
ret3wk   = nan(nMeet, nStocks);
illiq    = nan(nMeet, nStocks);
illiq3wk = nan(nMeet, nStocks);

% Calculate the variables from daily data by looping through the periods
for i=1:nMeet-1
    % Figure out the period
    s = find(ddates == SurpriseData.yyyymmdd(i));
    e = find(ddates == SurpriseData.yyyymmdd(i+1));
    
    % Get the daily returns
    tempRet = dret(s:e,:);
    
    % Cumulate (1+r) and subtract 1 
    cumRet = cumprod(1+tempRet,1)-1;
    
    % Store this period's cumulative return, volatility, and illiquidity
    ret(i,:)   = cumRet(end,:);       
    vol(i,:)   = std(tempRet,[],1);
    illiq(i,:) = mean(baspread(s:e,:));    
    
    % Do the same for the three-week-window 
    date3wk          = SurpriseData.date(i)+caldays(21);
    date3wk_yyyymmdd = 10000*year(date3wk) + ...
                         100*month(date3wk) + ...
                             day(date3wk);
    
    % Find the row in ddates corresponding to the last trading day
    e_3wk = find(ddates <= date3wk_yyyymmdd,1,'last');
    
    % Get the daily returns
    tempRet = dret(s:e_3wk,:);
    
    % Cumulate (1+r) and subtract 1 
    cumRet=cumprod(1+tempRet,1)-1;    
    
    % Store this period's cumulative return, volatility, and illiquidity
    ret3wk(i,:)   = cumRet(end,:);
    vol3wk(i,:)   = std(tempRet,[],1);
    illiq3wk(i,:) = mean(baspread(s:e_3wk,:));        
end

% initialize the earnings announcement dummies
eaDummy    = zeros(nMeet, nStocks);
eaDummy3wk = zeros(nMeet, nStocks);

% Store a few numbers
nMonths = length(dates);
nMonthObs = nMonths * nStocks; 

% Turn the  permno vector into a matrix
rptdPermno = repmat(permno', nMonths, 1);

% Reshape the permno and RDQ matrices
rshpdRDQ 	= reshape(RDQ,        nMonthObs, 1);
rshpdPermno = reshape(rptdPermno, nMonthObs, 1);

% Create the linking table
rdqTable = array2table([rshpdPermno rshpdRDQ], 'VariableNames',{'permno','rdq'});

% Drop the missing RDQs
indToDrop             = isnan(rdqTable.rdq);
rdqTable(indToDrop,:) = [];

% Loop over the FOMC meetings
for i=1:nMeet-1    
    
    % Find this period in the RDQ table
    ind = find(rdqTable.rdq >= SurpriseData.yyyymmdd(i) & ...
               rdqTable.rdq < SurpriseData.yyyymmdd(i+1));
    
    % Find which permnos had RDQs during this period
    eaPermnoInd = ismember(permno, rdqTable.permno(ind));
    
    % Assign a 1 to them
    eaDummy(i, eaPermnoInd) = 1;
    
    % Find the 3-week threshold for the meeting date
    meetingDate    = SurpriseData.date(i);
    meetingDate3wk = meetingDate + caldays(21);
    endDate3wk     = 10000*year(meetingDate3wk) + ...
                       100*month(meetingDate3wk) + ...
                           day(meetingDate3wk);
        
    % Find the 3-week period in the RDQ table
    ind3wk=find(rdqTable.rdq >= SurpriseData.yyyymmdd(i) & ...
             rdqTable.rdq < endDate3wk);
         
    % Find which permnos had RDQs during this period
    eaPermnoInd3wk = ismember(permno,rdqTable.permno(ind3wk));
    
    % Assign a 1 to them
    eaDummy3wk(i, eaPermnoInd3wk) = 1;    
end

% Define a few vars
PeriodEndDate = lead(SurpriseData.yyyymmdd, 1,nan);
MarketCap     = dme(meetingDailyIndex-1,:);

% Repmat a few variable
rptdPermno       = repmat(permno',                       nMeet, 1);
rptdPeriodNum    = repmat([1:nMeet]',                    1,     nStocks);
rptdKuttnerSurp  = repmat(SurpriseData.KuttnerSurp,      1,     nStocks);
rptdTargetSurp   = repmat(SurpriseData.TargetSurp,       1,     nStocks);
rptdPathSurp     = repmat(SurpriseData.PathSurp,         1,     nStocks);
rptdIV1          = repmat(SurpriseData.IV1,              1,     nStocks);
rptdIV5          = repmat(SurpriseData.IV5,              1,     nStocks);
rptdTargetChange = repmat(SurpriseData.targetRateChange, 1,     nStocks);
rptdBegDate      = repmat(SurpriseData.yyyymmdd,         1,     nStocks);
rptdEndDate      = repmat(PeriodEndDate,                 1,     nStocks);
rptdCalDays      = repmat(SurpriseData.cal_days,         1,     nStocks);
rptdBusDays      = repmat(SurpriseData.bus_days,         1,     nStocks);

% Create the table, starting with permno
data = array2table(reshape(rptdPermno,nMeetObs, 1),'VariableNames',{'permno'});

% Add the per-period variables first
data.PeriodNumber                 = reshape(rptdPeriodNum,    nMeetObs, 1);
data.KuttnerSurpriseStartOfPeriod = reshape(rptdKuttnerSurp,  nMeetObs, 1);
data.TargetSurpriseStartOfPeriod  = reshape(rptdTargetSurp,   nMeetObs, 1);
data.PathSurpriseStartOfPeriod    = reshape(rptdPathSurp,     nMeetObs, 1);
data.IV1StartOfPeriod             = reshape(rptdIV1,          nMeetObs, 1);
data.IV5StartOfPeriod             = reshape(rptdIV5,          nMeetObs, 1);
data.TargetChangeStartOfPeriod    = reshape(rptdTargetChange, nMeetObs, 1);
data.PeriodStart                  = reshape(rptdBegDate,      nMeetObs, 1);
data.PeriodEnd                    = reshape(rptdEndDate,      nMeetObs, 1);
data.PeriodCalendarDays           = reshape(rptdCalDays,      nMeetObs, 1);
data.PeriodBusinessDays           = reshape(rptdBusDays,      nMeetObs, 1);

% Add the panel variables from the monthly data next
data.MPE           = reshape(-mpe(meetingMonthlyIndex-1,:),   nMeetObs, 1);
data.ROA           = reshape(ROA(meetingMonthlyIndex-1,:),    nMeetObs, 1);
data.BtM           = reshape(btm(meetingMonthlyIndex-1,:),    nMeetObs, 1);
data.Leverage      = reshape(lev(meetingMonthlyIndex-1,:),    nMeetObs, 1);
data.InstOwnership = reshape(io_pct(meetingMonthlyIndex-1,:), nMeetObs, 1);
data.SICCD         = reshape(SIC(meetingMonthlyIndex,:),      nMeetObs, 1);
data.FF10          = reshape(FF10(meetingMonthlyIndex,:),     nMeetObs, 1);
data.FF17          = reshape(FF17(meetingMonthlyIndex,:),     nMeetObs, 1);
data.FF49          = reshape(FF49(meetingMonthlyIndex,:),     nMeetObs, 1);

% Add the ERPs
erpFieldNames = fieldnames(erp);
nERPs = length(erpFieldNames);
for i = 1:nERPs
    thisERPName = char(erpFieldNames(i));
    tempERP = erp.(thisERPName);
    varName = ['erp_', thisERPName];
    data.(varName) = reshape(tempERP(meetingMonthlyIndex, :), nMeetObs, 1);
end

% Add the panel variables from the daily data next
data.MarketCap            = reshape(MarketCap, nMeetObs, 1);
data.PeriodReturn         = reshape(ret,       nMeetObs, 1);
data.PeriodVolatility     = reshape(vol,       nMeetObs, 1);
data.PeriodIlliquidity    = reshape(illiq,     nMeetObs, 1);
data.PeriodReturn3wk      = reshape(ret3wk,    nMeetObs, 1);
data.PeriodVolatility3wk  = reshape(vol3wk,    nMeetObs, 1);
data.PeriodIlliquidity3wk = reshape(illiq3wk,  nMeetObs, 1);

% Add the announcement dummies
data.AnnouncementIndicator    = reshape(eaDummy,    nMeetObs, 1);
data.AnnouncementIndicator3wk = reshape(eaDummy3wk, nMeetObs, 1);

% Save & store the periods
periods = unique(data(:,{'PeriodNumber','PeriodStart','PeriodEnd'}));
periods(isnan(periods.PeriodEnd), :) = [];
save Data\periods periods

% Drop nans
indToDrop         = isnan(data.MPE + data.PeriodEnd);
data(indToDrop,:) = [];

% Do some housekeeping
data.year         = floor(data.PeriodStart/10000);
data.PeriodNumber = categorical(data.PeriodNumber);

% Attach net issuance
data.netshareissuance    = nan(height(data),1);
data.netshareissuance3wk = nan(height(data),1);

% Load the relevant variables
load dcfacshr
load dshrout
load ddates
load permno

adj_shrs = dshrout .* dcfacshr;

for i=1:height(data)    
    % Find the stock and period
    c  = find(permno==data.permno(i));
    b = find(ddates >= data.PeriodStart(i), 1, 'first');
    e = find(ddates <= data.PeriodEnd(i),   1, 'last' );
    
    % Assign the issuance
    data.netshareissuance(i) = 100*(adj_shrs(e,c)/adj_shrs(b,c)-1);
    
    % Do the 3-week share issuance
    meetingDate3wk      = datetime(ddates(b),'ConvertFrom','yyyyMMdd') + caldays(21);
    endDate3wk_yyyymmdd = 10000*year(meetingDate3wk) + ...
                            100*month(meetingDate3wk) + ...
                                day(meetingDate3wk);
    
    % Find the index of the end of the 3-week period                        
    e_3wk = find(ddates <= endDate3wk_yyyymmdd, 1, 'last');
    
    % Assign the issuance
    data.netshareissuance3wk(i) = 100*(adj_shrs(e_3wk,c)/adj_shrs(b,c)-1);    
end



% Attach CUSIPs from CRSP
% Note: definitions from crsp:
% CUSIP: CUSIP is the latest eight-character CUSIP identifier for the security 
% through the end of the file. CUSIP identifiers are supplied to CRSP by the 
% CUSIP Service Bureau,

% NCUSIP: The CUSIP Agency will often change an issue's CUSIP identifier to reflect a 
% change of name or capital structure. CRSP has preserved all CUSIPs that 
% have been assigned to a given issue. NCUSIP may be a blank string if the 
% name structure predates the CUSIP Bureau.

% Detect options for the CRSP_STOCKNAMES table input file
opts = detectImportOptions('crsp_stocknames.csv');

% Ensure NCUSIP is char
opts.VariableTypes(strcmp(opts.VariableNames,'ncusip')) = {'char'};

% Read it in
crsp_stocknames = readtable('crsp_stocknames.csv',opts);

% Change dates format
crsp_stocknames.bdate = 10000 * year(crsp_stocknames.namedt) + ...
                          100 * month(crsp_stocknames.namedt) + ...
                                day(crsp_stocknames.namedt);                          
crsp_stocknames.edate = 10000 * year(crsp_stocknames.nameenddt) + ...
                          100 * month(crsp_stocknames.nameenddt) + ...
                                day(crsp_stocknames.nameenddt);
                          
% Leave only the relevant variables                          
crsp_stocknames = crsp_stocknames(:,{'permno','bdate','edate','ncusip','comnam'});

% Merge the CRSP_STOCKNAMES file into the CCM data
data = outerjoin(data, crsp_stocknames, 'Keys','permno', ...
                                        'MergeKeys',1, ...
                                        'Type','Left');

% Drop some observations & columns
indToDrop                 = isundefined(data.PeriodNumber) | ... 
                            data.PeriodStart <  data.bdate | ...
                            data.PeriodEnd   >= data.edate;
data(indToDrop,:)         = [];
data(:,{'bdate','edate'}) = [];



% Store the dataset
writetable(data, 'Data/data_ccm.csv');

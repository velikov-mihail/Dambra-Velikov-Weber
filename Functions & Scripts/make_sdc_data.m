
%% Prepare the M&A data from SDC

clear
clc

fprintf('Now working on making the SDC data. Run started at %s.\n\n\n', char(datetime('now')));

% Store the directory & get the file names
filesDir = [pwd, filesep, 'Inputs', filesep, 'SDC', filesep, 'M&A', filesep];
fileList = dir(filesDir);
fileNames = {fileList.name}';
indToDrop = ~contains(fileNames, '.xlsx'); 
fileNames(indToDrop) = [];
numFiles = length(fileNames);

% Initialize the M&A data table
data = [];

% Initialize the dates matrix used for checking 
dates   = datetime;

for i = 1:numFiles
    % Read the current file
    thisFileName = char(fileNames(i));
    thisData = readtable(thisFileName);
    
    % Get the min and max dates
    dates(i,1) = min(thisData.DateAnnounced);
    dates(i,2) = max(thisData.DateAnnounced);
    
    % Append
    data = [data; thisData];
end

% Next we'll check if we downloaded the SDC data correctly. That would
% involve checking whether the start date for each file is the day after
% the end date of the previous one.

% Transform the dates into a table
dates = array2table(dates);
dates.Properties.VariableNames = {'MinDate','MaxDate'};

% Sort the dates
dates = sortrows(dates,'MinDate');

% Store the date after the Max date for each file
dates.MaxNext = dates.MaxDate + caldays(1);

% Store the min from the next file
dates.NextStart          = NaT(numFiles,1);
dates.NextStart(1:end-1) = dates.MinDate(2:end); 

% Take the difference 
datesDiff = dates.MaxNext - dates.NextStart;

% Find non-zero ones
indIsFinite = isfinite(datesDiff);
indNonZero  = datesDiff ~= 0;
indErr      = find(indIsFinite & indNonZero,1);

% Print the result of the check
if isempty(indErr)
    fprintf('\n\nM&A data looks good. A total of %d number of observations were stores.\n\n\n', height(data));
else
    error('\n\nM&A data not complete or double counted.\n\n\n');
end

save Data\temp_ma_data data

% Leave only the relevant variables & rename
data = data(:,{'Acquiror6_digitCUSIP','DateAnnounced','DealValue_USD_Millions_'});
data.Properties.VariableNames = {'cusip','date','value'};

% Take the unique periods & their start and end dates
load periods
periods.PeriodStart = datetime(periods.PeriodStart, 'ConvertFrom', 'yyyyMMdd');
periods.PeriodEnd = datetime(periods.PeriodEnd, 'ConvertFrom', 'yyyyMMdd');

data.PeriodNumber = zeros(height(data),1);
data.PeriodNumber3wk = zeros(height(data),1);
for i=1:height(periods)
    % Find all announements during this period
    indThisPeriod = data.date >= periods.PeriodStart(i) &  ...
                    data.date < periods.PeriodEnd(i);
    
    % Assing the period
    data.PeriodNumber(indThisPeriod) = periods.PeriodNumber(i);
    
    % Find all announements during this period
    indThisPeriod3wk = data.date >= periods.PeriodStart(i) &  ...
                       data.date < (periods.PeriodStart(i) + caldays(21));
    
    % Assing the period
    data.PeriodNumber3wk(indThisPeriod3wk) = periods.PeriodNumber(i);        
end

% Drop observations outside of our FMC period
data(data.PeriodNumber==0,:) = [];


% Collapse the data
ma_merge_data = varfun(@nansum, data(:,{'cusip','PeriodNumber','value'}), ...
                                         'GroupingVariables', {'cusip','PeriodNumber'});
% Change the variable names
ma_merge_data.Properties.VariableNames = {'cusipSDCMerge','PeriodNumber','AcquisitionsCount','AcquisitionsValue'};

                                                                                           
                                              
% Collapse the data
ma_merge_data_3wk = varfun(@nansum, data(:,{'cusip','PeriodNumber3wk','value'}), ...
                                         'GroupingVariables', {'cusip','PeriodNumber3wk'});
% Change the variable names
ma_merge_data_3wk.Properties.VariableNames = {'cusipSDCMerge','PeriodNumber','AcquisitionsCount3wk','AcquisitionsValue3wk'};
indToDrop = ma_merge_data_3wk.PeriodNumber == 0;
ma_merge_data_3wk(indToDrop, :) = [];

data_sdc_ma = outerjoin(ma_merge_data, ma_merge_data_3wk, 'Type', 'Left', ...
                                                   'MergeKeys', 1);

writetable(data_sdc_ma, ['Data', filesep, 'data_sdc_ma.csv']);

fprintf('Done with SDC M&A data.\n');
datetime('now')

%% Prepare the Bond issuance data from SDC

clear
clc

% Store the directory & get the file names
filesDir = [pwd, filesep, 'Inputs', filesep, 'SDC', filesep, 'Bonds', filesep];
fileList = dir(filesDir);
fileNames = {fileList.name}';
indToDrop = ~contains(fileNames, '.xlsx'); 
fileNames(indToDrop) = [];
numFiles = length(fileNames);

% Initialize the Bond data table
data = [];

% Initialize the dates matrix used for checking 
dates   = datetime;

for i = 1:numFiles
    % Read the current file
    thisFileName = char(fileNames(i));
    thisData = readtable(thisFileName);
    
    % Get the min and max dates
    dates(i,1) = min(thisData.IssueDate);
    dates(i,2) = max(thisData.IssueDate);
    
    % Append
    data = [data; thisData];
end

% Next we'll check if we downloaded the SDC data correctly. That would
% involve checking whether the start date for each file is the day after
% the end date of the previous one.

% Transform the dates into a table
dates = array2table(dates);
dates.Properties.VariableNames = {'MinDate','MaxDate'};

% Sort the dates
dates = sortrows(dates,'MinDate');

% Store the date after the Max date for each file
dates.MaxNext = dates.MaxDate + caldays(1);

% Store the min from the next file
dates.NextStart          = NaT(numFiles,1);
dates.NextStart(1:end-1) = dates.MinDate(2:end); 

% Take the difference 
datesDiff = dates.MaxNext - dates.NextStart;

% Find non-zero ones
indIsFinite = isfinite(datesDiff);
indPos  = datesDiff > 0;
indErr      = find(indIsFinite & indPos,1);

% Print the result of the check
if isempty(indErr)
    fprintf('\n\nBond data looks good. A total of %d number of observations were stores.\n\n\n', height(data));
else
    error('\n\nBond data not complete or double counted.\n\n\n');
end


% Leave only the relevant variables & rename
data = data(:,{'Issuer_BorrowerUltimateParent6_digitCUSIP','IssueDate','ProceedsAmountInclOverallotmentSoldAllMarkets_USD_Millions_'});
data.Properties.VariableNames = {'cusip','date','value'};

% Take the unique periods & their start and end dates
load periods
periods.PeriodStart = datetime(periods.PeriodStart, 'ConvertFrom', 'yyyyMMdd');
periods.PeriodEnd = datetime(periods.PeriodEnd, 'ConvertFrom', 'yyyyMMdd');

% Initialize the periodnumber variables
data.PeriodNumber    = zeros(height(data),1);
data.PeriodNumber3wk = zeros(height(data),1);

for i=1:height(periods)
    % Find all announements during this period
    indThisPeriod = data.date >= periods.PeriodStart(i) &  ...
                    data.date < periods.PeriodEnd(i);
    
    % Assing the period
    data.PeriodNumber(indThisPeriod) = periods.PeriodNumber(i);
    
    % Find all announements during this period
    indThisPeriod3wk = data.date >= periods.PeriodStart(i) &  ...
                       data.date < (periods.PeriodStart(i) + caldays(21));
    
    % Assing the period
    data.PeriodNumber3wk(indThisPeriod3wk) = periods.PeriodNumber(i);        
end

% Collapse the data
bond_merge_data = varfun(@nansum, data(:,{'cusip','PeriodNumber','value'}), ...
                                         'GroupingVariables', {'cusip','PeriodNumber'});
% Change the variable names
bond_merge_data.Properties.VariableNames = {'cusipSDCMerge','PeriodNumber','BondIssuesCount','BondIssuesValue'};

                                              
% Collapse the data
bond_merge_data_3wk = varfun(@nansum, data(:,{'cusip','PeriodNumber3wk','value'}), ...
                                                'GroupingVariables', {'cusip','PeriodNumber3wk'});
% Change the variable names
bond_merge_data_3wk.Properties.VariableNames = {'cusipSDCMerge','PeriodNumber','BondIssuesCount3wk','BondIssuesValue3wk'};


% Create the final dataset
data_sdc_bonds = outerjoin(bond_merge_data, bond_merge_data_3wk, 'Type', 'Left', ...
                                                                 'Keys', {'cusipSDCMerge','PeriodNumber'}, ...
                                                                 'RightVariables', {'BondIssuesCount3wk','BondIssuesValue3wk'});                                                                                            

% Store it
writetable(data_sdc_bonds, ['Data', filesep, 'data_sdc_bonds.csv']);


fprintf('Done with SDC Bond data.\n');
datetime('now')

%% Prepare the Loan issuance data from SDC

clear
clc

% Store the directory & get the file names
filesDir = [pwd, filesep, 'Inputs', filesep, 'SDC', filesep, 'Loans', filesep];
fileList = dir(filesDir);
fileNames = {fileList.name}';
indToDrop = ~contains(fileNames, '.xlsx'); 
fileNames(indToDrop) = [];
numFiles = length(fileNames);

% Initialize the Loan data table
data = [];

% Initialize the dates matrix used for checking 
dates   = datetime;

for i = 1:numFiles
    % Read the current file
    thisFileName = char(fileNames(i));
    thisData = readtable(thisFileName);
    
    % Get the min and max dates
    dates(i,1) = min(thisData.DateAnnounced);
    dates(i,2) = max(thisData.DateAnnounced);
    
    % Append
    data = [data; thisData];
end

% Next we'll check if we downloaded the SDC data correctly. That would
% involve checking whether the start date for each file is the day after
% the end date of the previous one.

% Transform the dates into a table
dates = array2table(dates);
dates.Properties.VariableNames = {'MinDate','MaxDate'};

% Sort the dates
dates = sortrows(dates,'MinDate');

% Store the date after the Max date for each file
dates.MaxNext = dates.MaxDate + caldays(1);

% Store the min from the next file
dates.NextStart          = NaT(numFiles,1);
dates.NextStart(1:end-1) = dates.MinDate(2:end); 

% Take the difference 
datesDiff = dates.MaxNext - dates.NextStart;

% Find non-zero ones
indIsFinite = isfinite(datesDiff);
indNonNeg  = datesDiff ~= 0;
indErr      = find(indIsFinite & indNonNeg,1);

% Print the result of the check
if isempty(indErr)
    fprintf('\n\nLoan data looks good. A total of %d number of observations were stores.\n\n\n',height(data));
else
    error('\n\nLoan data not complete or double counted.\n\n\n');
end

% Leave only the relevant variables & rename
data = data(:,{'Issuer_Borrower6_digitCUSIP','DateAnnounced','TotalFacilityAmount_USD_Millions_'});
data.Properties.VariableNames = {'cusip','date','value'};

% Take the unique periods & their start and end dates
load periods
periods.PeriodStart = datetime(periods.PeriodStart, 'ConvertFrom', 'yyyyMMdd');
periods.PeriodEnd = datetime(periods.PeriodEnd, 'ConvertFrom', 'yyyyMMdd');

% Initialize the periodnumber variables
data.PeriodNumber    = zeros(height(data),1);
data.PeriodNumber3wk = zeros(height(data),1);

for i=1:height(periods)
    % Find all announements during this period
    indThisPeriod = data.date >= periods.PeriodStart(i) &  ...
                    data.date < periods.PeriodEnd(i);
    
    % Assing the period
    data.PeriodNumber(indThisPeriod) = periods.PeriodNumber(i);
    
    % Find all announements during this period
    indThisPeriod3wk = data.date >= periods.PeriodStart(i) &  ...
                       data.date < (periods.PeriodStart(i) + caldays(21));
    
    % Assing the period
    data.PeriodNumber3wk(indThisPeriod3wk) = periods.PeriodNumber(i);        
end

% Collapse the data
loan_merge_data = varfun(@nansum, data(:,{'cusip','PeriodNumber','value'}), ...
                                         'GroupingVariables', {'cusip','PeriodNumber'});
% Change the variable names
loan_merge_data.Properties.VariableNames = {'cusipSDCMerge','PeriodNumber','LoanIssuesCount','LoanIssuesValue'};

                                              
% Collapse the data
loan_merge_data_3wk = varfun(@nansum, data(:,{'cusip','PeriodNumber3wk','value'}), ...
                                         'GroupingVariables', {'cusip','PeriodNumber3wk'});
% Change the variable names
loan_merge_data_3wk.Properties.VariableNames = {'cusipSDCMerge','PeriodNumber','LoanIssuesCount3wk','LoanIssuesValue3wk'};

% Create the final dataset
data_sdc_loans = outerjoin(loan_merge_data, loan_merge_data_3wk, 'Type', 'Left', ...
                                                  'Keys', {'cusipSDCMerge','PeriodNumber'}, ...
                                                  'RightVariables', {'LoanIssuesCount3wk','LoanIssuesValue3wk'});                                                                                            

% Store it
writetable(data_sdc_loans, ['Data', filesep, 'data_sdc_loans.csv']);

fprintf('Done with SDC Loan data.\n');
datetime('now')

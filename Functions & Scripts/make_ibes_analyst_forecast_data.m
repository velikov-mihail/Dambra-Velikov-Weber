clear
clc

fprintf('Now working on making the IBES analyst forecast data. Run started at %s.\n\n\n', char(datetime('now')));

% Read in the IBES statistical summary file for US stocks
opts                         = detectImportOptions('IBES_STATSUM_EPSUS.csv');
indCusip                     = strcmp(opts.VariableNames,'cusip');
opts.VariableTypes(indCusip) = {'char'};
data1                        = readtable('IBES_STATSUM_EPSUS.csv', opts);

% Read in the IBES statistical summary file for international stocks
opts                         = detectImportOptions('IBES_STATSUM_EPSINT.csv');
indCusip                     = strcmp(opts.VariableNames,'cusip');
opts.VariableTypes(indCusip) = {'char'};
data2                        = readtable('IBES_STATSUM_EPSINT.csv', opts);

% Combine the two
data = [data1; data2];
clear data1 data2

% Drop the observations we don't need
indToDrop = strcmp(data.cusip,'') | ...
            strcmp(data.cusip,'00000000') | ...
            year(data.statpers) < 1994;
data(indToDrop, :) = [];

% Define the net percent up variable
data.netPctUp = (data.numup - data.numdown) ./ data.numest;

% Define the date to be in yyyymmdd format
data.date = 10000 * year(data.statpers) + ...
              100 * month(data.statpers) + ...
                    day(data.statpers);

% Load the periods
load periods

% Create a big matrix that would correspond to whether the filing date is
% in the intermeeting period
temp  = periods.PeriodStart' <= data.date;
temp2 = periods.PeriodEnd'   >  data.date;
temp  = (temp & temp2)';

% Assign the corresponding period numbers to each row in data
[row, col]        = find(temp);
per               = zeros(height(data),1);
per(col)          = row;
data.PeriodNumber = per;

% Delete the cases outside of our CCM/FOMC data
indToDrop         = (data.PeriodNumber==0);
data(indToDrop,:) = [];

% Leave only the relevant variables
data = data(:, {'cusip','PeriodNumber','fpedats','fpi','statpers', ...
                'netPctUp','medest','meanest'});

% Sort & leave only the first statpers for each (CUSIP, PeriodNumber, fpedats, fpi) 
data = sortrows(data, {'cusip','PeriodNumber','fpedats','fpi','statpers'}, 'ascend');
data_first = varfun(@(x) x(1, :), data, 'GroupingVariables', {'cusip','PeriodNumber','fpedats','fpi'}, ...
                                        'InputVariables', {'netPctUp','medest','meanest'});
data_first.Properties.VariableNames = regexprep(data_first.Properties.VariableNames, 'Fun_', '');
data_first.GroupCount = [];

% Get the last ones for the differences
data_last = varfun(@(x) x(end, :), data, 'GroupingVariables', {'cusip','PeriodNumber','fpedats','fpi'}, ...
                                         'InputVariables', {'medest','meanest'});
data_last.Properties.VariableNames = regexprep(data_last.Properties.VariableNames, 'Fun_', 'Last_');
data_last.GroupCount = [];

% Merge the two
data = outerjoin(data_first, data_last, 'Keys', {'cusip','PeriodNumber','fpedats','fpi'}, ...
                                        'Type', 'Left', ...
                                        'MergeKeys', 1); 
clear data_first data_last
                                     
% Drop the (CUSIP, fpedats) with only one PeriodNumber (i.e., no lags)
dataEst = data(:, {'cusip','PeriodNumber','fpedats','fpi','netPctUp','meanest','medest','Last_meanest','Last_medest'});
dataEst = sortrows(dataEst, {'cusip','fpedats','fpi','PeriodNumber'});
dataEst = varfun(@(x) x, dataEst, 'GroupingVariables', {'cusip','fpedats','fpi'}, ...
                                  'InputVariables', {'PeriodNumber','netPctUp','medest','meanest','Last_meanest','Last_medest'});
dataEst.Properties.VariableNames = regexprep(dataEst.Properties.VariableNames, 'Fun_', '');
dataEst(dataEst.GroupCount == 1,:) = [];

% Get the lagged PeriodNumber, medest, and meanest
dataEstLag = varfun(@(x) lag(x, 1, nan), dataEst, 'GroupingVariables', {'cusip','fpedats','fpi'}, ...
                                                  'InputVariables', {'PeriodNumber','Last_meanest','Last_medest'});

% Assign the lagged mean and median estimates to dataEst
dataEst.lagMeanEst = dataEstLag.Fun_Last_meanest;
dataEst.lagMedEst = dataEstLag.Fun_Last_medest;
dataEst.lagPeriod = dataEstLag.Fun_PeriodNumber;

% Make sure we are only using one-period lags
dataEst.lag = dataEst.PeriodNumber - dataEstLag.Fun_PeriodNumber;
dataEst(dataEst.lag ~= 1, :) = [];
dataEst(isnan(dataEst.lag), :) = [];

% Get the change in mean and median estimates
dataEst.d_meanest = dataEst.meanest - dataEst.lagMeanEst;
dataEst.d_medest = dataEst.medest - dataEst.lagMedEst;

% Filter only the relevant variables
dataEst = dataEst(:, {'cusip','fpi','PeriodNumber','netPctUp','d_meanest','d_medest'});

data_afr = unstack(dataEst,{'netPctUp','d_meanest','d_medest'},'fpi');
data_afr.Properties.VariableNames = regexprep(data_afr.Properties.VariableNames, 'x', 'fpi');

% temp = varfun(@(x) x(end,:), data_afr,'GroupingVariables',{'cusip','PeriodNumber'});

% Store the dataset
writetable(data_afr,'Data\data_ibes_analyst_forecast_revisions.csv');

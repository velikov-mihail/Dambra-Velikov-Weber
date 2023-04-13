%% Prepare the Earnings guidance data

clear
clc

fprintf('Now working on making the IBES guidance data. Run started at %s.\n\n\n', char(datetime('now')));

% Detect the import options for the 8K data
opts = detectImportOptions('IBES_DET_GUIDANCE.csv');

% Ensure Ticker variable is a character
indTicker = strcmp(opts.VariableNames,'ticker');
opts.VariableTypes(indTicker) = {'char'};

% Read the data
data = readtable('IBES_DET_GUIDANCE.csv',opts);

% Read the IBES/CRSP linking file
opts = detectImportOptions('WRDSAPPS_IBCRSPHIST.csv');

% Ensure Ticker variable is a character
ind = ismember(opts.VariableNames,{'ticker','ncusip'});
opts.VariableTypes(ind) = {'char'};

% Read the data
ibes_crsp_link = readtable('WRDSAPPS_IBCRSPHIST.csv',opts);
ibes_crsp_link(ibes_crsp_link.score==6, :)=[];

data = outerjoin(data, ibes_crsp_link, 'Type','Left', ...
                                        'Keys', 'ticker', ...
                                        'MergeKeys', 1, ...
                                        'RightVariables', {'ncusip', 'sdate', 'edate'});
                                    
indToDrop = data.anndats > data.edate | ...
            data.anndats < data.sdate;
        
data(indToDrop, :)=[];

% Create EPS and Any guidance dummies, dates and subsample
data.eps_guidance = 1* strcmp(data.measure,'EPS');
data.any_guidance = ones(height(data), 1);
data.date         = 10000 * year(data.anndats) + ...
                      100 * month(data.anndats) + ...
                            day(data.anndats);

data = data(:, {'ncusip','date','eps_guidance','any_guidance'});
data_3wk = data;

% Load the unique periods 
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

% Aggregate over the FOMC periods
inputVarNames = {'eps_guidance','any_guidance'};

% Create the dummies first    
data_dummies = varfun(@max,data,'GroupingVariables',{'ncusip','PeriodNumber'}, ...
                                'InputVariables',   inputVarNames);
data_dummies.GroupCount = [];

% Fix the variable names - add '_d' to indicate they are dummies
anonFun  = @(x) cat(2, char(x),'_d');
newNames = cellfun(anonFun,inputVarNames,'UniformOutput',0);
data_dummies.Properties.VariableNames = [{'cusip','PeriodNumber'},newNames];

% Get the sum next
data_sum = varfun(@(x) nansum(x),data,'GroupingVariables',{'ncusip','PeriodNumber'}, ...
                                      'InputVariables',   inputVarNames);
data_sum.GroupCount = [];

% Fix the variable names - add '_n' to indicate they are counts
anonFun  = @(x) cat(2, char(x),'_n');
newNames = cellfun(anonFun, inputVarNames, 'UniformOutput', 0);
data_sum.Properties.VariableNames = [{'cusip','PeriodNumber'},newNames];

data_guid = outerjoin(data_sum, data_dummies, 'MergeKeys', 1);

% Make the three-week any guidance variables
% Load the unique periods 
load periods
periodStart3wk = datetime(periods.PeriodStart, 'ConvertFrom', 'yyyyMMdd') + ...
                caldays(21);
periods.PeriodEnd = 10000 * year(periodStart3wk) + ... 
                      100 * month(periodStart3wk) + ...
                            day(periodStart3wk);

% Create a big matrix that would correspond to whether the filing date is
% in the intermeeting period
temp  = periods.PeriodStart' <= data_3wk.date;
temp2 = periods.PeriodEnd'   >  data_3wk.date;
temp  = (temp & temp2)';

% Assign the corresponding period numbers to each row in data
[row, col]        = find(temp);
per               = zeros(height(data_3wk),1);
per(col)          = row;
data_3wk.PeriodNumber = per;

% Delete the cases outside of our CCM/FOMC data
indToDrop         = (data_3wk.PeriodNumber==0);
data_3wk(indToDrop,:) = [];

% Drop the eps, change name
data_3wk.eps_guidance = [];
data_3wk.Properties.VariableNames{'any_guidance'} = 'any_guidance_3wk';

% Aggregate over the FOMC periods
inputVarNames = {'any_guidance_3wk'};

% Create the dummies first    
data_dummies = varfun(@max, data_3wk, 'GroupingVariables',{'ncusip','PeriodNumber'}, ...
                                      'InputVariables',   inputVarNames);
data_dummies.GroupCount = [];

% Fix the variable names - add '_d' to indicate they are dummies
anonFun  = @(x) cat(2, char(x),'_d');
newNames = cellfun(anonFun,inputVarNames,'UniformOutput',0);
data_dummies.Properties.VariableNames = [{'cusip','PeriodNumber'},newNames];

% Get the sum next
data_sum = varfun(@(x) nansum(x), data_3wk, 'GroupingVariables',{'ncusip','PeriodNumber'}, ...
                                            'InputVariables',   inputVarNames);
data_sum.GroupCount = [];

% Fix the variable names - add '_n' to indicate they are counts
anonFun  = @(x) cat(2, char(x),'_n');
newNames = cellfun(anonFun, inputVarNames, 'UniformOutput', 0);
data_sum.Properties.VariableNames = [{'cusip','PeriodNumber'},newNames];

% Merge the 3-week variables to the main data
data_guid = outerjoin(data_guid, data_dummies, 'Type', 'Left', ...
                                              'MergeKeys', 1);
data_guid = outerjoin(data_guid, data_sum, 'Type', 'Left', ...
                                           'MergeKeys', 1);

% Store the cleaned up 8k dataset
writetable(data_guid,'Data\data_ibes_guidance.csv');

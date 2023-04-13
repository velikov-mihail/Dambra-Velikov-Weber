%% Prepare the 8k data

clear
clc

fprintf('Now working on making the 8K data. Run started at %s.\n\n\n', char(datetime('now')));

% Detect the import options for the 8K data
opts = detectImportOptions('WRDSSEC_ITEMS8K.csv');

% Ensure CIK variable is a character
indCik                     = strcmp(opts.VariableNames,'cik');
opts.VariableTypes(indCik) = {'char'};

% Select only the following variables
opts.SelectedVariableNames = {'cik','fdate','coname','fsize','nitem','item','form'};

% Read the data
data = readtable('WRDSSEC_ITEMS8K.csv',opts);

% Round the numeric item number to the second decimal
data.nitem = round(data.nitem,2);

% Drop non-8k observations & the form variable
indToDrop         = ~strcmp(data.form,'8-K');
data(indToDrop,:) = [];
data.form         = [];

% Create a few more variables
data.nonea_8k            = 1 * ~ismember(data.nitem,[2.02,9.01,7,12]);
data.sec201_8k           = 1 * ismember(data.nitem,[2.01]);
data.sec_material_8k     = 1 * ismember(data.nitem,[1.01,1.02,2.01,2.03,2.04,2.05,2.06,3.03,5.02,5.05,6.03,6.04,6.05,8.01]);
data.sec_nonmaterial_8k  = 1 * ismember(data.nitem,[1.03,1.04,3.01,3.02,4.01,4.02,5.01,5.03,5.04,5.06,5.07,5.08,6.01,6.02,7.01]);

% Make the pre-2004 observations NaNs
data.ever_8k_d(data.fdate < datetime(2004, 1, 1)) = nan;

% Add the delayed M&A 8K flag
% read in the CUSIP/CIK link
opts                    = detectImportOptions('cusip_cik_link.csv');
ind                     = ismember(upper(opts.VariableNames), {'CIK','CUSIP_FULL','CUSIP'});
opts.VariableTypes(ind) = repmat({'char'}, 1, sum(ind));
cusip_cik_link          = readtable('cusip_cik_link.csv', opts);

% Read in the M&A data
% opts                    = detectImportOptions('temp_ma_data.csv');
% ind                     = ismember(opts.VariableNames, {'Acquiror6_digitCUSIP'});
% opts.VariableTypes(ind) = repmat({'char'}, 1, sum(ind));
% ma_data                 = readtable('temp_ma_data.csv', opts);
ma_data = load('temp_ma_data.mat');
ma_data = ma_data.data;

data.fdate_yyyymmdd = 10000 * year(data.fdate) + ...
                        100 * month(data.fdate) + ...
                              day(data.fdate);

data.sec_201_8k_delayed = zeros(height(data), 1);
ind201 = find(data.sec201_8k == 1);
for j = 1:length(ind201)
    
    i = ind201(j);
    indThisCik = find(strcmp(cusip_cik_link.cik, data.cik(i)) & ...
                 cusip_cik_link.cikdate1 <= data.fdate_yyyymmdd(i) & ...
                 cusip_cik_link.cikdate2 >= data.fdate_yyyymmdd(i));
    if ~isempty(indThisCik)           
        thisCusip = extractBetween(cusip_cik_link.cusip(indThisCik(end)), 1, 6);
        r = find( strcmp(ma_data.Acquiror6_digitCUSIP, thisCusip) & ...
                  ma_data.DateAnnounced <= data.fdate(i) & ...
                  ma_data.DateAnnounced >= data.fdate(i) + caldays(15));
        if isempty(r)
            data.sec_201_8k_delayed(i) = 1;
        end        
    end
    
end

data_3wk = data(:, {'cik','fdate_yyyymmdd','nonea_8k'});

% Load periods
load periods

% Create a big matrix that would correspond to whether the filing date is
% in the intermeeting period
temp  = periods.PeriodStart' <= data.fdate_yyyymmdd;
temp2 = periods.PeriodEnd'   >  data.fdate_yyyymmdd;
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
inputVarNames = {'nonea_8k','sec201_8k', 'sec_201_8k_delayed', ...
                'sec_material_8k','sec_nonmaterial_8k'};

% Create the dummies first    
data_dummies = varfun(@max,data,'GroupingVariables',{'cik','PeriodNumber'}, ...
                                'InputVariables',   inputVarNames);
data_dummies.GroupCount = [];

% Fix the variable names - add '_d' to indicate they are dummies
anonFun  = @(x) cat(2, char(x),'_d');
newNames = cellfun(anonFun,inputVarNames,'UniformOutput',0);
data_dummies.Properties.VariableNames = [{'cik','PeriodNumber'},newNames];

% Get the sum next
data_sum = varfun(@(x) nansum(x),data,'GroupingVariables',{'cik','PeriodNumber'}, ...
                                      'InputVariables',   inputVarNames);
data_sum.GroupCount = [];

% Fix the variable names - add '_n' to indicate they are counts
anonFun  = @(x) cat(2, char(x),'_n');
newNames = cellfun(anonFun, inputVarNames, 'UniformOutput', 0);
data_sum.Properties.VariableNames = [{'cik','PeriodNumber'},newNames];

% Save the names to compare the match with CCM
data_names = unique(data(:,{'cik','PeriodNumber','coname'}));
data_names = varfun(@(x) x(end,:),data_names,'GroupingVariables',{'cik','PeriodNumber'}, ...
                                             'InputVariables',   'coname');
data_names.GroupCount               = [];
data_names.Properties.VariableNames = {'cik','PeriodNumber','Name'};
    
% Join the names, counts, and dummies tables
data_sec = outerjoin(data_names, data_sum, 'MergeKeys', 1);
data_sec = outerjoin(data_sec, data_dummies, 'MergeKeys', 1);

% Add the 3-week nonea_8k indicator     
data_3wk.Properties.VariableNames{'nonea_8k'} = 'nonea_8k_3wk';

% Load periods
load periods
periodStart3wk = datetime(periods.PeriodStart, 'ConvertFrom', 'yyyyMMdd') + ...
                caldays(21);
periods.PeriodEnd = 10000 * year(periodStart3wk) + ... 
                      100 * month(periodStart3wk) + ...
                            day(periodStart3wk);


% Create a big matrix that would correspond to whether the filing date is
% in the intermeeting period
temp  = periods.PeriodStart' <= data_3wk.fdate_yyyymmdd;
temp2 = periods.PeriodEnd'   >  data_3wk.fdate_yyyymmdd;
temp  = (temp & temp2)';


% Assign the corresponding period numbers to each row in data
[row, col]        = find(temp);
per               = zeros(height(data_3wk),1);
per(col)          = row;
data_3wk.PeriodNumber = per;

% Delete the cases outside of our CCM/FOMC data
indToDrop         = (data_3wk.PeriodNumber==0);
data_3wk(indToDrop,:) = [];

% Aggregate over the FOMC periods
inputVarNames = {'nonea_8k_3wk'};

% Create the dummies first    
data_dummies = varfun(@max,data_3wk,'GroupingVariables',{'cik','PeriodNumber'}, ...
                                'InputVariables',   inputVarNames);
data_dummies.GroupCount = [];

% Fix the variable names - add '_d' to indicate they are dummies
anonFun  = @(x) cat(2, char(x),'_d');
newNames = cellfun(anonFun,inputVarNames,'UniformOutput',0);
data_dummies.Properties.VariableNames = [{'cik','PeriodNumber'},newNames];

% Get the sum next
data_sum = varfun(@(x) nansum(x),data_3wk,'GroupingVariables',{'cik','PeriodNumber'}, ...
                                      'InputVariables',   inputVarNames);
data_sum.GroupCount = [];

% Fix the variable names - add '_n' to indicate they are counts
anonFun  = @(x) cat(2, char(x),'_n');
newNames = cellfun(anonFun, inputVarNames, 'UniformOutput', 0);
data_sum.Properties.VariableNames = [{'cik','PeriodNumber'},newNames];
                                  

% Merge the 3-week variables to the main data
data_sec = outerjoin(data_sec, data_dummies, 'Type', 'Left', ...
                                              'MergeKeys', 1);
data_sec = outerjoin(data_sec, data_sum, 'Type', 'Left', ...
                                           'MergeKeys', 1);
                                  
% Store the cleaned up 8k dataset
writetable(data_sec,'Data\data_8k.csv');

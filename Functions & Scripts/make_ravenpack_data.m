%% Prepare the Ravenpack data

clear
clc

fprintf('Now working on making the Ravenpack data. Run started at %s.\n\n\n', char(datetime('now')));

rp_data = [];
for i = 2004:2020
    % Detect the import options for this year's file.
    opts = detectImportOptions(['RPNA_PR_EQUITIES_',char(num2str(i)),'.csv']);
    
    % Select the variables we need
    opts.VariableNames = upper(opts.VariableNames);
    opts.SelectedVariableNames = {'ISIN','ENTITY_NAME','ESS','NIP','PEQ','RPNA_DATE_UTC','TYPE','GROUP'};
    
    % Make we sure we read these as chars
    charVars = {'ISIN','ENTITY_NAME','TYPE','GROUP'};
    nCharVars = length(charVars);
    indCharVars = find(ismember(opts.VariableNames,charVars));
    opts.VariableTypes(indCharVars) = repmat({'char'}, 1, nCharVars);
    
    % Make sure we read these as numeric
    numVars = {'ESS','NIP','PEQ'};
    nNumVars = length(numVars);
    indNumVars = find(ismember(opts.VariableNames,numVars));
    opts.VariableTypes(indNumVars)=repmat({'double'}, 1, nNumVars);
    
    % Read this year's file and attach to the table for all years
    thisYrData = readtable(['RPNA_PR_EQUITIES_',char(num2str(i)),'.csv'], opts);
    rp_data = [rp_data; thisYrData];
end

% Store the raw data for the match with 8k's later
writetable(rp_data,'Data\rp_data_raw.csv');

% Change the format for the dates to yyyymmdd
rp_data.RPNA_DATE_UTC = 10000 * year(rp_data.RPNA_DATE_UTC) + ...
                          100 * month(rp_data.RPNA_DATE_UTC) + ...
                                day(rp_data.RPNA_DATE_UTC);

% opts=detectImportOptions('rp_data.csv');
% rp_data=readtable('rp_data.csv',opts);

nObs = height(rp_data);

rp_data.rp_ea              = zeros(nObs, 1);
rp_data.rp_nonea           = zeros(nObs, 1);
rp_data.rp_product         = zeros(nObs, 1);
rp_data.rp_mnap            = zeros(nObs, 1);
rp_data.rp_labor           = zeros(nObs, 1);
rp_data.rp_finance         = zeros(nObs, 1);
rp_data.rp_equity          = zeros(nObs, 1);
rp_data.rp_debt            = zeros(nObs, 1);
rp_data.rp_marketing       = zeros(nObs, 1);
rp_data.rp_contract        = zeros(nObs, 1);
rp_data.rp_product_release = zeros(nObs, 1);
rp_data.rp_product_other   = zeros(nObs, 1);
rp_data.rp_other           = zeros(nObs, 1);


% Create an earning-related dummy
indEa = ismember(rp_data.GROUP,{'earnings','revenues','investor-relations'});
rp_data.rp_ea(indEa)     = 1;
rp_data.rp_nonea(~indEa) = 1;
rp_data.total = rp_data.rp_ea + rp_data.rp_nonea;


% Create topical dummies
indProduct = ismember(rp_data.GROUP, {'products-services'});
rp_data.rp_product(indProduct) = 1;

indMnap = ismember(rp_data.GROUP, {'acquisitions-mergers'});
rp_data.rp_mnap(indMnap) = 1;

indLabor = ismember(rp_data.GROUP, {'labor-issues'});
rp_data.rp_labor(indLabor) = 1;

indFinance = ismember(rp_data.GROUP, {'equity-actions','credit','dividends','credit-ratings'});
rp_data.rp_finance(indFinance) = 1;

indEquity = ismember(rp_data.GROUP,{'equity-actions','dividends'});
rp_data.rp_equity(indEquity) = 1;

indDebt = ismember(rp_data.GROUP,{'credit','credit-ratings'});
rp_data.rp_debt(indDebt)=1;

indMarketing = ismember(rp_data.GROUP,{'marketing'});
rp_data.rp_marketing(indMarketing) = 1;

indContract = ismember(rp_data.TYPE,{'business-contract'});
rp_data.rp_contract(indContract) = 1;

indProductRelease = ismember(rp_data.TYPE,{'product-release'});
rp_data.rp_product_release(indProductRelease) = 1;

indProductOther = ismember(rp_data.GROUP,{'products-services'});
rp_data.rp_product_other(indProductOther) = 1;

indOther = ~ismember(rp_data.GROUP,{'earnings', 'revenues', 'investor-relations', ...
                                    'products-services','dividends','acquisitions-mergers', ...
                                    'labor-issues','equity-actions','credit','credit-ratings','marketing'});
rp_data.rp_other(indOther) = 1;

% WHEN MEASURING TONE -- I ENSURE THAT THE TONE VARIABLES ARE FOR THE "IN-SAMPLE" OBS -- I.E.; NOT RELATED TO EARNINGS ANNOUNCEMENTS
rp_data.ESS(rp_data.rp_ea==1) = nan;
rp_data.PEQ(rp_data.rp_ea==1) = nan;


% Extract the cusip from the ISIN
rp_data.cusip = cellfun(@(x) extractBetween(x,3,10), rp_data.ISIN);
rp_data(strcmp(rp_data.cusip, '00000000'), :) = [];

% Store the data for the 3-week variables
rp_data_3wk = rp_data(:,{'cusip','RPNA_DATE_UTC','rp_nonea'});

% Load the CCM data & merge the periods 
load periods

% Create a big matrix that would correspond to whether the filing date is
% in the intermeeting period
temp  = periods.PeriodStart' <= rp_data.RPNA_DATE_UTC;
temp2 = periods.PeriodEnd'   >  rp_data.RPNA_DATE_UTC;
temp  = (temp & temp2)';


% Assign the corresponding period numbers to each row in data
[row, col]           = find(temp);
per                  = zeros(height(rp_data),1);
per(col)             = row;
rp_data.PeriodNumber = per;

% Delete the cases outside of our CCM/FOMC data
rp_data(rp_data.PeriodNumber==0, :) = [];


% Filter the data
rp_data = rp_data(:, {'cusip','PeriodNumber','ENTITY_NAME','ESS','NIP','PEQ', ...
                     'rp_ea','rp_nonea','rp_product','rp_mnap','rp_labor','rp_finance','rp_equity','rp_debt','rp_marketing','rp_other', ...
                     'rp_product_other','rp_contract','rp_product_release'});
                

% Choose the input variables
inputVarNames = {'rp_ea','rp_nonea','rp_product','rp_mnap','rp_labor', ...
                 'rp_finance','rp_equity','rp_debt','rp_marketing','rp_other',...
                 'rp_product_other','rp_contract','rp_product_release'};

% Get the dummies first    
rp_data_dummies = varfun(@max, rp_data, 'GroupingVariables', {'cusip','PeriodNumber'}, ...
                                        'InputVariables', inputVarNames);
rp_data_dummies.GroupCount = [];

% Fix the names
newNames = cellfun(@(x) cat(2,char(x),'_d'), inputVarNames, 'UniformOutput', 0);
rp_data_dummies.Properties.VariableNames = [{'cusip','PeriodNumber'},newNames];

% Get the sum next
inputVarNames = inputVarNames(1:end-3);
rp_data_sum = varfun(@(x) nansum(x), rp_data, 'GroupingVariables', {'cusip','PeriodNumber'}, ...
                                              'InputVariables', inputVarNames);
rp_data_sum.GroupCount = [];

% Fix the names
newNames = cellfun(@(x) cat(2,char(x),'_n'), inputVarNames, 'UniformOutput', 0);
rp_data_sum.Properties.VariableNames = [{'cusip','PeriodNumber'}, newNames];

% Get the means next
rp_data_means = varfun(@(x) nanmean(x), rp_data, 'GroupingVariables', {'cusip','PeriodNumber'}, ...
                                                 'InputVariables', {'NIP','ESS','PEQ'});
rp_data_means.GroupCount = [];

% Fix the nanes
rp_data_means.Properties.VariableNames = regexprep(rp_data_means.Properties.VariableNames, 'Fun_', '');

% Get the unique names 
rp_data_names = unique(rp_data(:, {'cusip','PeriodNumber','ENTITY_NAME'}));
rp_data_names = sortrows(rp_data_names, {'cusip','PeriodNumber'}, 'ascend');
rp_data_names = varfun(@(x) x(end,:), rp_data_names, 'InputVariables', 'ENTITY_NAME', ...
                                                     'GroupingVariables', {'cusip','PeriodNumber'});
rp_data_names.GroupCount = [];
rp_data_names.Properties.VariableNames = {'cusip','PeriodNumber','Name'};

% Merge the tables
data_rp = outerjoin(rp_data_names, rp_data_sum, 'MergeKeys', 1);
data_rp = outerjoin(data_rp, rp_data_dummies, 'MergeKeys', 1);
data_rp = outerjoin(data_rp, rp_data_means, 'MergeKeys', 1);

% Create a couple of more variables
data_rp.rp_total_d = max([data_rp.rp_ea_d, data_rp.rp_nonea_d], [], 2);
data_rp.rp_total_n = sum([data_rp.rp_ea_n, data_rp.rp_nonea_n], 2);


% Now do the 3-week variables

% Load the CCM data & merge the periods 
load periods
periodStart3wk = datetime(periods.PeriodStart, 'ConvertFrom', 'yyyyMMdd') + ...
                caldays(21);
periods.PeriodEnd = 10000 * year(periodStart3wk) + ... 
                      100 * month(periodStart3wk) + ...
                            day(periodStart3wk);


% Create a big matrix that would correspond to whether the filing date is
% in the intermeeting period
temp  = periods.PeriodStart' <= rp_data_3wk.RPNA_DATE_UTC;
temp2 = periods.PeriodEnd'   >  rp_data_3wk.RPNA_DATE_UTC;
temp  = (temp & temp2)';


% Assign the corresponding period numbers to each row in data
[row, col]           = find(temp);
per                  = zeros(height(rp_data_3wk),1);
per(col)             = row;
rp_data_3wk.PeriodNumber = per;

% Delete the cases outside of our CCM/FOMC data
rp_data_3wk(rp_data_3wk.PeriodNumber==0, :) = [];


% Filter the data
rp_data_3wk = rp_data_3wk(:, {'cusip','PeriodNumber','rp_nonea'});
rp_data_3wk.Properties.VariableNames{'rp_nonea'} = 'rp_nonea_3wk';      

% Choose the input variables
inputVarNames = {'rp_nonea_3wk'};

% Get the dummies first    
rp_data_dummies = varfun(@max, rp_data_3wk, 'GroupingVariables', {'cusip','PeriodNumber'}, ...
                                        'InputVariables', inputVarNames);
rp_data_dummies.GroupCount = [];

% Fix the names
newNames = cellfun(@(x) cat(2,char(x),'_d'), inputVarNames, 'UniformOutput', 0);
rp_data_dummies.Properties.VariableNames = [{'cusip','PeriodNumber'},newNames];

% Get the sum next
rp_data_sum = varfun(@(x) nansum(x), rp_data_3wk, 'GroupingVariables', {'cusip','PeriodNumber'}, ...
                                              'InputVariables', inputVarNames);
rp_data_sum.GroupCount = [];

% Fix the names
newNames = cellfun(@(x) cat(2,char(x),'_n'), inputVarNames, 'UniformOutput', 0);
rp_data_sum.Properties.VariableNames = [{'cusip','PeriodNumber'}, newNames];


% Merge the 3-week variables to the main data
data_rp = outerjoin(data_rp, rp_data_dummies, 'Type', 'Left', ...
                                              'MergeKeys', 1);
data_rp = outerjoin(data_rp, rp_data_sum, 'Type', 'Left', ...
                                           'MergeKeys', 1);


% Store the cleaned up Ravenpack dataset
writetable(data_rp, ['Data', filesep, 'data_rp.csv']);


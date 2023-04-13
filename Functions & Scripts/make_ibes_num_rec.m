clear
clc

fprintf('Now working on making the IBES number of recommendations data. Run started at %s.\n\n\n', char(datetime('now')));

opts                        = detectImportOptions('IBES_RECDSUM.csv');
indChar                     = ismember(opts.VariableNames, {'ticker','cusip'});
opts.VariableTypes(indChar) = repmat({'char'}, sum(indChar), 1);
ibes_recdsum                = readtable('IBES_RECDSUM.csv',opts);

% Take the unique periods & their start and end dates
load periods

% Create a big matrix that would correspond to whether the start in the
% intermeeting period is in the same month with the IBES month
periods.yyyymm      = floor(periods.PeriodStart/100);
ibes_recdsum.yyyymm = 100*year(ibes_recdsum.statpers) + month(ibes_recdsum.statpers);
temp                = (periods.yyyymm'==ibes_recdsum.yyyymm)';

% Assign the corresponding period numbers to each row in data
[row, col]                = find(temp);
per                       = zeros(height(ibes_recdsum),1);
per(col)                  = row;
ibes_recdsum.PeriodNumber = per;

% Delete the cases outside of our IBES data
indToDrop                 = (ibes_recdsum.PeriodNumber==0) | ...
                            strcmp(ibes_recdsum.cusip, '');
ibes_recdsum(indToDrop,:) = [];

data_ibes_num_rec = varfun(@(x) x(end,:), ibes_recdsum, 'GroupingVariables', {'cusip','PeriodNumber'}, ...
                                                        'InputVariables', 'numrec');
data_ibes_num_rec.GroupCount = [];
data_ibes_num_rec.Properties.VariableNames = {'cusip','PeriodNumber','numrec'};

% Store it
writetable(ibes_recdsum,'Data\data_ibes_num_rec.csv');
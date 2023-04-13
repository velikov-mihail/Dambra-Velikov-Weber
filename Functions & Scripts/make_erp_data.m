clear
clc

fprintf('Now working on making the ERP data. Run started at %s.\n\n\n', char(datetime('now')));

% Read in the Lee, So, and Wang (2022) ERP file from 
% https://leesowang2021.github.io/data/
% October, 2022 version of the file used here. Downloaded and exported into
% a .csv file from Stata on on 3/17/2023 by Mihail Velikov
fileName = 'erp_public_221025';
opts = detectImportOptions(fileName);
indGvkey = strcmp(opts.VariableNames, 'gvkey');
opts.VariableTypes(~indGvkey) = repmat({'double'}, 1, sum(~indGvkey));
data = readtable(fileName, opts);

load crsp_link
load ret

data.Properties.VariableNames{'yearmonth'} = 'dates';
data.gvkey = [];

erp = struct;

for i = 3:size(data, 2)
    varName = data.Properties.VariableNames(i);
    tempData = data(: ,[{'permno','dates'}, varName]);
    tempData.Properties.VariableNames = {'permno','dates','var'};
    mergedData = outerjoin(crsp_link, tempData, 'Type', 'Left', 'MergeKeys', 1);
    
    varTable = unstack(mergedData, 'var', 'dates');
    varTable.permno = [];
    var = table2array(varTable)';
    erp.(lower(char(varName))) = var;
end

save Data\erp erp -v7.3


clear
clc

fprintf('Now working on making the 8K/Ravenpack merge data. Run started at %s.\n\n\n', char(datetime('now')));

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
data(ismember(data.nitem,[2.02,9.01,7,12]), :) = [];

% read in the CUSIP/CIK link
opts                    = detectImportOptions('cusip_cik_link.csv');
ind                     = ismember(upper(opts.VariableNames), {'CIK','CUSIP_FULL','CUSIP'});
opts.VariableTypes(ind) = repmat({'char'}, 1, sum(ind));
cusip_cik_link          = readtable('cusip_cik_link.csv', opts);
% Adjust the SEC/CUSIP link - fix dates format
cusip_cik_link.cikdate1 = datetime(cusip_cik_link.cikdate1, 'ConvertFrom', 'yyyyMMdd');
cusip_cik_link.cikdate2 = datetime(cusip_cik_link.cikdate2, 'ConvertFrom', 'yyyyMMdd');

data = outerjoin(data, cusip_cik_link, 'Keys', 'cik', ...
                                        'Type', 'Left', ...
                                        'RightVariables', {'cusip','cikdate1','cikdate2'});

indToDrop = data.fdate <= data.cikdate1 | ...
            data.fdate > data.cikdate2;
data(indToDrop, :) = [];

data = varfun(@(x) x(end,:), data, 'GroupingVariables',{'cik','fdate','fsize','nitem','item'});
data = data(:, {'Fun_cusip','fdate','Fun_coname'});
data.Properties.VariableNames = {'cusip','fdate','sec_name'};

% Load the Ravenpack data
opts = detectImportOptions('rp_data_raw.csv');
rp_data = readtable('rp_data_raw.csv', opts);

% Extract the cusip from the ISIN
rp_data.cusip = cellfun(@(x) extractBetween(x,3,10), rp_data.ISIN);
rp_data(strcmp(rp_data.cusip, '00000000'), :) = [];
rp_data = rp_data(:, {'cusip','RPNA_DATE_UTC','ENTITY_NAME'});

% Merge the two 
merged_data = outerjoin(data, rp_data, 'Type','full', ...
                                       'Keys', 'cusip', ...
                                       'MergeKeys', 1);
merged_data.diff = days(merged_data.fdate - merged_data.RPNA_DATE_UTC);
merged_data(abs(merged_data.diff)>3 | isnan(merged_data.diff),:)=[];

merged_data.RPNA_DATE_UTC = 10000 * year(merged_data.RPNA_DATE_UTC) + ...
                              100 * month(merged_data.RPNA_DATE_UTC) + ...
                                    day(merged_data.RPNA_DATE_UTC);
% Load the CCM data & merge the periods 
load periods

% Create a big matrix that would correspond to whether the filing date is
% in the intermeeting period
temp  = periods.PeriodStart' <= merged_data.RPNA_DATE_UTC;
temp2 = periods.PeriodEnd'   >  merged_data.RPNA_DATE_UTC;
temp  = (temp & temp2)';


% Assign the corresponding period numbers to each row in data
[row, col]           = find(temp);
per                  = zeros(height(merged_data),1);
per(col)             = row;
merged_data.PeriodNumber = per;

merged_data(merged_data.PeriodNumber == 0, :) = [];

data_8k_rp = varfun(@max, merged_data, 'GroupingVariables', {'cusip','PeriodNumber'}, ...
                                       'InputVariables', 'diff');
data_8k_rp(:, {'GroupCount','max_diff'}) = [];
data_8k_rp.rp_8k_match = ones(height(data_8k_rp), 1);

writetable(data_8k_rp, 'Data\data_8k_rp.csv');
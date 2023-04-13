%% Make io data

% Run this first:
% https://wrds-www.wharton.upenn.edu/pages/support/applications/institutional-ownership-research/institutional-ownership-concentration-and-breadth-ratios/

fprintf('Now working on making the institutional ownership data. Run started at %s.\n\n\n', char(datetime('now')));


clear
clc

load ret
load dates
load permno

% Detect the import options for file with IO data
opts = detectImportOptions('io_timeseries.csv');

% Make sure we can read the IO variable
indIO                     = find(strcmp(opts.VariableNames,'IOR'));
opts.VariableTypes(indIO) = {'double'};
opts                      = setvaropts(opts, 'IOR', 'TrimNonNumeric', true);
opts                      = setvaropts(opts, 'IOR', 'ThousandsSeparator', ',');

% Read the data in
data = readtable('io_timeseries.csv',opts);

% Fix the dates format
data.dates = datetime(data.rdate, 'InputFormat','ddMMMyyy');
data.dates = 100*year(data.dates) + month(data.dates);

% Leave only rows with nonmissing IO and permnos in our sample
permnoToDrop       = ~ismember(data.PERMNO,permno);
ioToDrop           = (data.IO_MISSING == 1);
rowsToDrop         = (permnoToDrop | ioToDrop);
data(rowsToDrop,:) = [];

% Make the IO variable a percentage
data.IOR = data.IOR/100;

% Leave only the relevant variables
data = data(:,{'PERMNO','dates','IOR'});

% These next few lines create the CRSP linking table

% Store the dimensions first
nmonths = length(dates);
nstocks = length(permno);
numobs  = nmonths * nstocks;

% Turn the dates and permno vectors into matrices
rptdDates  = repmat(dates  , 1      , nstocks);
rptdPermno = repmat(permno', nmonths, 1      );

% Reshape the dates and permno repeated matrices
rshpdDates  = reshape(rptdDates, numobs, 1);
rshpdPermno = reshape(rptdPermno, numobs, 1);

% Create the linking table
crsp_mat_link = array2table([rshpdPermno rshpdDates], ... 
                            'VariableNames',{'permno','dates'});

% Merge the CRSP linking table and the IO table through a left join on
% permno and dates
mergedTable = outerjoin(crsp_mat_link, data, ...
                            'Type'          , 'Left'            , ...
                            'MergeKeys'     , 1                 , ...
                            'LeftKeys'      , {'permno','dates'}, ...
                            'RightKeys'     , {'PERMNO','dates'}, ...
                            'RightVariables', 'IOR'              );

% Unstack the merged table and convert to our regular matrix format
io_pct      = unstack(mergedTable, 'IOR', 'dates');
io_pct      = table2array(io_pct)';
io_pct(1,:) = [];

% Fill in the missing months
io_pct = FillMonths(io_pct);

% Save the matrix
save Data\io_pct io_pct


clear
clc

fprintf('Now working on making the FOMC surprise data. Run started at %s.\n\n\n', char(datetime('now')));

load ddates

% Download the surprises from Kenn Kuttner'ss website
filePath = [pwd, filesep, 'Inputs', filesep];
fileId = '1Up04KzMYug9zyKWYFdrOgQD7S6n_Q7d7';
fileName = 'dailyFFsurprises.xlsx';
getGoogleDriveData(fileName, fileId, filePath);


% Load the daily Fed funds surprises from Ken Kuttner's file
opts        = detectImportOptions('dailyFFsurprises.xlsx');
KuttnerData = readtable('dailyFFsurprises.xlsx',opts);

% Fix the dates variable name
KuttnerData.Properties.VariableNames{'Var1'} = 'date';
KuttnerData.yyyymmdd = 10000*year(KuttnerData.date) + ...
                         100*month(KuttnerData.date) + ...
                             day(KuttnerData.date);

% Create a year
KuttnerData.YYYY = floor(KuttnerData.yyyymmdd/10000);

% Leave only the relevant surprises (scheduled & post-94 meetings)
schdldInd   = (KuttnerData.ScheduledFOMCMeeting == 1);
post94Ind   = (KuttnerData.YYYY >= 1994);
intToKeep   = schdldInd & post94Ind;
KuttnerData = KuttnerData(intToKeep,{'yyyymmdd','Surprise','Change'});

% Rename the variables
KuttnerData.Properties.VariableNames={'yyyymmdd','KuttnerSurp','KuttnerChange'};

% Download the GSS surprises
urlLink = 'https://onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1111%2Fjofi.13163&file=jofi13163-sup-0002-ReplicationCode.zip';
% urlLink = 'jofi13163-sup-0002-replicationcode.zip';
unzip(urlLink, filePath);
addpath(genpath(filePath));

% Read in the GSS surprises
opts     = detectImportOptions('GSSfactors.xlsx');
GSSData = readtable('GSSfactors.xlsx',opts);

% Rename the variables
GSSData.Properties.VariableNames = {'date','target_shock','path_shock'};

% Read in the FOMC dates 
opts       = detectImportOptions('FOMC_dates.csv');
FOMC_dates = readtable('FOMC_dates.csv',opts);

% Create a year
FOMC_dates.YYYY=year(FOMC_dates.date);

% Leave only the relevant meetings (scheduled & post-94 meetings)
schdldInd  = (FOMC_dates.scheduled == 1);
post94Ind  = (FOMC_dates.YYYY >= 1994);
intToKeep  = (schdldInd & post94Ind);
FOMC_dates = FOMC_dates(intToKeep,:);

% Filter the GSS surprises
indToKeep = ismember(GSSData.date, FOMC_dates.date); 
GSSData   = GSSData(indToKeep,:);

% Convert date to yyyymmdd & drop the date column
GSSData.yyyymmdd = 10000*year(GSSData.date) + ...
                      100*month(GSSData.date) + ...
                          day(GSSData.date);
                             

% Download the Miranda-Agrippino and Rico (2016) shocks
% Read in the FOMC dates 
url = 'http://silviamirandaagrippino.com/s/Instruments_web-x8wr.xlsx';
opts    = detectImportOptions(url);
mpiData = readtable(url, opts);
mpiData.Properties.VariableNames{'HFDates'} = 'date';

% Merge the surprises
SurpriseData = outerjoin(GSSData, KuttnerData, 'Type', 'Left', 'MergeKeys',1);
SurpriseData = outerjoin(SurpriseData, mpiData, 'Type','Left', ...
                                            'Keys', {'date'}, ...
                                            'MergeKeys', 1, ...
                                            'RightVariables', {'IV1','IV5'});

% Clean it up
SurpriseData.TargetSurp = 100*SurpriseData.target_shock;
SurpriseData.PathSurp   = 100*SurpriseData.path_shock;
SurpriseData            = SurpriseData(:,{'yyyymmdd','date','KuttnerSurp','KuttnerChange','TargetSurp','PathSurp','IV1','IV5'});

% Get Fed funds rate data - start with target (goes until 2008)
fredStruct = getFredData('DFEDTAR', [], [], 'lin', 'd', 'eop');
fredDataTarget = array2table(fredStruct.Data, 'VariableNames', {'date','targetRate'});
fredDataTarget.date = datetime(fredDataTarget.date, 'ConvertFrom', 'datenum');

% Get the target lower bound
fredStruct = getFredData('DFEDTARL', [], [], 'lin', 'd', 'eop');
fredDataTargetLB = array2table(fredStruct.Data, 'VariableNames', {'date','targetRateLB'});
fredDataTargetLB.date = datetime(fredDataTargetLB.date, 'ConvertFrom', 'datenum');

% Get the target upper bound
fredStruct = getFredData('DFEDTARU', [], [], 'lin', 'd', 'eop');
fredDataTargetUB = array2table(fredStruct.Data, 'VariableNames', {'date','targetRateUB'});
fredDataTargetUB.date = datetime(fredDataTargetUB.date, 'ConvertFrom', 'datenum');

% Get the midpoint of the target range
fredDataTargetMid = outerjoin(fredDataTargetLB, fredDataTargetUB, 'Type', 'Left', 'MergeKeys', 1);
fredDataTargetMid.targetRate = (fredDataTargetMid.targetRateLB + fredDataTargetMid.targetRateUB)/2;

% Merge the ZLB period midpoint to the target
fredDataTarget = outerjoin(fredDataTarget, fredDataTargetMid(:, {'date','targetRate'}), 'MergeKeys', 1);
fredDataTarget.targetRateChange = 100*(fredDataTarget.targetRate - lag(fredDataTarget.targetRate, 1, nan));

% merge the target rate change to the surprise data
SurpriseData = outerjoin(SurpriseData, fredDataTarget, 'Type', 'Left', ...
                                                       'MergeKeys', 1, ...
                                                       'RightVariables', {'targetRate','targetRateChange'});

% Store the surprise table
save Data\SurpriseData SurpriseData
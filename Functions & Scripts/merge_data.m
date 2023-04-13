%% Put the datasets together

clear 
clc

fprintf('Now working on merging the datasets. Run started at %s.\n\n\n', char(datetime('now')));

% Read in the CCM/FOMC data
opts                    = detectImportOptions('data_ccm.csv');
ind                     = ismember(opts.VariableNames,{'ncusip'});
opts.VariableTypes(ind) = repmat({'char'},1,sum(ind));
data_ccm                = readtable('data_ccm.csv',opts);

% Read in the SEC/CUSIP link
opts                    = detectImportOptions('cusip_cik_link.csv');
ind                     = ismember(opts.VariableNames,{'cusip','cik'});
opts.VariableTypes(ind) = repmat({'char'},1,sum(ind));
cusip_cik_link          = readtable('cusip_cik_link.csv',opts);

% Read in 8k data
opts                    = detectImportOptions('data_8k.csv');
ind                     = strcmp(opts.VariableNames,'cik');
opts.VariableTypes(ind) = {'char'};
data8k                  = readtable('data_8k.csv',opts);

% Read in Ravenpack data
opts                    = detectImportOptions('data_rp.csv');
ind                     = strcmp(opts.VariableNames,'cusip');
opts.VariableTypes(ind) = {'char'};
data_rp                 = readtable('data_rp.csv',opts);

% Read in (8k, Ravenpack) merged data
opts                    = detectImportOptions('data_8k_rp.csv');
ind                     = strcmp(opts.VariableNames,'cusip');
opts.VariableTypes(ind) = {'char'};
data_8k_rp              = readtable('data_8k_rp.csv',opts);


% Read in the IBES guidance data
opts                    = detectImportOptions('data_ibes_guidance.csv');
ind                     = strcmp(opts.VariableNames,'cusip');
opts.VariableTypes(ind) = {'char'};
data_guidance           = readtable('data_ibes_guidance.csv',opts);


% Adjust CCM - start with ensuring NCUSIP is 8-digit
data_ccm.cusip = cellfun(@(x) extractBetween(x,1,8),data_ccm.ncusip);

% Remove duplicates (for each cusip-period, leave the observation with highest
% market capitalization)
data_ccm = sortrows(data_ccm,{'cusip','PeriodNumber','MarketCap'}, 'ascend');
data_ccm = varfun(@(x) x(end,:), data_ccm, 'GroupingVariables', {'cusip','PeriodNumber'});
data_ccm.Properties.VariableNames   = regexprep(data_ccm.Properties.VariableNames,'Fun_','');
data_ccm(:,{'GroupCount','permno'}) = [];


% Merge CCM data with cusip/cik link
% We'll take all the links that are valid at the start of the FOMC
% inter-period
temp_ccm_link = outerjoin(data_ccm, cusip_cik_link, 'Type', 'Left', ... 
                                                    'Keys', 'cusip', ...
                                                    'LeftVariables', {'cusip','PeriodStart'}, ...
                                                    'RightVariables', {'cik','cikdate1','cikdate2'});
indToDrop = temp_ccm_link.PeriodStart < temp_ccm_link.cikdate1 | ...
            temp_ccm_link.PeriodStart > temp_ccm_link.cikdate2 | ...
            isnan(temp_ccm_link.cikdate1);
temp_ccm_link(indToDrop,:)  = [];             
                 
% Then we'll only leave the ones with the longest duration
linked_data_ccm = outerjoin(data_ccm, temp_ccm_link, 'Type', 'Left', ...
                                                     'Keys', {'cusip','PeriodStart'}, ...
                                                     'MergeKeys', 1);
linked_data_ccm.linkdur = days(datetime(linked_data_ccm.cikdate2,'ConvertFrom','yyyyMMdd') - ...
                               datetime(linked_data_ccm.cikdate1,'ConvertFrom','yyyyMMdd'));
                           
% Sort by duration & Leave the last one in each cusip x periodnumber
linked_data_ccm = sortrows(linked_data_ccm, {'cusip','PeriodNumber','linkdur'}, 'ascend');
linked_data_ccm = varfun(@(x) x(end,:), linked_data_ccm, 'GroupingVariables', {'cusip','PeriodNumber'});
linked_data_ccm.Properties.VariableNames = regexprep(linked_data_ccm.Properties.VariableNames, 'Fun_', '');
linked_data_ccm(:, {'GroupCount','cikdate1','cikdate2','linkdur'}) = [];

% Append 8k data
[ccm_8k_data, ~, iright] = outerjoin(linked_data_ccm, data8k, 'LeftKeys',  {'cik','PeriodNumber'}, ...
                                                              'RightKeys', {'cik','PeriodNumber'}, ...
                                                              'Type',      'Left', ...
                                                              'MergeKeys', 1);
% Indicate the SEC Analytics sample
ccm_8k_data.sec_merge              = zeros(height(ccm_8k_data),1);
indSecMerge                        = find(iright~=0);
ccm_8k_data.sec_merge(indSecMerge) = 1;

% Find all cusips for which we ever had an 8k
cusip_match = varfun(@max, ccm_8k_data, 'InputVariables',    'sec_merge', ...
                                        'GroupingVariables', 'cusip');
% Clean it up
cusip_match.GroupCount = [];
cusip_match.Properties.VariableNames{'max_sec_merge'} = 'ever_8k';

% Merge it back
ccm_8k_data = outerjoin(ccm_8k_data, cusip_match, 'Type', 'Left', ...
                                                  'MergeKeys',1);

%% Append Ravenpack data

[ccm_8k_rp_data, ~, iright] = outerjoin(ccm_8k_data, data_rp, 'Keys',      {'cusip','PeriodNumber'}, ...
                                                         'Type',      'Left', ...
                                                         'MergeKeys', 1);

% Indicate the Ravenpack Analytics sample
ccm_8k_rp_data.rp_merge              = zeros(height(ccm_8k_rp_data),1);
indRvnMerge                          = find(iright ~= 0);
ccm_8k_rp_data.rp_merge(indRvnMerge) = 1;

% Find all cusips for which we ever had a press release
cusip_match = varfun(@max, ccm_8k_rp_data, 'InputVariables', 'rp_merge', ...
                                      'GroupingVariables','cusip');

% Clean it up
cusip_match.GroupCount = [];
cusip_match.Properties.VariableNames{'max_rp_merge'} = 'ever_rp';

% Merge it back in
ccm_8k_rp_data = outerjoin(ccm_8k_rp_data, cusip_match, 'Type', 'Left', ... 
                                              'MergeKeys',1);                

%% Add the 8k depth variable from the merged (8k, Ravenpack dataset)

ccm_8k_rp_data = outerjoin(ccm_8k_rp_data, data_8k_rp, 'Type', 'Left', ... 
                                                       'MergeKeys',1);                


%% Append Guidance data

[main_data, ~, iright] = outerjoin(ccm_8k_rp_data, data_guidance, 'Keys', {'cusip','PeriodNumber'}, ...
                                                                  'Type', 'Left', ...                                                                  
                                                                  'MergeKeys', 1);

% Indicate the Ravenpack Analytics sample
main_data.guid_merge               = zeros(height(main_data),1);
indGuidMerge                       = find(iright ~= 0);
main_data.guid_merge(indGuidMerge) = 1;

% Find all cusips for which we ever had an earnings guidance
cusip_match = varfun(@max, main_data, 'InputVariables', 'guid_merge', ...
                                      'GroupingVariables','cusip');

% Clean it up
cusip_match.GroupCount = [];
cusip_match.Properties.VariableNames{'max_guid_merge'} = 'ever_guid';

% Merge it back in
main_data = outerjoin(main_data, cusip_match, 'Type', 'Left', ... 
                                              'MergeKeys',1);   

%% Append rest of the datasets

% Append IBES number of recommendations data
opts                        = detectImportOptions('data_ibes_num_rec.csv');
indChar                     = ismember(opts.VariableNames, {'cusip'});
opts.VariableTypes(indChar) = repmat({'char'}, sum(indChar), 1);
ibes_recdsum                = readtable('data_ibes_num_rec.csv', opts);


% Appnd the IBES data
final_data = outerjoin(main_data, ibes_recdsum, 'Type',           'Left', ...
                                                'Keys',           {'cusip','PeriodNumber'}, ...
                                                'RightVariables', 'numrec');


%% Append IBES analyst forecast revisions
opts                        = detectImportOptions('data_ibes_analyst_forecast_revisions.csv');
indChar                     = ismember(opts.VariableNames, {'cusip'});
opts.VariableTypes(indChar) = repmat({'char'}, sum(indChar), 1);
data_afr                    = readtable('data_ibes_analyst_forecast_revisions.csv', opts);


% Appnd the IBES data
final_data = outerjoin(final_data, data_afr, 'Type', 'Left', ...
                                             'Keys', {'cusip','PeriodNumber'}, ...
                                             'MergeKeys', 1);
                                            
%%                                            
                                            
% Read and merge the SDC data
% Add a 6-digit cusip for the merge
final_data.cusipSDCMerge    = cellfun(@(x) extractBetween(x,1,6),final_data.cusip);

% Read the M&A data
opts                        = detectImportOptions('data_sdc_ma.csv');
indChar                     = ismember(opts.VariableNames, {'Acquiror6_digitCUSIP'});
opts.VariableTypes(indChar) = repmat({'char'}, sum(indChar), 1);
data_sdc_ma                     = readtable('data_sdc_ma.csv',opts);

% Merge it in
final_data = outerjoin(final_data, data_sdc_ma, 'Type', 'Left', ...
                                                'Keys', {'cusipSDCMerge','PeriodNumber'}, ...
                                                'RightVariables', {'AcquisitionsCount','AcquisitionsValue','AcquisitionsCount3wk','AcquisitionsValue3wk'});                                                                                            

% Read the Bond data
opts                        = detectImportOptions('data_sdc_bonds.csv');
indChar                     = ismember(opts.VariableNames, {'Issuer_BorrowerUltimateParent6_digitCUSIP'});
opts.VariableTypes(indChar) = repmat({'char'}, sum(indChar), 1);
data_sdc_bonds                   = readtable('data_sdc_bonds.csv',opts);

% Merge it in
final_data = outerjoin(final_data, data_sdc_bonds, 'Type', 'Left', ...
                                                   'Keys', {'cusipSDCMerge','PeriodNumber'}, ...
                                                   'RightVariables', {'BondIssuesCount','BondIssuesValue','BondIssuesCount3wk','BondIssuesValue3wk'});

% Read the Loan data
opts                        = detectImportOptions('data_sdc_loans.csv');
indChar                     = ismember(opts.VariableNames, {'Issuer_Borrower6_digitCUSIP'});
opts.VariableTypes(indChar) = repmat({'char'}, sum(indChar), 1);
data_sdc_loans                   = readtable('data_sdc_loans.csv',opts);

% Merge it in
final_data = outerjoin(final_data, data_sdc_loans, 'Type', 'Left', ...
                                                   'Keys', {'cusipSDCMerge','PeriodNumber'}, ...
                                                   'RightVariables', {'LoanIssuesCount','LoanIssuesValue','LoanIssuesCount3wk','LoanIssuesValue3wk'});
           
%% Add & clean up variables 

% Mean, median, and Q3 MPE post 8/23/2004
post2004 = final_data.PeriodStart > 20040823;
mpe_mean = mean(final_data.MPE(post2004));

% Create the dummies
final_data.mean_mpe = 1 * (final_data.MPE > mpe_mean);

% Now do the time varying values
data_mean = varfun(@mean, final_data(:,{'PeriodNumber','MPE'}), 'GroupingVariables', 'PeriodNumber', ...
                                                                'InputVariables', 'MPE');
data_mean = data_mean(:,{'PeriodNumber','mean_MPE'});
data_mean.Properties.VariableNames = {'PeriodNumber','tv_mean_MPE'};

% merge them into the final_data
final_data = outerjoin(final_data, data_mean, 'Type', 'Left', 'MergeKeys', 1);
final_data.mean_mpe_tv = 1*(final_data.MPE - final_data.tv_mean_MPE > 0);
final_data(:,{'tv_mean_MPE'}) = [];

% Fill in some missing observations with 0
% Start with numrec
final_data.numrec(isnan(final_data.numrec)) = 0;
final_data.rp_8k_match(isnan(final_data.rp_8k_match)) = 0;

% Do all the LHS variables here
varNames = final_data.Properties.VariableNames';
varNames = varNames(contains(varNames, {'_n','_d'}));
varNames(contains(varNames,{'_data'})) = [];
for i = 1:length(varNames)
    thisVarName = char(varNames(i));
    thisVar = final_data.(thisVarName);    
    indIsNan = isnan(thisVar);
    thisVar(indIsNan) = 0;     
    final_data.(thisVarName) = thisVar;
end


% Log a bunch of variables here
final_data.ln_mcap = log(1+final_data.MarketCap);
final_data.ln_cov = log(1+final_data.numrec);

% Do all the LHS count variables here
varNames = final_data.Properties.VariableNames';
varNames = varNames(contains(varNames, {'_n'}));
varNames(contains(varNames,{'_data'})) = [];
for i = 1:length(varNames)
    thisVarName = char(varNames(i));
    thisVar = final_data.(thisVarName);    
    logThisVar = log(1+thisVar);
    logThisVarName = ['ln_', thisVarName];
    final_data.(logThisVarName) = logThisVar;
end

% Add the 8k depth measure
nobs = height(final_data);
final_data.rp_8k3 = zeros(nobs, 1);
ind8kNoPR = (final_data.nonea_8k_d == 1) & ...
            (final_data.rp_8k_match == 0);
final_data.rp_8k3(ind8kNoPR) = 1;
ind8kPR = (final_data.nonea_8k_d == 1) & ...
          (final_data.rp_8k_match == 1); 
final_data.rp_8k3(ind8kPR) = 2;

% Any issuance indicator
final_data.any_issue_d = zeros(height(final_data), 1);
indIssuance = (final_data.netshareissuance > 1) | ...
              (final_data.LoanIssuesCount > 0) | ...
              (final_data.BondIssuesCount > 0);
final_data.any_issue_d(indIssuance) = 1;          


% Do a few more adjustments and new variables
final_data.InstOwnership(final_data.InstOwnership > 1) = 1;
final_data.seo_d = 1 * (final_data.netshareissuance > 0);

final_data = sortrows(final_data, {'cusip','PeriodNumber'});
final_data.pastYearMA = zeros(height(final_data), 1);
for i = 1:height(final_data)
    ind = strcmp(final_data.cusip, final_data.cusip(i)) & ...
          final_data.PeriodNumber > (final_data.PeriodNumber(i) - 8) & ...
          final_data.PeriodNumber <= final_data.PeriodNumber(i); 
    b = sum(final_data.AcquisitionsCount(ind), 'omitnan');
    final_data.pastYearMA(i) = (b);
end                                               
                                                                                              
% Store the final dataset
writetable(final_data,'Data\final_data.csv');


%% Prepare the CIK/CUSIP link

clear
clc

fprintf('Now working on making the CIK/CUSIP link. Run started at %s.\n\n\n', char(datetime('now')));

% Read in the SEC/CUSIP link
opts                    = detectImportOptions('wrdssec_wciklink_cusip.csv');
ind                     = ismember(upper(opts.VariableNames), {'CIK','CUSIP_FULL','CUSIP'});
opts.VariableTypes(ind) = repmat({'char'}, 1, sum(ind));
cusip_cik_link          = readtable('wrdssec_wciklink_cusip.csv', opts);

% Adjust the SEC/CUSIP link - fix dates format
cusip_cik_link.cikdate1 = datetime(cusip_cik_link.cikdate1, 'InputFormat', 'ddMMMyyyy');
cusip_cik_link.cikdate2 = datetime(cusip_cik_link.cikdate2, 'InputFormat', 'ddMMMyyyy');

% Adjust the dates in SEC/CUSIP link table
cusip_cik_link.cikdate1 = 10000*year(cusip_cik_link.cikdate1) + ...
                            100*month(cusip_cik_link.cikdate1) + ...
                                day(cusip_cik_link.cikdate1);
cusip_cik_link.cikdate2 = 10000*year(cusip_cik_link.cikdate2) + ... 
                            100*month(cusip_cik_link.cikdate2) + ...
                            day(cusip_cik_link.cikdate2);

% Make sure CUSIP is 8-digit                        
cusip_cik_link.cusip = cellfun(@(x) extractBetween(x,1,8),cusip_cik_link.cusip);

% VALIDATED=0 means invalid cusip:
% https://wrds-www.wharton.upenn.edu/pages/get-data/wrds-sec-analytics-suite/wrds-sec-linking-tables/cik-cusip-link-table/
indValidated                   = (cusip_cik_link.validated == 0);
cusip_cik_link(indValidated,:) = [];

% Store it
writetable(cusip_cik_link, 'Data\cusip_cik_link.csv');

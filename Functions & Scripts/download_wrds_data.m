clear
clc

fprintf('Now working on downloading data from WRDS. Run started at %s.\n\n\n', char(datetime('now')));

% Check if the \Inputs\WRDS\ directory exists
if ~exist([pwd,'\Inputs\WRDS\'], 'dir')
    mkdir([pwd,'\Inputs\WRDS\'])
    addpath([pwd,'\Inputs\WRDS\'])
end

% Check if the \Inputs\WRDS\Ravenpack\ directory exists
if ~exist([pwd,'\Inputs\WRDS\Ravenpack\'], 'dir')
    mkdir([pwd,'\Inputs\WRDS\Ravenpack\'])
    addpath([pwd,'\Inputs\WRDS\Ravenpack\'])
end

currDir = pwd;

% Enter WRDS username & pass
Params.directory    = currDir(1:find(currDir=='\', 1, 'last'));
Params.username     = usernameUI();                                        % Input your WRDS username
Params.pass         = passwordUI();                                        % Input your WRDS password

% Setup the WRDS connection
setupWRDSConn(Params);

% Call the WRDS connection
WRDS = callWRDSConnection(Params.username, Params.pass); 

% SEC Analytics 8-K Items
getWRDSTable(WRDS, 'WRDSSEC',  'ITEMS8K',        [pwd,'\Inputs\WRDS\']); 

% SEC Analytics CUSIP link
getWRDSTable(WRDS, 'WRDSSEC',  'WCIKLINK_CUSIP', [pwd,'\Inputs\WRDS\']); 

% IBES linking table
getWRDSTable(WRDS, 'WRDSAPPS', 'IBCRSPHIST', [pwd,'\Inputs\WRDS\']); 

% IBES RECDSUM for number of recommendations
getWRDSTable(WRDS, 'IBES', 'RECDSUM',        [pwd,'\Inputs\WRDS\']); 

% IBES DET_GUIDANCE for earnings guidance
qry = ['SELECT ticker, measure, pdicity, anndats FROM IBES.DET_GUIDANCE'];
getWRDSTable(WRDS, 'IBES', 'DET_GUIDANCE',   [pwd,'\Inputs\WRDS\'], qry); 

% IBES STATSUM for analyst forecast revisions. EPS forecasts, US firms
qry = ['SELECT cusip, statpers, fpi, numest, numup, numdown, meanest, medest, fpedats, anndats_act FROM IBES.STATSUM_EPSUS', ...
        ' WHERE fpi IN (''1'',''2'',''3'')'];
getWRDSTable(WRDS, 'IBES', 'STATSUM_EPSUS', 'dirPath', [pwd,'\Inputs\WRDS\'], ...
                                            'customQuery', qry); 

% IBES STATSUM for analyst forecast revisions. EPS forecasts, International firms
qry = ['SELECT cusip, statpers, fpi, numest, numup, numdown, meanest, medest, fpedats, anndats_act FROM IBES.STATSUM_EPSINT', ...
        ' WHERE fpi IN (''1'',''2'',''3'')'];
getWRDSTable(WRDS, 'IBES', 'STATSUM_EPSINT', 'dirPath', [pwd,'\Inputs\WRDS\'], ...
                                             'customQuery', qry); 

% Download the Ravenpack datasets - separate queries/files for each year
for i=2004:2020
    % Define the query
    sqlQuery = ['SELECT * FROM RPNA.PR_EQUITIES_',char(num2str(i)), ... 
                ' WHERE RELEVANCE = 100 AND ENS = 100 AND NEWS_TYPE = ''PRESS-RELEASE'' AND ENTITY_TYPE=''COMP'' AND ISIN != '''''];
            
    % Download the current year (i)'s Ravenpack PR_EQUITIES file using the
    % custom SQL query from above
    getWRDSTable(WRDS, 'RPNA', ['PR_EQUITIES_',char(num2str(i))], 'dirPath', [pwd,'\Inputs\WRDS\Ravenpack\'], ...
                                                                  'customQuery',sqlQuery); 
end           

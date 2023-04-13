clear
clc

fprintf('Now working on creating the MPE index from Ozdagli and Velikov (2020). Run started at %s.\n\n\n', char(datetime('now')));

load me
load ATQ
load SALEQ
load COGSQ
load CHEQ
load SEQQ
load ret
load me
load dates
load permno
load NYSE
load FinFirms
load SIC

% Make the underlying variables (functions at the end of this script)
wwRank = makeWhitedWu();
durRank = makeImpldEqDur();
CFVol = makeCFVol();                                
cash = CHEQ./me;

mva = (ATQ - SEQQ + me);
mva(mva<=0) = nan;
opProf = (SALEQ - COGSQ) ./ lag(mva,3,nan);

% Winsorize 
wwRank  = winsorize(wwRank,  2.5);
cash    = winsorize(cash,    2.5);
durRank = winsorize(durRank, 2.5);
CFVol   = winsorize(CFVol,   2.5);
opProf  = winsorize(opProf,  2.5);

% Exclude financials and regulated firms
wwRank(FinFirms == 1) = nan;
wwRank(SIC>=4900 & SIC<5000) = nan;

% Create the index
mpe = -1.60 * wwRank + ...
      -0.87 * cash + ...
       0.63 * durRank + ...
       4.36 * CFVol + ...
      -5.74 * opProf;

% Sort - should come close to Ozdagli and Velikov (2020), Table 3
ind = makeUnivSortInd(-mpe, 5, NYSE);
res = runUnivSort(ret, ind, dates, me, 'plotFigure', 0);

% Export it. Start with a few constants 
nMonths = length(dates);
nStocks = length(permno);
nObs = nMonths * nStocks;
rptdPermno = repmat(permno', nMonths, 1);
rptdDates = repmat(dates, 1, nStocks);

% Create the table we'll use to export
data = array2table([reshape(rptdPermno, nObs, 1) ...
                    reshape(rptdDates, nObs, 1) ...
                    reshape(-mpe, nObs, 1)], ...
                    'VariableNames', {'permno','dates','MPE'});

% Drop the missing MPE observations & sort
indToDrop = isnan(data.MPE) | data.dates < 197501;
data(indToDrop, :) = [];
data = sortrows(data, {'permno','dates'}, 'ascend');

% Export
writetable(data, 'Data\mpe.csv');

%% Auxiliary functions below

function wwRank = makeWhitedWu()

    % Load the data
    load ATQ
    load SALEQ
    load IBQ
    load DLTTQ
    load SIC
    load DVC
    load DPQ
    load DVP
    load dates
    load permno
    load FQTR
    load RDQ

    % Drop the repeating RDQ and FQTR observations
    indToDrop = (RDQ - lag(RDQ, 1, nan)) == 0;
    RDQ(indToDrop)=nan;
    FQTR(indToDrop)=nan;

    % We divide/take logs of these two
    ATQ(ATQ<=0) = nan;
    SALEQ(SALEQ<=0) = nan;

    % We are using annual dividends as there is no quarterly DVCQ
    dividends = FillMonths(DVC + DVP);
    posDiv = 1 * (dividends > 0);
    posDiv(~isfinite(ATQ)) = nan;

    % Prepare some variables
    cashFlow = (IBQ + DPQ)./ATQ;
    totalDebt = DLTTQ./ATQ;
    logAssets = log(ATQ);

    SIC(SIC==0) = nan;
    SIC = floor(SIC/10);
    RDQ = floor(RDQ/100);

    % Reshape & create a table
    nStocks = size(ATQ, 2);
    nMonths = size(ATQ, 1);
    nObs = nStocks * nMonths;
    rptdPermno = repmat(permno', nMonths, 1);
    data = [reshape(FQTR,  nObs, 1) ...
            reshape(rptdPermno, nObs, 1) ...
            reshape(RDQ,        nObs, 1) ...
            reshape(cashFlow,   nObs, 1) ... 
            reshape(posDiv,     nObs, 1) ...
            reshape(totalDebt,  nObs, 1) ...
            reshape(logAssets,  nObs, 1) ...
            reshape(SIC,        nObs, 1) ...
            reshape(SALEQ,      nObs, 1)];
    indToDrop = isnan(data(:,1));
    data(indToDrop, :) = [];

    % Make the table now
    data = array2table(data);
    data.Properties.VariableNames = {'FQTR','permno','RDQ','cashFlow','posDiv', ...
                                     'totalDebt','logAssets','SIC','SALEQ'};

    % Create the YYYYQQ variable
    data.FQTR = datetime(data.FQTR, 'ConvertFrom', 'YYYYmmDD');
    data.month = month(data.FQTR);
    data.qtr = floor((data.month-1)/3) + 1;
    data.yyyyqq = year(data.FQTR)*100 + data.qtr;

    % Calculate industry sales for the industry sales growth variable
    dataInd = varfun(@(x) sum(x, 'omitnan'), data(:, {'SIC','yyyyqq','SALEQ'}), ...
                                        'GroupingVariables', {'SIC','yyyyqq'}, ...
                                        'InputVariables',{'SALEQ'});
    dataInd.GroupCount = [];
    dataInd.Properties.VariableNames={'SIC','yyyyqq','indSales'};

    % Merge the industry data back to the stock-level data
    data = outerjoin(data, dataInd, 'Type', 'Left', ...
                                    'MergeKeys', 1);

    % Prepare the variables for which we want to take lags
    dataToMerge = data(:, {'permno','SALEQ','indSales','FQTR'});
    dataToMerge.Properties.VariableNames = {'permno','lagSALEQ','lagIndSale','lagFQTR'};

    dataLag = outerjoin(data, dataToMerge, 'Keys', 'permno');
    indToDrop = calmonths(between(dataLag.FQTR, dataLag.lagFQTR)) ~= -3;
    dataLag(indToDrop, :) = [];
    dataLag = dataLag(:,{'permno_data','FQTR','lagFQTR','lagSALEQ','lagIndSale'});
    dataLag.Properties.VariableNames={'permno','FQTR','lagFQTR','lagSALEQ','lagIndSale'};

    % Attach the lags
    data = outerjoin(data, dataLag, 'Type', 'Left', ...
                                    'MergeKeys', 1, ...
                                    'RightVariables', {'lagSALEQ','lagIndSale'});
    
    % Create the sales and industry sales growth variables
    data.salesGrowth = data.SALEQ./data.lagSALEQ - 1;
    data.indSalesGrowth = data.indSales./data.lagIndSale - 1;

    data = data(:,{'permno','RDQ','cashFlow','posDiv','totalDebt', ...
                    'logAssets','indSalesGrowth','salesGrowth'});

    data.WW = -0.091 * data.cashFlow + ... 
              -0.062 * data.posDiv + ... 
               0.021 * data.totalDebt + ... 
              -0.044 * data.logAssets + ... 
               0.102 * data.indSalesGrowth + ... 
              -0.035 * data.salesGrowth;

    data = sortrows(data, {'permno','RDQ'}, 'ascend');
    data = varfun(@(x) x(end,:), data, 'GroupingVariables', {'permno','RDQ'});
    data.GroupCount = [];    
    data.Properties.VariableNames = regexprep(data.Properties.VariableNames, 'Fun_','');

    % Load a few variables
    load permno
    load dates
    load ret

    % Store a few constants
    nStocks = length(permno);
    nMonths = length(dates);
    nObs = nStocks * nMonths;

    % Create the linking table with CRSP
    rptdDates = repmat(dates, 1, nStocks);
    rptdPermno = repmat(permno', nMonths, 1);
    crspMatLink = [reshape(rptdPermno, nObs, 1) ...
                   reshape(rptdDates, nObs, 1)];
    crspMatLinkTab = array2table(crspMatLink, 'VariableNames', {'permno', 'dates'});           


    mergedTab = outerjoin(crspMatLinkTab, data, 'Type', 'Left', ...
                                                'LeftKeys', {'permno','dates'}, ...
                                                'RightKeys',{'permno','RDQ'}, ...
                                                'RightVariables', 'WW', ...
                                                'MergeKeys', 1);

    % Unstack the table and turn it into a matrix
    thisVar = unstack(mergedTab, 'WW', 'dates_RDQ');
    thisVar.permno = [];
    WhitedWu = table2array(thisVar)';
    
    % Fill in the missing months if any
    WhitedWu = FillMonths(WhitedWu);
    WhitedWu(isnan(ATQ)) = nan;

    % Create its rank and standardize to [0, 1] by dividing by the max rank
    wwRank = tiedrank(WhitedWu')';
    maxRank = max(wwRank, [], 2, 'omitnan');
    rptdMaxRank = repmat(maxRank, 1, nStocks);
    wwRank = wwRank./rptdMaxRank;           

end

function durRank = makeImpldEqDur()

    % Load the variables
    load sale
    load ib
    load be
    load me
    
    nStocks = size(me, 2);
    

    lSale = lag(SALE, 12, nan);
    sg = (SALE - lSale) ./ lSale;

    mu_g = 0.06*(1-.24);

    g = struct;
    g(1).sg = sg;
    for i = 2:11
        g(i).sg = g(i-1).sg*.24+mu_g;
    end

    roe = IB./lag(BE,12,nan);

    mu_roe = 0.12*(1-.57);

    rStruct = struct;
    rStruct(1).roe = roe;

    for i = 2:11
        rStruct(i).roe = rStruct(i-1).roe*.57+mu_roe;
    %     chec=[chec rStruct(i).roe(r,c)];
    end

    % BE(r,c)
    beStruct = struct;
    beStruct(1).be = BE;

    for i = 2:11
        beStruct(i).be = beStruct(i-1).be.*(1+g(i).sg);
    end

    earningsStruct = struct;
    earningsStruct(1).e = nan(size(me));

    for i=2:11
        earningsStruct(i).e=rStruct(i).roe.*beStruct(i-1).be;
    %     chec=[chec earningsStruct(i).e(r,c)];
    end

    pvcfStruct=struct;
    pvcfStruct(1).pvcf=nan(size(me));

    for i=2:11
        pvcfStruct(i).pvcf=(beStruct(i-1).be+earningsStruct(i).e-beStruct(i).be)/(1.12)^(i-1);
    %     chec=[chec pvcfStruct(i).pvcf(r,c)];
    end

    tpvcfStruct=struct;
    tpvcfStruct(1).pvcf=nan(size(me));

    for i=2:11
        tpvcfStruct(i).pvcf=(i-1)*(beStruct(i-1).be+earningsStruct(i).e-beStruct(i).be)/(1.12)^(i-1);
    %     chec=[chec tpvcfStruct(i).pvcf(r,c)];
    end

    sum_pvcf=pvcfStruct(2).pvcf;
    for i=3:11
        sum_pvcf=sum_pvcf+pvcfStruct(i).pvcf;
    end

    sum_tpvcf=tpvcfStruct(2).pvcf;
    for i=3:11
        sum_tpvcf=sum_tpvcf+tpvcfStruct(i).pvcf;
    end

    % sum_pvcf(r,c)
    % sum_tpvcf(r,c)

    terminal_cf=me-sum_pvcf;
    % terminal_cf(r,c)
    terminal_duration=10+1.12/.12;
    terminal_duration_weight=(me-sum_pvcf)./me;
    % terminal_duration_weight(r,c)

    impldEqDur=(sum_tpvcf./sum_pvcf).*(1-terminal_duration_weight)+terminal_duration_weight*terminal_duration;

    impldEqDur = FillMonths(impldEqDur);
    durRank = tiedrank(impldEqDur')';
    maxRank = max(durRank, [], 2, 'omitnan');
    rptdMaxRank = repmat(maxRank, 1, nStocks);
    durRank = durRank./rptdMaxRank;
    
    
end



function CFVol = makeCFVol()

    load SALEQ
    load COGSQ
    load XSGAQ
    load WCAPQ
    load ATQ
    load dates
    load permno
    load FQTR
    load RDQ

    indToDrop = (RDQ - lag(RDQ, 1, nan)) == 0;
    RDQ(indToDrop)=nan;
    FQTR(indToDrop)=nan;

    XSGAQ(isnan(XSGAQ) & isfinite(ATQ))=0;

    % Reshape & create a table
    nStocks = size(ATQ, 2);
    nMonths = size(ATQ, 1);
    nObs = nStocks * nMonths;
    rptdPermno = repmat(permno', nMonths, 1);
    data = [reshape(FQTR,       nObs, 1) ...
            reshape(rptdPermno, nObs, 1) ...
            reshape(RDQ,        nObs, 1) ...
            reshape(SALEQ,      nObs, 1) ... 
            reshape(COGSQ,      nObs, 1) ...
            reshape(XSGAQ,      nObs, 1) ...
            reshape(WCAPQ,      nObs, 1) ...
            reshape(ATQ,        nObs, 1)];
    indToDrop = isnan(data(:,1));
    data(indToDrop, :) = [];

    % Make the table now
    data = array2table(data);
    data.Properties.VariableNames = {'FQTR','permno','RDQ','SALEQ','COGSQ','XSGAQ','WCAPQ','ATQ'};
    data.FQTR = datetime(data.FQTR, 'ConvertFrom', 'YYYYmmDD');

    % Prepare the variables for which we want to take lags
    dataToMerge = data(:, {'permno', 'WCAPQ', 'FQTR'});
    dataToMerge.Properties.VariableNames = {'permno','lagWCAPQ','lagFQTR'};

    dataLag = outerjoin(data, dataToMerge, 'Keys', 'permno');
    indToDrop = calmonths(between(dataLag.FQTR, dataLag.lagFQTR))~=-3;
    dataLag(indToDrop, :) = [];
    dataLag = dataLag(:,{'permno_data','FQTR','lagFQTR','lagWCAPQ'});
    dataLag.Properties.VariableNames={'permno','FQTR','lagFQTR','lagWCAPQ'};

    % Attach the lags
    data = outerjoin(data, dataLag, 'Type', 'Left', ...
                                    'MergeKeys', 1, ...
                                    'RightVariables', {'lagWCAPQ'});



    data.WCPAQCH = data.WCAPQ - data.lagWCAPQ;
    data.OCF = (data.SALEQ - data.COGSQ - data.XSGAQ - data.WCPAQCH) ./ data.ATQ;
    data.RDQ = floor(data.RDQ/100);

    data = data(:,{'permno','RDQ','OCF'});

    data = sortrows(data, {'permno','RDQ'}, 'ascend');
    data = varfun(@(x) x(end,:), data, 'GroupingVariables',{'permno','RDQ'});
    data.GroupCount = [];    
    data.Properties.VariableNames = regexprep(data.Properties.VariableNames, 'Fun_','');

    % Load a few variables
    load permno
    load dates
    load ret

    % Store a few constants
    nStocks = length(permno);
    nMonths = length(dates);
    nObs = nStocks * nMonths;

    % Create the linking table with CRSP
    rptdDates = repmat(dates, 1, nStocks);
    rptdPermno = repmat(permno', nMonths, 1);
    crspMatLink = [reshape(rptdPermno, nObs, 1) ...
                   reshape(rptdDates, nObs, 1)];
    crspMatLinkTab = array2table(crspMatLink, 'VariableNames', {'permno', 'dates'});           


    mergedTab = outerjoin(crspMatLinkTab, data, 'Type', 'Left', ...
                                                'LeftKeys', {'permno','dates'}, ...
                                                'RightKeys',{'permno','RDQ'}, ...
                                                'RightVariables', 'OCF', ...
                                                'MergeKeys', 1);

    % Unstack the table and turn it into a matrix
    thisVar = unstack(mergedTab, 'OCF', 'dates_RDQ');
    thisVar.permno = [];
    OCF = table2array(thisVar)';

    OCF(isnan(RDQ))=nan;

    CFVol = nan(size(ATQ));
    rollingWindow = 60;
    startMonth = max(find(dates>=197501, 1, 'first'), rollingWindow);

    for i = startMonth:nMonths
        rollWindOcf = OCF(i-rollingWindow+1:i, :);
        numFiniteOcf = sum(isfinite(rollWindOcf), 1);    
        numFinitelastQtr = sum(isfinite(OCF(i-3:i, :)),1);

        ind = (numFiniteOcf >= 8) & (numFinitelastQtr >= 1);

        tempVol = std(rollWindOcf(:, ind), [], 1, 'omitnan');
        CFVol(i,ind) = tempVol;         
    end

    CFVol = FillMonths(CFVol);
    CFVol(isnan(ATQ)) = nan;
end
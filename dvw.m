
clear
clc

% Start with the default path
restoredefaultpath; 

% Path to the MATLAB asset pricing package
matlabPackagePath = 'D:\Published Repos\Dambra-Velikov-Weber\'; 

% Path to the code for the paper
paperCodePath = 'D:\Published Repos\Dambra-Velikov-Weber\Dambra-Velikov-Weber'; 

% Path to the folder with inputs that should contain 
inputsPath = 'D:\Published Repos\Dambra-Velikov-Weber\Dambra-Velikov-Weber\Inputs\'; 

% Add the relevant folders (with subfolders) to the path
addpath(genpath([matlabPackagePath, 'Data']))
addpath(genpath([matlabPackagePath, 'Functions']))
addpath(genpath([matlabPackagePath, 'Library Update']))
addpath(genpath([paperCodePath]))
addpath(genpath([inputsPath]))

% Navigate to the paper folder
cd(paperCodePath)

%% Add the directories

% Check if the /Data/ directory exists
if ~exist([pwd,'Data'], 'dir')
    mkdir(['Data'])
end

% Make sure we add those to the path if we created them
addpath(genpath(pwd));

%% Start a log file

warning('off','all');
startLogFile([paperCodePath], 'dvw_ms')

%% Download the data from WRDS

run('download_wrds_data.m');

%% Make the institutional ownership data

run('make_mpe.m');

%% Make the institutional ownership data

run('make_io_data.m');

%% Make ERP data

run('make_erp_data.m');

%% Make CIK/CUSIP link table

run('make_cik_cusip_link.m');

%% Make FOMC surprises

run('make_fomc_surprises.m');

%% Make CCM data

run('make_ccm_data.m');

%% Make SDC data (M&A, Loans, and Bond issuance)

run('make_sdc_data.m');

%% Make 8-K data from SEC analytics

run('make_8k_data.m');

%% Make press release data from Ravenpack

run('make_ravenpack_data.m');

%% Make the 8-k/press release merged data

run('make_8k_ravenpack_merge.m');

%% Make IBES Earnings guidance/Management forecast data

run('make_ibes_guidance_data.m');

%% Make IBES analyst forecast data

run('make_ibes_analyst_forecast_data.m');

%% Make IBES number of recommendations data

run('make_ibes_num_rec.m');

%% Merge data

run('merge_data.m');

%% End the log file

diary('off');


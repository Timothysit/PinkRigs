function []=initialise_kilosort()
%% deal with paths
addpath(genpath('C:\Users\Experiment\Documents\GitHub\PinkRigs')) % path to kilosort folder

addpath(genpath('C:\Users\Experiment\Documents\GitHub\Kilosort-2.0')) % path to kilosort folder
addpath(genpath('C:\Users\Experiment\Documents\GitHub\npy-matlab')) % for converting to Phy

csvRoot='\\zserver.cortexlab.net\Code\AVrig\'; % folder in which queue csv resides
pathToKSConfigFile = 'C:\Users\Experiment\Documents\Github\AV_passive\preprocessing\configFiles_kilosort2'; 
kilosortworkfolder='C:\Users\Experiment\Documents\KSworkfolder'; % local folder on ssd where I process the data for whitening (rootH) 
kilosortoutputfolder='C:\Users\Experiment\Documents\kilosort'; % local temporal folder for output (rootZ)
defaultP3Bchanmap='C:\Users\Experiment\Documents\Github\AV_passive\preprocessing\configFiles_kilosort2\neuropixPhase3B2_kilosortChanMap.mat';

%% the rest 
% check which days from the mice's folder contain ephys data
if ~exist(kilosortworkfolder, 'dir')
   mkdir(kilosortworkfolder)
end


% check active mice
csvLocation = [csvRoot 'kilosort_queue.csv'];
csvData = readtable(csvLocation,'Delimiter',',');
activeSortQueue=csvData.ephysName(csvData.sortedTag==0);
idx=find(csvData.sortedTag==0);

% loop over recordings to be sorted 
for recidx=1:numel(activeSortQueue)
% identify parent folder where we will push the output
    myAPdata=[activeSortQueue{recidx}]; 
    [ephys_folder,b,c]=fileparts(myAPdata); myapbin=strcat(b,c);
    
    if ~exist(kilosortoutputfolder, 'dir')
       mkdir(kilosortoutputfolder)
    end
    % indentify meta file and create channel map
    meta=kilo.ReadMeta_GLX(myAPdata,ephys_folder); 
    if contains(meta.imDatPrb_type,'0')
    % phase 3B probe -- just load the default kilosort map
    channelmapdir=defaultP3Bchanmap;

    elseif contains(meta.imDatPrb_type,'2')
        % create channelmap (good for all phase2, even single shank) or copy P3B map?    
        fprintf('creating custom channelmap...') 
        [~]=kilo.create_channelmapMultishank(myAPdata,ephys_folder,0);        
        channelmapfile=dir([ephys_folder '\\**\\*_channelmap.mat*']);
        channelmapdir=[channelmapfile(1).folder '\' channelmapfile(1).name]; % channelmap for the probe - should be in the same folder
    end
    %%
    if ~exist([kilosortoutputfolder myapbin])==1
        disp('copying data to local SSD');          
        copyfile(myAPdata,kilosortoutputfolder);
        disp('copied data') 
    else 
        disp('data already copied');
    end

    try
        kilo.Kilosort2Matlab(kilosortoutputfolder,kilosortworkfolder,channelmapdir,pathToKSConfigFile)
        delete([kilosortoutputfolder '\' myapbin]); % delete .bin file from KS output
        movefile(kilosortoutputfolder,ephys_folder) % copy KS output back to server


        % extract sync pulse 
        probesortedfolder=[ephys_folder '\\kilosort'];
        d=dir([probesortedfolder '\**\sync.mat']);
        if numel(d)<1            
            kilo.syncFT(myAPdata, 385, probesortedfolder);
        else 
            disp('sync extracted already.');
        end

        % overwrite the queue
        csvData.sortedTag(recidx)=1; 
    catch 
        % sorting was not successful write a permanent tag indicating that
        csvData.sortedTag(recidx)=-1;
        errorMsge=jsonencode(lasterror);
        fid = fopen([ephys_folder '\KSerror.json'], 'w');
        fprintf(fid, '%s', errorMsge);
        fclose(fid);
    end
    % save the updated queue

    writetable(csvData,csvLocation,'Delimiter',',');
end
close all; 
end

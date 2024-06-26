function spk = getSpikeDataONE(KSFolder)
    %% Loads the ephys data from a KS folder.
    %
    % Parameters:
    % -------------------
    % KSFolder: str
    %   Path to kilosort folder
    %
    % Returns: 
    % -------------------
    % spk: struct
    %   Contains a condensed summary with spikes times & template info.
    %       Related to spikes:
    %           times: spike times
    %           templates: associated template 
    %           clusters: associated cluster
    %           amps: amplitude
    %           depths: depth
    %           av_xpos: x position
    %           av_shankIDs: shank ID
    %
    %       Related to templates:
    %           amps: amplitude
    %           waveforms: waveform
    %           waveformsChannels: associated channels
    %
    %       Related to clusters (that can be manually curated):
    %           av_IDs: IDs
    %           av_KSLabels: labels given by kilosort
    %           amps: amplitude
    %           waveforms: waveform
    %           waveformsChannels: associated channels
    %           depths: depth
    %           av_xpos: x position
    %           av_shankID: shank ID
    %           peakToTrough: peak to trough time
    %           channels: which channel the cluster had its peak amp on

    %% Parameters

    % so that one can give this a custom folder
    if ~exist('KSFolder','var')
        KSFolder = fullfile(ephysPath,'pyKS','output');
    end
    IBLFormatFolder = fullfile(KSFolder,'ibl_format');

    %% Get spike info
    
    % Load spike times
    spikeTimes = readNPY(fullfile(IBLFormatFolder,'spikes.times.npy'));

    % Load spike templates
    spikeTemplates = readNPY(fullfile(IBLFormatFolder,'spikes.templates.npy'));

    % Load spike clusters--same as templates if no manual curation
    spikeClusters = readNPY(fullfile(IBLFormatFolder,'spikes.clusters.npy'));
    
    % Load spike amplitudes
    spikeAmps = readNPY(fullfile(IBLFormatFolder,'spikes.amps.npy'));

    % Load coords
    coords = readNPY(fullfile(KSFolder, 'channel_positions.npy'));
    ycoords = coords(:,2); xcoords = coords(:,1);

    % Load spike depth
    spikeDepths = readNPY(fullfile(IBLFormatFolder,'spikes.depths.npy'));

%     % Load pc features
%     pcFeat = readNPY(fullfile(KSFolder,'pc_features.npy')); % nSpikes x nFeatures x nLocalChannels
% 	pcFeatInd = readNPY(fullfile(KSFolder,'pc_feature_ind.npy')); % nTemplates x nLocalChannels
% 
%     % Compute depths
%     pcFeat = squeeze(pcFeat(:,1,:)); % take first PC only
%     pcFeat(pcFeat<0) = 0; % some entries are negative, but we don't really want to push the CoM away from there.
%     
%     % which channels for each spike?
%     spikeFeatInd = pcFeatInd(spikeTemplates+1,:);
%     % ycoords of those channels?
%     spikeFeatYcoords = ycoords(spikeFeatInd+1); % 2D matrix of size #spikes x 12
%     % center of mass is sum(coords.*features)/sum(features)
%     spikeDepths = sum(spikeFeatYcoords.*pcFeat.^2,2)./sum(pcFeat.^2,2);   
% 
%     spikeFeatXcoords = xcoords(spikeFeatInd+1); % 2D matrix of size #spikes x 12
%     spikeXPos = sum(spikeFeatXcoords.*pcFeat.^2,2)./sum(pcFeat.^2,2);

    % New, faster to get spikeXPos
    temps = readNPY(fullfile(KSFolder, 'templates.npy'));
    winv = readNPY(fullfile(KSFolder, 'whitening_mat_inv.npy'));
    tempsUnW = zeros(size(temps));
    for t = 1:size(temps,1)
        tempsUnW(t,:,:) = squeeze(temps(t,:,:))*winv;
    end
    % The amplitude on each channel is the positive peak minus the negative
    tempChanAmps = squeeze(max(tempsUnW,[],2))-squeeze(min(tempsUnW,[],2));

    % The template amplitude is the amplitude of its largest channel (but see
    % below for true tempAmps)
    tempAmpsUnscaled = max(tempChanAmps,[],2);

    % need to zero-out the potentially-many low values on distant channels ...
    threshVals = tempAmpsUnscaled*0.3;
    tempChanAmps(bsxfun(@lt, tempChanAmps, threshVals)) = 0;

    % ... in order to compute the depth as a center of mass
    templateDepths = sum(bsxfun(@times,tempChanAmps,ycoords'),2)./sum(tempChanAmps,2);

    % Compute xpos as center of mass
    templateXPos = sum(bsxfun(@times,tempChanAmps,xcoords'),2)./sum(tempChanAmps,2);

    % spikeDepths = templateDepths(spikeTemplates+1);
    spikeXPos = templateXPos(spikeTemplates+1);

    % Get spike shank IDs
    [~,spikeShankIDs] = min(abs(spikeXPos - repmat([0 200 400 600], [numel(spikeXPos),1])),[],2);
    spikeShankIDs = uint8(spikeShankIDs-1);

    %% Get template info
    
    % Load template info
    tempWav = readNPY(fullfile(IBLFormatFolder,'templates.waveforms.npy'));
    tempWavChan = readNPY(fullfile(IBLFormatFolder,'templates.waveformsChannels.npy'));
    tempWavChan = single(tempWavChan);
    tempAmps = readNPY(fullfile(IBLFormatFolder,'templates.amps.npy'));
    
    %% Get cluster info after manual curation too (phy)
  
    % Load the cluster ID and labels
    if exist(fullfile(KSFolder, 'cluster_info.tsv'),'file') 
       cgsFile = fullfile(KSFolder, 'cluster_info.tsv');
       [cids, cgs] = readClusterGroupsCSV_AV(cgsFile,1);
    elseif exist(fullfile(KSFolder, 'cluster_KSLabel.tsv'),'file') 
       cgsFile = fullfile(KSFolder, 'cluster_KSLabel.tsv');
       [cids, cgs] = readClusterGroupsCSV_AV(cgsFile,0);
    end 

    clusKSLabels = zeros(1,numel(cids),'uint8');
    clusXpos = zeros(1,numel(cids),'single');
    clusDepths = zeros(1,numel(cids),'single');
    clusShankIDs = zeros(1,numel(cids),'uint8');
    for ii = 1:numel(cids)
        temp = cids(ii);
        spkIdx = spikeClusters == temp;
        clusKSLabels(ii) = cgs(cids == temp);
        clusXpos(ii) = nanmedian(spikeXPos(spkIdx)); % not sure why there can be nans here
        clusDepths(ii) = nanmedian(spikeDepths(spkIdx));
        clusShankIDs(ii) = nanmedian(spikeShankIDs(spkIdx));
    end

    % Some metrics from the IBL format
    clusWav = readNPY(fullfile(IBLFormatFolder,'clusters.waveforms.npy'));
    % clusWavChan = readNPY(fullfile(IBLFormatFolder,'clusters.waveformsChannels.npy'));
    clusWavChan = single(tempWavChan);
    clusAmps = readNPY(fullfile(IBLFormatFolder,'clusters.amps.npy'));
    clusPeakToTrough = readNPY(fullfile(IBLFormatFolder,'clusters.peakToTrough.npy'));
    clusChannel = readNPY(fullfile(IBLFormatFolder,'clusters.channels.npy'));
        
    % The ibl format clusters and the curated KS clusters don't match
    % so if they don't match we need to get rid of clusters to keep
    % dimensions consistent
    if numel(cids)~=numel(clusAmps)
        disp('curated dataset? cluster dims not match with IBL...')
        disp('matching...')
        % cids indexing is python based so adding 1 
        clusWav = clusWav(cids+1,:,:);
        clusWavChan = clusWavChan(cids+1,:);
        clusAmps = clusAmps(cids+1);
        clusPeakToTrough = clusPeakToTrough(cids+1);  
        clusChannel = clusChannel(cids+1); 
    end


    %% Save it in spk
    
    % spikes
    spk.spikes.times = spikeTimes;
    spk.spikes.templates = spikeTemplates;
    spk.spikes.clusters = spikeClusters;
    spk.spikes.amps = spikeAmps;
    spk.spikes.depths = spikeDepths;
    spk.spikes.av_xpos = spikeXPos;
    spk.spikes.av_shankIDs = spikeShankIDs; 
    
    % templates
    spk.templates.amps = tempAmps;
    spk.templates.waveforms = tempWav; % maybe to remove/redundant with qMetrics?
    spk.templates.waveformsChannels = tempWavChan; % maybe to remove/redundant with qMetrics?
    
    % clusters (that can be manually curated)
    spk.clusters.av_IDs = cids';
    spk.clusters.av_KSLabels = clusKSLabels';
    spk.clusters.amps = clusAmps;
    spk.clusters.waveforms = clusWav; % maybe to remove/redundant with qMetrics?
    spk.clusters.waveformsChannels = clusWavChan; % maybe to remove/redundant with qMetrics?
    spk.clusters.depths = clusDepths';
    spk.clusters.av_xpos = clusXpos';
    spk.clusters.av_shankID = clusShankIDs';
    spk.clusters.peakToTrough = clusPeakToTrough;
    spk.clusters.channels = clusChannel; 

end
    
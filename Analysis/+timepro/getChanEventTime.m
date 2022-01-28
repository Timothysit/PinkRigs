function evTimes = getChanEventTime(timeline,chanName)
    %%% This function will extract event times depending on the chan. 
    
    %% Extract channel
    chan = timepro.extractChan(timeline,chanName);
    timelineTime = timepro.extractChan(timeline,'time');
        
    %% Extract events
    if ~isempty(chan)
        switch chanName
            case 'photoDiode'
                % Uses k-means here to get thresholds. 
                % Different form the shmitt times I used to use; also takes much longer!
                % pdT = schmittTimes(timelineTime,chan, [2.5 3]);
                
                [~, thresh] = kmeans(chan,5);
                thresh = [min(thresh) + range(thresh)*0.2;  max(thresh) - range(thresh)*0.2];
                
                % Find flips based on these thresholds.
                photoDiodeFlipOn = sort([strfind(chan'>thresh(1), [0 1]), strfind(chan'>thresh(2), [0 1])]);
                photoDiodeFlipOff = sort([strfind(chan'<thresh(1), [0 1]), strfind(chan'<thresh(2), [0 1])]);
                photoDiodeFlips = sort([photoDiodeFlipOn photoDiodeFlipOff]);
                
                % Remove cases where two flips in the same direction appear in succession (you can't flip to white twice in a row)
                photoDiodeFlips([strfind(ismember(photoDiodeFlips, photoDiodeFlipOn), [1 1])+1 strfind(ismember(photoDiodeFlips, photoDiodeFlipOff), [1 1])+1]) = [];
                
                % Get corresponding flip times. Remove any that would be faster than 60Hz (screen refresh rate)
                evTimes = timelineTime(photoDiodeFlips)'; % in timeline time
                evTimes(find(diff(evTimes)<(12/1000))+1) = [];
                
            case 'audioOut'
                % Get audio Onsets
                
            case 'camSync'
                % Get cam Sync events (onset of dark flash)
                tlSyncThresh = [2 3]; % these seem to work well
                [~, ~, evTimes] = schmittTimes(1:numel(tlSync), tlSync, tlSyncThresh);
                evTimes = timelineTime(evTimes); % in timeline time
                
            case {'faceCamStrobe','eyeCamStrobe','sideCamStrobe'}
                % Get cam strobe events
                tlStrobeThresh = [1 2];
                [~,evTimes,~] = schmittTimes(1:numel(tlStrobe), tlStrobe, tlStrobeThresh);
                evTimes = timelineTime(evTimes); % in timeline time
                
            case 'rewardEcho'
                % Get reward events
                thresh = max(chan)/2;
                rewardTrace = chan > thresh;
                evTimes = strfind(rewardTrace', [0 1])+1;
                evTimes = timelineTime(evTimes); % in timeline time
        end
        
    else
        % Channel couldn't be found. Warning already sent. 
        evTimes = [];
    end

    
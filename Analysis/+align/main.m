function main(params,varargin)
    %%% This function will run the main alignment code, and save the
    %%% results in the expPath folder.
    
    %% Get missing parameters and list of mice to check
    if isfield(params, 'recompute')
        params.recompute = {'none'};
    end
    
    if nargin > 1
        mouse2checkList = varargin{1};
    else
        % Get mouse list from main csv
        mainCSVLoc = getCSVLocation('main');
        mouseList = readtable(mainCSVLoc);
        mouse2checkList = mouseList.Subject;
    end
    
    %% Check which experiments aren't aligned
    for m = 1:numel(mouse2checkList)
        % Loop through subjects
        subject = mouse2checkList{m};
        
        % Get list of exp for this mouse
        expList = getMouseExpList(subject);
        
        for e = 1:numel(expList)
            % Loop through csv to look for experiments that weren't
            % aligned, or all if params.recompute isn't none.
            % Can also amend the csv to say whether this one has been
            % aligned or not.
            
            % Get exp info
            expInfo = expList(e,:);
            expPath = expInfo.path{1};
            
            %% --------------------------------------------------------
            %% Will first compute or fetch the 'alignment' file. 
            
            %% Get the path of the alignment file and fetch it if exists
            % Define savepath for the alignment results
            savePath = fullfile(expPath,'alignment.mat');
            
            % Load it if exists
            if exist(savePath,'file')
                load(savePath,'alignment');
            else
                alignmentOld = struct();
            end
            
            % monitors if anything has changed
            change = 0;
            
            %% Align spike times to timeline and save results in experiment folder
            %  This function will load the timeline flipper from the experiment and
            %  check this against all ephys files recorded on the same date. If it
            %  locates a matching section of ephys data, it will save the reference
            %  flipper times for both the ephys and the timeline.
            %  It will output two time series, and one can use these time series to
            %  compute the events times in timeline time from times in block time using
            %  "event2timeline".

            %%% Maybe update csv's 'ephys'?    
            
            if contains(params.recompute,'all') || contains(params.recompute,'ephys') || ~isfield(alignmentOld,'ephys')
                if expInfo.ephys
                    % Align it
                    [ephysFlipperTimes, timelineFlipperTimes, ephysPath] = align.ephys_AVrigs(expPath);
                    
                    % Save it
                    for p = 1:numel(ephysPath)
                        alignment.ephys(p).originTimes = ephysFlipperTimes{p};
                        alignment.ephys(p).timelineTimes = timelineFlipperTimes{p};
                        alignment.ephys(p).ephysPath = ephysPath{p}; % can have several probes
                    end
                else
                    alignment.ephys = [];
                end
                change = 1;
            else
                % Just load it
                alignment.ephys = alignmentOld.ephys;
            end
            
            %% Align the block timings to timeline
            %  This function will load the timeline and block for that experiment and
            %  align one with another using 1) the wheel or 2) the photodiode.
            %  It will output two time series, and one can use these time series to
            %  compute the events times in timeline time from times in block time using
            %  "event2timeline".
            
            if contains(params.recompute,'all') || contains(params.recompute,'block') || ~isfield(alignmentOld,'block')
                [blockRefTimes, timelineRefTimes] = align.block_AVrigs(expPath);
                
                % save it
                alignment.block.originTimes = blockRefTimes;
                alignment.block.timelineTimes = timelineRefTimes;
                change = 1;
            else
                % Just load it
                alignment.block = alignmentOld.block;
            end
            
            %% Align the video frame times to timeline
            %  This function will align all cameras' frame times with the experiment's
            %  timeline.
            %  The resulting times for these alignments will be saved in a structure
            %  'vids' that contains all cameras.
            
            if contains(params.recompute,'all') || contains(params.recompute,'video') || ~isfield(alignmentOld,'video')
                % Define a few parameters (optional) -- should maybe live somewhere else?
                pVid.recomputeInt = false; % will recompute intensity file if true
                pVid.nFramesToLoad = 3000; % will start loading the first and 3000 of the movie
                pVid.adjustPercExpo = 1; % will adjust the timing of the first frame from its intensity
                pVid.plt = 1; % to plot the inter frame interval for sanity checks
                pVid.crashMissedFrames = 1; % will crash if any missed frame
                
                % Get cameras' names
                vids = dir(fullfile(expPath,'*Cam.mj2')); % there should be 3: side, front, eye
                
                % Align each of them
                for v = 1:numel(vids)
                    [~,vidName,~]=fileparts(vids(v).name);
                    try
                        [vids(v).frameTimes, vids(v).missedFrames] = align.video_AVrigs(expPath, vidName, pVid);
                    catch me
                        % case when it's corrupted
                        vids(v).frameTimes = [];
                        vids(v).missedFrames = [];
                        warning('Corrupted video %s: threw an error (%s)',vidName,me.message)
                    end
                end
                
                % save it
                alignment.video = vids;
                change = 1;
            else
                % Just load it
                alignment.video = alignmentOld.video;
            end
            
            %% Align microphone to timeline
            %  This function will take the output of the 192kHz microphone and align it
            %  to the low frequency microphone that records directly into the timeline
            %  channel. Saved as a 1Hz version of the envelope of both.
            
            if contains(params.recompute,'all') || contains(params.recompute,'mic') || ~isfield(alignmentOld,'mic')
                % Align it
                change = 1;
            else
                % Just load it
                alignment.mic = alignmentOld.mic;
            end
            
            %% Save the alignment structure
            
            if change
                save(savePath,'alignment')
            else
                % Could save over it anyway even if nothing has changed,
                % but I felt like keeping the date of last modifications of
                % the files might be useful (e.g., for debugging).
            end
            
            %% --------------------------------------------------------
            %% Will then compute and save the processed data.
            
            %% ephys
            % use align.event2timeline(spikeTimes,alignment.ephys(e).originTimes,alignment.ephys(e).timelineTimes)
            
            %% block events
            % use align.event2timeline(eventTimes,alignment.block.originTimes,alignment.block.timelineTimes)
            
        end
    end
    

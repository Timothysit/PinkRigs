function plotIMROProtocol(basePath,savePlt)
    if ~exist('savePlt','var')
        savePlt = 0;
    end
    
    probeColor = [0.4 0.6 0.2; ...
                    0.9 0.3 0.0];
    
    days = dir(basePath);
    days(~[days.isdir]) = [];
    days(ismember({days.name},{'.','..'})) = [];
    f = figure('Position',[1 30 1920 970]);
    for d = 1:numel(days)
        protocols = dir(fullfile(days(d).folder,days(d).name)); protocols(ismember({protocols.name},{'.','..'})) = [];
        for p = 1:numel(protocols)
            subplot(numel(days),numel(protocols),(d-1)*numel(protocols)+p); hold all
            IMROfiles = dir(fullfile(protocols(p).folder,protocols(p).name,'**','*.imro'));
            for probeNum = 1:numel(IMROfiles)
                %% read data
                IMROfileName = fullfile(IMROfiles(probeNum).folder,IMROfiles(probeNum).name);
                [fid,msg] = fopen(IMROfileName,'rt');
                assert(fid>=3,msg) % ensure the file opened correctly.
                out = fgetl(fid); % read and ignore the very first line.
                fclose(fid);
                out = regexp(out,'\(|\)(|\)','split'); 
                out(1:2) = []; % empty + extra channel or something?
                out(end) = []; % empty
                
                % Get channel properties
                chans = nan(1,numel(out));
                shank = nan(1,numel(out));
                bank = nan(1,numel(out));
                elecInd = nan(1,numel(out));
                for c = 1:numel(out)
                    chanProp = regexp(out{c},' ','split');
                    chans(c) = str2double(chanProp{1});
                    shank(c) = str2double(chanProp{2});
                    bank(c) = str2double(chanProp{3});
                    % 4 is refElec
                    elecInd(c) = str2double(chanProp{5});
                end
                
                %% plot data -- taken from IMRO generation script 
                % NP 2.0 MS (4 shank), probe type 24 electrode positions
                nElec = 1280;   %per shank; pattern repeats for the four shanks
                vSep = 15;      % in um
                hSep = 32;
                
                elecPos = zeros(nElec, 2);
                
                elecPos(1:2:end,1) = 0;                %sites 0,2,4...
                elecPos(2:2:end,1) =  hSep;            %sites 1,3,5...
                
                % fill in y values
                viHalf = (0:(nElec/2-1))';                %row numbers
                elecPos(1:2:end,2) = viHalf * vSep;       %sites 0,2,4...
                elecPos(2:2:end,2) = elecPos(1:2:end,2);  %sites 1,3,5...
                
                chanPos = elecPos(elecInd+1,:);
                
                % make a plot of all the electrode positions
                shankSep = 250;
                for sI = 0:3
                    cc = find(shank == sI);
                    scatter((probeNum-1)*8*shankSep + shankSep*sI + elecPos(:,1), elecPos(:,2), 10, probeColor(probeNum,:), 'square' );
                    scatter((probeNum-1)*8*shankSep + shankSep*sI + chanPos(cc,1), chanPos(cc,2), 20, [.4 .2 .6], 'square', 'filled' );
                end
                xlim([-16,(numel(IMROfiles)-1)*8*shankSep + numel(IMROfiles)*3*shankSep+64]);
                ylim([-10,10000]);
                text((probeNum-1)*8*shankSep + 0.5*shankSep+64,10000,sprintf('Probe %d', probeNum))
                title(sprintf('%s, Protocol %s',days(d).name,regexprep(protocols(p).name,'_',' ')));
            end
        end
    end
    
    if savePlt
        saveas(f,fullfile(basePath,'IMROWholeProtocol.png'),'png')
    end
end
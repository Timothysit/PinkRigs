clc; clear all;
extracted = loadOptoData('balanceTrials',0,'sepMice',0,'reExtract',1,'sepHemispheres',1,'sepPowers',1,'sepDiffPowers',1,'whichSet', 'bi_high'); 
% build the table for the LME 
%extracted = loadOptoData('balanceTrials',0,'sepMice',0,'reExtract',1,'sepHemispheres',0,'sepPowers',0,'sepDiffPowers',0,'whichSet', 'uni_all'); 

% need to contain - choice, visContrast (scaled) and raised to some sort of power, soundPos, scaled, session
%ID, mouseID, isLaserTrial. 
%%

ev = extracted.data{1,1}; 
% normalise the stims 
ev.origMax = [max(abs(ev.stim_visDiff)) max(abs(ev.stim_audDiff))];
ev.stim_visDiff = ev.stim_visDiff./max(ev.origMax(1),1e-15); % to avoid nans
ev.stim_audDiff = ev.stim_audDiff./max(ev.origMax(2),1e-15);

% fit the control data to obtain the average gamma
controlBlock = filterStructRows(ev, ~ev.is_laserTrial);
controlfit = plts.behaviour.GLMmulti(controlBlock, 'simpLogSplitVSplitA');
controlfit.fit;

%%


gamma = controlfit.prmFits(1,4); % empirical from the control trials after fitting the log-Odds. 

ev.vis_gamma_scaled = sign(ev.stim_visDiff).*(abs(ev.stim_visDiff)).^gamma; 
tbl = table; 
tbl.opto = double(ev.is_laserTrial);

tbl.choice = ev.response_direction-1; 
[~,~,tbl.mouse] = unique(ev.subjectID_); 
[~,~,tbl.session] = unique(ev.sessionID);
tbl.aud = ev.stim_audDiff; 
tbl.vis = ev.vis_gamma_scaled; 


%
model = fitglme(tbl,['choice ~ opto+aud+vis+aud*opto+vis*opto+ (1|mouse)+ (1|mouse:session) + ' ...
    '(-1+vis|mouse)  + (-1+vis|mouse:session)+ (-1+aud|mouse)  + (-1+aud|mouse:session) +' ...
    ' (-1+opto|mouse) + (-1+opto|mouse:session) '],'Distribution','Binomial','Link','logit');
%%

figure; 
bar(model.Coefficients.Estimate([1,2,3,5,4,6]))

labels = {'bias','bias_o','A','A_o','V','V_o'};
xticklabels(labels)
ylim([-1,3])
    
%%
% plot the data /mouse/session based on table
% maybe in a stype that each session is a subplot
% plot the prediction on top 

visPos = unique(tbl.vis); 
audPos = unique(tbl.aud);
opto = unique(tbl.opto); 


[visGrid,audGrid,optoGrid] = meshgrid(visPos,audPos,opto);
combinations = [visGrid(:),audGrid(:),optoGrid(:)];

mouseID =6; 



sessionIDs = unique(tbl.session(tbl.mouse==mouseID)); 

group_size = 5; 
num_groups = ceil(length(sessionIDs) / group_size);
groups = cell(1, num_groups);
for i = 1:num_groups
    start_index = (i - 1) * group_size + 1;
    end_index = min(i * group_size, length(sessionIDs));
    groups{i} = sessionIDs(start_index:end_index);
end

nSessions = numel(groups); 



figure; 

for s=1:nSessions
    sessionID = groups{s}; 
    isCurrSession  = (tbl.mouse==mouseID) & ismember(tbl.session,sessionID);
    nTrials(s) = sum(isCurrSession); 
    for c=1:size(combinations,1)
    
        isCurrentComb = ismember([tbl.vis,tbl.aud,tbl.opto],combinations(c,:),"rows");
        fracRightTurns(c) = mean(tbl.choice(isCurrentComb & isCurrSession)); 
    end 
    
    fracRightTurns = reshape(fracRightTurns,[numel(audPos),numel(visPos),numel(opto)]);
    
    
    
    curveType = 'log';
    % generate predictions for session in Q:
    nEval = 600; 
    evalpoints =  linspace(-1,1,nEval);
    [evalV,evalA,evalO] = meshgrid(evalpoints,audPos,opto);
    
    evaltbl = table; 
    for o=1:numel(opto)
        for a=1:numel(audPos)
            evaltbl.vis = evalV(a,:,o)'; 
            evaltbl.aud = evalA(a,:,o)';
            evaltbl.opto = evalO(a,:,o)';

            current_prediction=zeros(numel(sessionID),nEval);
            for currsess=1:numel(sessionID)
                evaltbl.session = ones(nEval,1) * sessionID(currsess); 
                evaltbl.mouse = ones(nEval,1) * mouseID; 
            
                current_prediction(currsess,:)  = predict(model,evaltbl);
            end 
            preds(a,:,o) = mean(current_prediction,1);
        end 
    end 
    
    % convert things to log if requested 
    if strcmp('log',curveType)
        preds = log10(preds./(1-preds));  % this is the logOdds -- 
        fracRightTurns = log10(fracRightTurns./(1-fracRightTurns)); 
        ylim( [-3,3])
    end 
    % plot the data and the predictions on top     
    
    subplot(1,nSessions,s)
    linestyles_pred = {'--';'-'};
    markers_pred = {'none';'none'}; 
    linestyles_dat = {'none';'none'}; 
    markers_dat = {'none';'.'};
    lineColors = plts.general.selectRedBlueColors(audPos);
    for oidx=1:numel(opto)
        plotOpt.lineStyle = linestyles_pred{oidx}; 
        plotOpt.Marker = markers_pred{oidx};
        plts.general.rowsOfGrid(evalV(1,:,oidx), preds(:,:,oidx), lineColors, plotOpt);
        hold on;
        plotOpt.lineStyle = linestyles_dat{oidx}; 
        plotOpt.Marker = markers_dat{oidx};
        plts.general.rowsOfGrid(visGrid(1,:,oidx), fracRightTurns(:,:,oidx), lineColors, plotOpt);
        hold on; 
    end
    if strcmp('log',curveType)
        ylim( [-3,3])
        hline(0,'k--')
        vline(0,'k--')

    end 
    title(sprintf('%.0f,n=%.0f',sessionID,nTrials(s)));
end
sgtitle(mouseID)

% more officially get a gamma for each session  -- does that make a
% difference

% get the fracRightturns grid
% get the prediciton

% 
% cidx = 1; 
% mouseIDs = unique(tbl.mouse); 
% mousetbl = tbl((tbl.mouse==mouseIDs(cidx)),:);
% 
% sessionIDs = unique(mousetbl.session); 
% nSessions = numel(sessionIDs); 
% 
% 
% 
%     
% figure; 
% subplots(1,nSessions,1); 




%%
% couple of things I tried in the past 
% fit the model 
% fullAV  = fitglme(tbl,'choice ~ opto+aud+vis+aud*opto+vis*opto+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');


% get the table and plot the data based on the table /mouse/sessio

%
% model2  = fitglme(tbl,'choice ~ opto+aud+vis+aud*opto+vis*opto+ (1|mouse)+ (1|mouse:session) + (-1+vis|mouse)  + (-1+vis|mouse:session)+ (-1+aud|mouse)  + (-1+aud|mouse:session)','Distribution','Binomial','Link','logit');
% %%
% model3 = fitglme(tbl,'choice ~ opto+aud+vis+aud*opto+vis*opto+ (1|mouse)+ (1|mouse:session) + (-1+vis|mouse)  + (-1+vis|mouse:session)+ (-1+aud|mouse)  + (-1+aud|mouse:session) + (-1+opto|mouse) + (-1+opto|mouse:session) ','Distribution','Binomial','Link','logit');
% 
% %%
% model4 = fitglme(tbl,'choice ~ opto+aud+vis+aud*opto+vis*opto+ (1|mouse)+ (1|mouse:session) + (-1+vis|mouse)  + (-1+vis|mouse:session)+ (-1+aud|mouse)  + (-1+aud|mouse:session) + (-1+opto|mouse) + (-1+opto|mouse:session)+(-1+opto*vis|mouse)  + (-1+opto*vis|mouse:session) +(-1+opto*aud|mouse)  + (-1+opto*aud|mouse:session) ','Distribution','Binomial','Link','logit');

% fullAdditive = fitglme(tbl,'choice ~ opto+aud+vis+aud*opto+vis*opto+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');
% noInteraction  = fitglme(tbl,'choice ~ opto+aud+vis+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');%
% noBias = fitglme(tbl,'choice ~ aud+vis+aud*opto+vis*opto+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');
% noVis = fitglme(tbl,'choice ~ opto+aud+vis+aud*opto+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');
% noAud = fitglme(tbl,'choice ~ opto+aud+vis+vis*opto+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');

%
% c = compare(fullAdditive,fullAV); 
% disp(c(2,8).pValue);
% %
% %%
% compare(glme,noaud);
% 
% %% 
% 
% figure; 
% plot([full.LogLikelihood,noBias.LogLikelihood,noAud.LogLikelihood,noVis.LogLikelihood,noInteraction.LogLikelihood]); 
% xticks([1,2,3,4,5])
% xticklabels({'full','noBias','noAudInteraction','noVisInteraction','noInteraction'})
% ylabel('-LogLikelihood')
% 
% %% 
% 
% ctrl =  table; 
% ctrl.choice = ev.response_direction(~ev.is_laserTrial)-1; 
% [~,~,ctrl.mouse] = unique(ev.subjectID_(~ev.is_laserTrial)); 
% [~,~,ctrl.session] = unique(ev.sessionID(~ev.is_laserTrial));
% ctrl.aud = ev.stim_audDiff(~ev.is_laserTrial); 
% ctrl.vis = ev.vis_gamma_scaled(~ev.is_laserTrial); 
% 
% AVinteraction = fitglme(ctrl,'choice ~ aud+vis+vis*aud+(vis|mouse)+(vis|mouse:session)+(aud|mouse)+(aud|mouse:session)+(1|mouse)+(1|mouse:session)','Distribution','Binomial','Link','logit');%
% 
% linear_1 = fitglme(ctrl,'choice ~ aud+vis+(1|mouse)+(1|mouse:session)','Distribution','Binomial','Link','logit');%
% 
% c = compare(linear,AVinteraction);
% disp(c(2,8).pValue);
% %%
% 
% full  = fitglme(tbl,'choice ~ opto+aud+vis+aud*vis+aud*opto+vis*opto+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');%
% noInteraction  = fitglme(tbl,'choice ~ opto+aud+vis+(vis|mouse)+(vis|session)+(vis|mouse:session)+(aud|mouse)+(aud|session)+(aud|mouse:session)+(opto|mouse)+(opto|session)+(opto|mouse:session)','Distribution','Binomial','Link','logit');%

%%
function [eventTimes, trialGroups, opt] = passive(ev)
if ~exist('customTag', 'var'); customTag = 'default'; end

switch lower(customTag)
    case 'default'
        %%
        opt = struct;

        eventTimes = {...
            ev.timeline_visPeriodOnOff(ev.is_visualTrial,1); ...
            ev.timeline_audPeriodOnOff(ev.is_auditoryTrial,1); ...
            ev.timeline_audPeriodOnOff(ev.is_coherentTrial,1); ...
            };

        opt.eventNames = {...
            'Vis'; ...
            'Aud'; ...
            'MS'; 

            };

        trialGroups = {...
            [sign(ev.stim_visAzimuth(ev.is_visualTrial))+2]; ...
            [sign(ev.stim_audAzimuth(ev.is_auditoryTrial))+2]; ...
            [sign(ev.stim_audAzimuth(ev.is_coherentTrial))+2]; ...
            };

        opt.groupNames = {...
            {'Azimuth'} ...
            {'Azimuth'} ...
            {'Azimuth'} ...
            };

        
        %         opt.groupNames = {...
%             {{'visL'; 'visR'}, choiceNames, trialNames} ...
%             {{'audL'; 'aud0'; 'audR'}, choiceNames, trialNames} ...
%             {choiceNames, trialNames} ...
%             };


        opt.sortClusters = 'sig';

        
    
end
end

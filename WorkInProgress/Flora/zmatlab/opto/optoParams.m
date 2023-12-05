function [params] = optoParams()
    %params.subject  = {['AV029'];['AV033'];['AV031'];['AV036'];['AV038'];['AV046'];['AV041'];['AV047'];['AV044']};
    %params.subject  = {['AV036'];['AV038'];['AV046'];['AV041'];['AV044'];['AV047']};
    %params.subject  = {['AV036'];['AV038']};
    params.subject  = {['AV041'];['AV047'];['AV044']};
    %params.subject  = {['AV047'];['AV044']};
    params.subject  = {['AV044']};
    params.expDef = 't'; 
    params.checkEvents = '1';
    params.expDate = {['2022-09-04:2023-12-04']}; 
    params.reverse_opto =0;
    params.combMice = 0; 
    params.selPowers = [5,10,15,17,20,22,27,34];
    params.selHemispheres = [-1,0,1];
    params.sepPlots= 1; % customary!!
    params.minN = 50; 
    params.includeNoGo = 0;  
end 
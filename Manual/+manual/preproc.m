close all

clear params
params.subject = {'AV045'};
params.expDate = {['2023-05-17']}; 
params.expDef = 't'; 

%
% preproc.extractExpData(exp2checkList,'recompute',{['events']});
%params.checkAlignEphys = '2'; 
%params.expNum = '1'; 
%params.expDate = {'2021-03-16'}; 
exp2checkList = csv.queryExp(params);

%% Just run alignment
preproc.align.main(exp2checkList,'recompute',{'sideCam'});

%% Just run preprocessing
preproc.extractExpData(exp2checkList,'recompute',{['events']},'process',{['events']}); % here spk does not work 



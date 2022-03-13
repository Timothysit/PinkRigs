function autoRunOvernight
%% Functions that will run on timeline computers
computerType = getComputerType;

switch lower(computerType)
    case 'time'
        fprintf('Detected timeline computer... \n')
        
        fprintf('Running "copyLocalData2ServerAndDelete"... \n')
        copyLocalData2ServerAndDelete('D:\LocalExpData');
        
        fprintf('Running "runFacemap" ... \n')
        eveningFacemapPath = which('evening_facemap.py');
        [statusFacemap resultFacemap] = system(['conda activate facemap && ' ...
            'python ' eveningFacemapPath ' &&' ...
            'conda deactivate']);
        if statusFacemap > 0
            fprintf('Facemap failed with error "%s".\n', resultFacemap)
        end
        
    case 'ephys'
        fprintf('Detected ephys computer... \n')
        
        fprintf('Running "copyLocalData2ServerAndDelete"... \n')
        copyLocalData2ServerAndDelete('D:\LocalExpData');
        
        fprintf('Running "copyEphysData2ServerAndDelete"... \n')
        copyEphysData2ServerAndDelete('D:\ephysData');
        
        fprintf('Running "runFacemap" ... \n')
        eveningFacemapPath = which('evening_facemap.py');
        [statusFacemap resultFacemap] = system(['conda activate facemap && ' ...
            'python ' eveningFacemapPath ' &&' ...
            'conda deactivate']);
        if statusFacemap > 0
            fprintf('Facemap failed with error "%s".\n', resultFacemap)
        end
        
    case 'kilo1'
        fprintf('Detected kilo1 computer... \n')
        
        dbstop if error
        
        fprintf('Running "csv.checkForNewPinkRigRecordings"... \n')
        csv.checkForNewPinkRigRecordings;
        
        c = clock;
        if c(4) > 20
            fprintf('Update on training... \n')
            checkTrainingPath = which('check_training_mice.py');
            [statusTrain,resultTrain] = system(['conda activate PinkRigs && ' ...
                'python ' checkTrainingPath ' &&' ...
                'conda deactivate']);
            if statusTrain > 0
                fprintf('Updating on training failed with error "%s".\n', resultTrain)
            end
        end
        
        fprintf('Getting kilosort queue... \n')
        stageKSPath = which('stageKS.py');
        [statusQueue,resultQueue] = system(['activate PinkRigs && ' ...
            'python ' stageKSPath ' && ' ...
            'conda deactivate']);
        if statusQueue > 0
            fprintf('Updating the queue failed with error "%s".\n', resultQueue)
        end
        
        fprintf('Running kilosort on the queue... \n')
        if c(4) > 20
            paramsKilo.runFor = 2; % to stop it after about 20h
        else
            paramsKilo.runFor = 17;
        end
        kilo.main(paramsKilo)
         
        fprintf('Running preprocessing...\n')
        paramsPreproc.mice2Check = {'AV007','AV008','AV009'}; % for now to avoid crashes
        preproc.main(paramsPreproc);
end
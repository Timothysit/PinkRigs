function copyFiles2ServerAndDelete(localFilePaths, serverFilePaths, makeMissingDirs)
if ~exist('makeMissingDirs', 'var'); makeMissingDirs = 0; end

serverList = getServersList;
serverList = cellfun(@(x) x(1:10), serverList, 'uni', 0);

if any(cellfun(@(x) contains(x, serverList), localFilePaths))
    error('It seems like the localFolder is actually on the zerver?!?!')
end

isDirectory = cellfun(@isfolder, localFilePaths);
localFilePaths = localFilePaths(~isDirectory);
serverFilePaths = serverFilePaths(~isDirectory);
copiedAlready = cellfun(@(x) exist(x,'file'), serverFilePaths)>0;

if any(contains(serverFilePaths, 'ephys'))    
    slashIdx = cellfun(@(x) strfind(x, filesep), serverFilePaths, 'uni', 0);
    serverFilePathsCelian = cellfun(@(x,y) [x(1:y(end-2)-1) x(y(end-1):end)], serverFilePaths, slashIdx, 'uni', 0);
    copiedAlreadyCelian = cellfun(@(x) exist(x,'file'), serverFilePathsCelian)>0;
    serverFilePaths(copiedAlreadyCelian) = serverFilePathsCelian(copiedAlreadyCelian);
    copiedAlready = copiedAlready | copiedAlreadyCelian;
end

%% Loop to copy/check/delete files
for i = 1:length(copiedAlready)
    failedCopy = 0*copiedAlready>0;
    localFileMD5 = GetMD5(localFilePaths{i}, 'File');
    fprintf('Processing %s ...\n', localFilePaths{i});
    if ~copiedAlready(i)
        fprintf('Copying %s ...\n', localFilePaths{i});
        tic;
        if ~isfolder(fileparts(serverFilePaths{i}))
            if makeMissingDirs
                mkdir(fileparts(serverFilePaths{i}));
            else
                fprintf('WARNING: Directory missing for: %s. Skipping.... \n', localFilePaths{i});
            end
        end
        try
            copyfile(localFilePaths{i},fileparts(serverFilePaths{i}));
            serverFileMD5 = GetMD5(serverFilePaths{i}, 'File');
            if ~strcmp(localFileMD5, serverFileMD5)
                fprintf('WARNING: Problem copying file %s. Skipping.... \n', localFilePaths{i});
                failedCopy(i) = 1;
            else
                elapsedTime = toc;
                d = dir(localFilePaths{i});
                rate = d.bytes/(10^6)/elapsedTime;
                fprintf('Done in %d sec (%d MB/s).\n',elapsedTime,rate)               
            end
        catch
            fprintf('WARNING: Problem copying file %s. Skipping.... \n', localFilePaths{i});
            failedCopy(i) = 1;
        end
    else
        serverFileMD5 = GetMD5(serverFilePaths{i}, 'File');
        failedCopy(i) = ~strcmp(localFileMD5, serverFileMD5);
    end
    if failedCopy(i) == 0
        fprintf('Copy successful. Deleting local file... \n')
%         delete(localFilePaths{i});
    elseif exist(serverFilePaths{i}, 'file')
        movefile(serverFilePaths{i}, [serverFilePaths{i} '_FAILEDCOPY']);
    end
end
%% TODO--email list of bad copies to users

fprintf('Done! \n')
end


function outPut = md5Error(~,~,~)
%function to handle errors when getting the md5 hash
outPut = 'md5Error';
end
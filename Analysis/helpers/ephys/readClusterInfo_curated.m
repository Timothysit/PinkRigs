

function [cids, cgs] = readClusterInfo_curated(filename)
%function [cids, cgs] = readClusterGroupsCSV(filename)
% cids is length nClusters, the cluster ID numbers
% cgs is length nClusters, the "cluster group":
% - 0 = noise
% - 1 = mua
% - 2 = good
% - 3 = unsorted

fid = fopen(filename);
C = textscan(fid, '%s%s%s%s%s%s%s%s%s%s%s%s%s');
fclose(fid);

cids = cellfun(@str2num, C{1}(2:end), 'uni', false);
ise = cellfun(@isempty, cids);
cids = [cids{~ise}];

isUns = cellfun(@(x)strcmp(x,'unsorted'),C{9}(2:end));
isMUA = cellfun(@(x)strcmp(x,'mua'),C{9}(2:end));
isGood = cellfun(@(x)strcmp(x,'good'),C{9}(2:end));
cgs = zeros(size(cids));

cgs(isMUA) = 1;
cgs(isGood) = 2;
cgs(isUns) = 3;

cgs = uint8(cgs);
cids = uint32(cids);
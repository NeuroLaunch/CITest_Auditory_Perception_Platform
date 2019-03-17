% ANALYZE_THRSWEEPS.M
%	Analysis script to process channel sweep threshold data from a series of related
% runs (e.g. forward + backward sweeps, multiple repetitions).
%	Compatible with the Bierer Lab custom analysis function for use in CITest,
% CUSTOM_THRESHOLD.
%

% Analysis options %
WINSIZE = 0.20;	
PLOTSYMBOL = '.';
LINESTYLE = 'none';

mainparamSkip = {'chanSettings','level'};
expparamSkip = {'chanSettings'};

% Ask user which files to analyze together %
% - list of files would be specific to THR or PTC experiment type
% - possibly show the directions as well
olddir = pwd;
if exist('runInfo','var')
	newdir = fileparts(runInfo.savedfile);
	cd(newdir);
end;

filefilt = 'THR-SWP*.mat';
[loadFile,loaddir] = uigetfile(filefilt,'Select one or more threshold files to process','multiselect','on');
if ~loadFile
	error('No file chosen for analysis.');
end;
if ischar(loadFile)
	loadFile = {loadFile};
end;

% Make sure the files match %
nFile = length(loadFile);
fileok = false(1,nFile);
for i = 1:nFile
	load(fullfile(loaddir,loadFile{i}),'runInfo');
	if strcmp(runInfo.experiment,'threshold') && strcmp(runInfo.mode,'Channel Sweep')
		fileok(i) = true;
	end;
end;

if all(~fileok)
	error('None of the chosen files are from threshold and channel sweep experiments.');
elseif any(~fileok)
	disp('Non-threshold, non-sweep files will be disregarded.');
end;

loadFile = loadFile(fileok);
nFile = length(loadFile);

matchok = true;
if nFile > 1				% make sure the stimulus parameters match across chosen runs!
	for i = 2:nFile
		load(fullfile(loaddir,loadFile{i-1}),'stimInfo');
		mpTemp1 = stimInfo.mainParam; epTemp1 = stimInfo.expParam;
		load(fullfile(loaddir,loadFile{i}),'stimInfo');
		mpTemp2 = stimInfo.mainParam; epTemp2 = stimInfo.expParam;

		[mpstatus,mismpFields] = compare_structures(mpTemp1,mpTemp2);
		[epstatus,misepFields] = compare_structures(epTemp1,epTemp2);

		mpdisregard = false(1,length(mismpFields));
		for j = 1:length(mismpFields)
			mpdisregard(j) = any(strcmp(mismpFields{j},mainparamSkip));
		end;				% don't include certain exceptions for mainParams ..
		if all(mpdisregard), mpstatus = true; end;

		epdisregard = false(1,length(misepFields));
		for j = 1:length(misepFields)
			epdisregard(j) = any(strcmp(misepFields{j},expparamSkip));
		end;				% .. and expParams
		if all(epdisregard), epstatus = true; end;

		matchok = matchok && mpstatus && epstatus;
	end;
end; % if nFile %

if ~matchok
	error('Chosen CITest runs were not all conducted using the same stimulus parameters.');
end;

% X-point hanning windowing method %
load(fullfile(loaddir,loadFile{1}));	% start with a representative file

xctr = 2:1:15;
xval = (stimInfo.mainParam.electrode-1) +  stimInfo.mainParam.configcode(2,:);
xdiff = diff(xval);						% figure out the spacing (assuming regular!)
xdiff = xdiff(xdiff>0 & xdiff<=1);		% avoid redundant channel codes at alpha = 0 and 1
alphstep = mean(xdiff);
sigma = unique(stimInfo.mainParam.configcode(1,:));

fwdind = runResults.blockdir==+1;
fwdblock = runResults.blockidx(fwdind);
padind = runResults.blockdir==0;
padblock = runResults.blockidx(padind);
revind = runResults.blockdir==-1;
revblock = runResults.blockidx(revind);

winlength = round(WINSIZE/alphstep)*2 + 1;
if exist('hanning','file')				% if using computer without signal processing toolbox %
    winvec = hanning(winlength);
else
    half = (winlength+1)/2;
    w = 0.5*(1-cos(2*pi*(1:half)'/(winlength+1)));
    winvec = [w; w(end-1:-1:1)];		% winvec will always be odd-numbered in length
end
winvec = winvec/sum(winvec);
winalph = (-(winlength-1)/2:1:(winlength-1)/2)*alphstep;

for irun = 2;%:2
    RUN = irun;
    filtvalues_fwd = nan(length(winvec),length(xctr)); filtvalues_rev = nan(length(winvec),length(xctr));
    winvalues_fwd = repmat(winvec,[1 length(xctr)]); winvalues_rev = repmat(winvec,[1 length(xctr)]);
    for i = 1:length(xctr)
        for j = 1:length(winvec)					% accumulate and average data for windowing
            %             subind = ismember(Data{RUN}(1,:),find(Data{RUN}(1,:)==xctr(i)+winalph(j)));
            subind = find(Data{RUN}(1,:)==xctr(i)+winalph(j));
            if ~isempty(subind)
                filtvalues_fwd(j,i) = mean(Data{RUN}(2,subind));% dbvalues(subind));
                % 	try, filtvalues_fwd(j,i) = min(dbvalues(subind)); catch, filtvalues_fwd(j,i) = NaN; end;
                %             subind = ismember(runResults.blockidx,find(xval==xctr(i)+winalph(j))) & revind;
                subind = find(Data{RUN}(3,:)==xctr(i)+winalph(j));
                filtvalues_rev(j,i) = mean(Data{RUN}(4,subind));%dbvalues(subind));
            end;
            % 	try, filtvalues_rev(j,i) = min(dbvalues(subind)); catch, filtvalues_fwd(j,i) = NaN; end;
        end;										% for end electrodes, re-weight windowing vector
        nanind = isnan(filtvalues_fwd(:,i)); winvalues_fwd(nanind,i) = NaN;
        winvalues_fwd(~nanind,i) = winvalues_fwd(~nanind,i)./sum(winvalues_fwd(~nanind,i));
        nanind = isnan(filtvalues_rev(:,i)); winvalues_rev(nanind,i) = NaN;
        winvalues_rev(~nanind,i) = winvalues_rev(~nanind,i)./sum(winvalues_rev(~nanind,i));
    end;
    % apply window weights to data, then sum (avoiding NaNs)
    filtvalues_fwd = filtvalues_fwd .* winvalues_fwd;
    filtvalues_fwd = nansum(filtvalues_fwd);
    filtvalues_rev = filtvalues_rev .* winvalues_rev;
    filtvalues_rev = nansum(filtvalues_rev);
    
    plot(Data{RUN}(1,:),Data{RUN}(2,:),'b.');
    hold on;
    plot(Data{RUN}(3,:),Data{RUN}(4,:),'r.');
    
    if 0
    plot(xctr,filtvalues_fwd,'b-','linewidth',2);
    hold on;
    plot(xctr,filtvalues_rev,'r-','linewidth',2);
    end
  
    outvec = [xctr ; filtvalues_fwd; filtvalues_rev];
    
    
    plot(outvec(1,:),mean(outvec(2:3,:)),'k^-','MarkerFaceColor','k');

end;
 

set(gca,'XLim',[1 16]);
xlabel('Sweep electrode (apical to basal)');
ylabel('Stimulus level (dB re 1 uA)');
legend('Forward Sweep','Reverse Sweep','Avg Sweep');%,'Avg 2IFC');


cd(olddir);



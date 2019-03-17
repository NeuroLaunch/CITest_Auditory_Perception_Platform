% ANALYZE_THRSWEEPS.M
%	Analysis script to process channel sweep threshold data from a series of related
% runs (e.g. forward + backward sweeps, multiple repetitions).
%	Compatible with the Bierer Lab custom analysis function for use in CITest,
% CUSTOM_THRESHOLD. The script produces two output arrays for copy-pasting into
% Excel: 'outvec_avg' (total average of all directions and runs) and 'outvec_runs'
% (single-run average of forward and reverse directions; empty if only one direction
% was used); the arrays include a row of electrode numbers, on which the windowed
% averages are centered.
%
% REVISION HISTORY
%	2015.05.18: Added compatibility for tuning curve data ('ptc') collected in sweep mode.
% Also, if data is already loaded in the workspace, that serves as the default file in
% the UIGETFILE() menu.
%

% Analysis options %
WINSIZE = 0.20;						% +/- breadth of window for averaging, in units of alpha
AVGCENTERS = 2:1:15;				% channel numbers on which to center each window (nominal is electrode-centered '2:1:15');

PLOTSYMBOL = '.';
LINESTYLE = 'none';

MAINSKIP = {'level','maxlevel'};	% all runs must have the exact same electrode/alpha set
EXPSKIP = {'direction'};

% Get and load results files, using the generic CITest loading tool %
if ~exist('loaddir','var')
	loaddir = pwd;
end;								% start with last directory or location of last saved file
lastdir = loaddir;

if exist('runInfo','var')
  switch runInfo.experiment
  case 'threshold'
	filefilt = 'THR-SWP*.mat';
	filestart = runInfo.savedfile;
  case 'ptc'
	filefilt = 'PTC-SWP*.mat';
	filestart = runInfo.savedfile;
  otherwise
	filefilt = 'THR-SWP*.mat';
	filestart = '';
  end;
else
	filefilt = 'THR-SWP*.mat';
	filestart = '';
end;

filestart_dir = fileparts(filestart);
if ~exist(filestart_dir,'dir')
	filestart = lastdir;
end;

[loadFile,loaddir] = loadresults_citest(filefilt,MAINSKIP,EXPSKIP,filestart);

if isempty(loaddir)					% reject if the files were not from similar runs
	loaddir = lastdir;				%#ok<NASGU>
	error('Invalid file or files. Analysis script stopped.');
end;
									% grab a representative file
load(fullfile(loaddir,loadFile{1}),'stimInfo','runInfo');
if ~any(strcmp(runInfo.experiment,{'threshold','ptc'})) || ~strcmp(runInfo.mode,'Channel Sweep')
	error('Files are not from threshold/sweep experiments. Analysis script stopped.');
end;								% stop if not the right exp + runmode

fwdData = cell(1,2); fwdChan = cell(1,2);  fwdcnt = 0;
revData = cell(1,2); revChan = cell(1,2); revcnt = 0;

nFile = length(loadFile);
runvec = nan(1,nFile);

for i = 1:nFile						% loop through chosen runs and organize data by channel + direction
	load(fullfile(loaddir,loadFile{i}));
	xval = (stimInfo.mainParam.electrode-1) +  stimInfo.mainParam.configcode(2,:);
	if isfield(runResults,'results')
		dbval =  20*log10(runResults.results);
	else							% data will be analyzed strictly in units of dB uA
		dbval =  20*log10(runResults.values);
	end;
	runvec(i) = runInfo.run;

	fwdind = runResults.blockdir==+1; fwdblock = runResults.blockidx(fwdind);
	revind = runResults.blockdir==-1; revblock = runResults.blockidx(revind);
	if ~isempty(fwdblock)
		fwdcnt = fwdcnt + 1;
		fwdData{fwdcnt} = dbval(fwdind);
		fwdChan{fwdcnt} = xval(fwdblock);
	end;
	if ~isempty(revblock)
		revcnt = revcnt + 1;
		revData{revcnt} = dbval(revind);
		revChan{revcnt} = xval(revblock);
	end;
end; % for i = 1:nFile %

fwdData = fwdData(1:fwdcnt); fwdChan = fwdChan(1:fwdcnt);
revData = revData(1:revcnt); revChan = revChan(1:revcnt);
try
	fwdData = cat(1,fwdData{:}); fwdChan = cat(1,fwdChan{:});
	revData = cat(1,revData{:}); revChan = cat(1,revChan{:});
	fwdchan = unique(fwdChan,'rows'); revchan = unique(revChan,'rows');
	if size(fwdchan,1)>1 || size(revchan,1)>1
		error('Mismatched channels.');
	end;
catch								% this shouldn't happen if LOADRESULTS compared structures correctly
	error('Channel numbers do not match across runs.');
end;

% Get X-point hanning windowing parameters using a representative file %
xval = (stimInfo.mainParam.electrode-1) +  stimInfo.mainParam.configcode(2,:);
xctr = AVGCENTERS;
xctr = xctr(xctr>=ceil(min(xval)) & xctr<=floor(max(xval)));

xdiff = diff(xval);						% figure out the spacing (assuming regular, but catching skipped electrodes)
if ~all(xdiff==1)
	xdiff = xdiff(xdiff>0 & xdiff<1);	% avoid redundant channel codes at alpha = 0 and 1
	xdiff = round(xdiff*100)/100;		% remove small variations
end;

alphstep = unique(xdiff);
if length(alphstep)>1, error('Alpha step size is not uniform.');
elseif isempty(alphstep), error('The alpha step size was not resolved.');
end;

sigma = unique(stimInfo.mainParam.configcode(1,:));
if length(sigma)>1, error('Sigma value is not constant.'); end;

if length(xval)==1
	winvec = 1; winalph = 0;
else
	winlength = round(WINSIZE/alphstep)*2 + 1;
	if exist('hanning','file')				% if using computer with signal processing toolbox
		winvec = hanning(winlength);
	else
		half = (winlength+1)/2;
		w = 0.5*(1-cos(2*pi*(1:half)'/(winlength+1)));
		winvec = [w; w(end-1:-1:1)];		% winvec will always be odd-numbered in length
	end
	winvec = winvec/sum(winvec);
	winalph = (-(winlength-1)/2:1:(winlength-1)/2)*alphstep;
end;

% Apply window weights to data, then sum (avoiding NaNs) %
nfwd = size(fwdData,1); nrev = size(revData,1);
binvalues_fwd = nan(length(winvec),length(xctr),nfwd);
binvalues_rev = nan(length(winvec),length(xctr),nrev);
winvalues_fwd = repmat(winvec,[1 length(xctr)]); winvalues_rev = repmat(winvec,[1 length(xctr)]);

for i = 1:length(xctr)
	for j = 1:length(winvec)		% accumulate and average data for windowing
	  if nfwd
		subind = fwdchan == xctr(i)+winalph(j);
		temp = mean(fwdData(:,subind),2);
		binvalues_fwd(j,i,:) = temp; % keep multiple forward (and reverse) runs separate; 'binvalues' are in dB uA
	  end;

	  if nrev						% note that reverse electrode order is now same as for forward
		subind = revchan == xctr(i)+winalph(j);
		temp = mean(revData(:,subind),2);
		binvalues_rev(j,i,:) = temp;
	  end;
	end;
									% for end electrodes, re-normalize windowing vector
	if nfwd
	  nanind = isnan(binvalues_fwd(:,i,1)); winvalues_fwd(nanind,i) = NaN;
	  winvalues_fwd(~nanind,i) = winvalues_fwd(~nanind,i)./sum(winvalues_fwd(~nanind,i));
	end;
	if nrev
	  nanind = isnan(binvalues_rev(:,i,1)); winvalues_rev(nanind,i) = NaN;
	  winvalues_rev(~nanind,i) = winvalues_rev(~nanind,i)./sum(winvalues_rev(~nanind,i));
	end;
end;

filtvalues_fwd = binvalues_fwd .* repmat(winvalues_fwd,[1,1,nfwd]);
filtvalues_fwd = nansum(filtvalues_fwd,1);	% of size #electrodes x #forward runs
filtvalues_fwd = reshape(filtvalues_fwd,[length(xctr),nfwd])';

nanind = all(isnan(winvalues_fwd));			% entries with no valid values show be NaN, not 0
filtvalues_fwd(nanind) = NaN;

filtvalues_rev = binvalues_rev .* repmat(winvalues_rev,[1,1,nrev]);
filtvalues_rev = nansum(filtvalues_rev,1);	% of size #electrodes x #reverse runs
filtvalues_rev = reshape(filtvalues_rev,[length(xctr),nrev])';

nanind = all(isnan(winvalues_rev));
filtvalues_rev(nanind) = NaN;

% Create array for copy + pasting into Excel %
outvec_avg = [xctr ; mean([filtvalues_fwd; filtvalues_rev],1)];
if nfwd==nrev
	outvec_runs = [xctr ; (filtvalues_fwd + filtvalues_rev)/2];
else
	outvec_runs = [];
end;

% Plot the data and filtered averages %
hfig = figure('Position',[330 240 1000 380]);
haxes = axes('Position',[0.0710 0.1368 0.7160 0.8184],'NextPlot','Add');
set(haxes,'FontSize',12,'XLim',[0.8 16.2],'XTick',1:16);

htitle = title(runInfo.subject);	% off to the side
set(htitle,'Units','Normalized','Position',[1.13 .93]);
xlabel('Electrode (apical to basal)','FontSize',12); ylabel('Stimulus Level (dB uA)','FontSize',12);

if nfwd && nrev
	yshift = .1;					% shift fwd and rev by 0.2 dB, if both are present
else yshift = 0;
end;

plot(fwdchan,fwdData+yshift,'b.');
plot(revchan,revData-yshift,'r.');
									% plot the AVERAGE across multiple fwd and rev runs
hfwd = plot(xctr,mean(filtvalues_fwd,1),'b-','linewidth',2);
hrev = plot(xctr,mean(filtvalues_rev,1),'r-','linewidth',2);
havg = plot(xctr,mean([filtvalues_fwd;filtvalues_rev],1),'k^','MarkerFaceColor','k');

hlegend = legend([hfwd,hrev,havg],'Fwd Sweeps','Rev Sweeps','Average');
set(hlegend,'position',[.8 .75 .17 .06]);
									% display some run info (assume all files from same subject + session!)
runstr = num2str(runvec(1:min(length(runvec),20))); if length(runvec)>20, runstr = [runstr ' ...']; end;
namestr = sprintf('   Analysis Results for  Subject %s,  Session %d,  Runs %s',runInfo.subject,runInfo.session,runstr);
set(hfig,'Name',namestr);


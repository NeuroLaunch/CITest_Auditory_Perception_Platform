% LOADRESULTS_CITEST.M
% function [loadFile,loaddir] = loadresults_citest(filefilt,mainskip,expskip,startdir)
%	Utility function to choose one or more related results files created by the CITest
% psychophysical testing program. The files must all have come from runs conducted
% using similar stimulus settings, enforced by comparing the fields of 'stimInfo.
% mainParam' and 'stimInfo.expParam'.
%	Input argument 'filefilt' is a filter for UIGETFILE, such as 'THR-SWP*.mat'; 
% leave empty to allow any MATLAB file. 'mainskip' and 'expskip' are field names
% from 'mainParam' and 'expParam', respectively, that can be ignored when comparing
% the results structures from the chosen runs. 'startdir' is the directory for
% starting the UIGETFILE search. Output argument 'loadFile' is a cell array containing
% the chosen file names, and 'loaddir' is a single string indicating the file directory.
% 'loaddir' will be empty if no files were chosen, or if the files are not suitably
% similar.
%	File comparisons are performed using the general-purpose function COMPARE_STRUCTURES.
%
% #### Possibly add option to grab files indicated by 'runSummary', stored in
% the Results View window (if open!). #######################################
%

function [loadFile,loaddir] = loadresults_citest(filefilt,mainskip,expskip,startfile)

MAINSKIP_INIT = {'chanSettings'};
EXPSKIP_INIT = {'chanSettings'};

if nargin < 4
	startfile = '';
end;

if isempty(filefilt)
	filefilt = '*.mat';
end;

mainskip = cat(2,MAINSKIP_INIT,mainskip);
expskip = cat(2,EXPSKIP_INIT,expskip);

% Ask user which files to analyze together %
if isempty(startfile)			% start at the specified or last-used directory
	wBase = evalin('base','whos');
	wBase = {wBase.name};
	if any(strcmp('runInfo',wBase))
		runInfo = evalin('base','runInfo');
		startfile = fileparts(runInfo.savedfile);
	end;
end;							% if uncertain, start with current directory
if ~exist(startfile,'file') && ~exist(startfile,'dir')
	startfile = pwd;
end;

[loadFile,loaddir] = uigetfile(filefilt,'Select one or more CITest files to process',startfile,'multiselect','on');
if ~iscell(loadFile) && ~ischar(loadFile)
	disp('No file chosen for loading.');
	loadFile = {}; loaddir = '';
	return;						% return empty variables if no files chosen
end;
if ischar(loadFile)
	loadFile = {loadFile};
end;

% Make sure the files match %
% nFile = length(loadFile);
% fileok = false(1,nFile);
% for i = 1:nFile
% 	load(fullfile(loaddir,loadFile{i}),'runInfo');
% 	if strcmp(runInfo.experiment,'threshold') && strcmp(runInfo.mode,'Channel Sweep')
% 		fileok(i) = true;
% 	end;
% end;
% 
% if all(~fileok)
% 	cd(olddir);
% 	error('None of the chosen files are from threshold and channel sweep experiments.');
% elseif any(~fileok)
% 	disp('Non-threshold, non-sweep files will be disregarded.');
% end;
% 
% loadFile = loadFile(fileok);
% nFile = length(loadFile);

nFile = length(loadFile);

matchok = true;
if nFile > 1				% make sure the stimulus parameters match across chosen runs!
	load(fullfile(loaddir,loadFile{1}),'stimInfo');
	mpTemp2 = stimInfo.mainParam; epTemp2 = stimInfo.expParam;
	for i = 2:nFile
% 		load(fullfile(loaddir,loadFile{i-1}),'stimInfo');
% 		mpTemp1 = stimInfo.mainParam; epTemp1 = stimInfo.expParam;
		mpTemp1 = mpTemp2; epTemp1 = epTemp2;
		load(fullfile(loaddir,loadFile{i}),'stimInfo');
		mpTemp2 = stimInfo.mainParam; epTemp2 = stimInfo.expParam;

		[mpstatus,mismpFields] = compare_structures(mpTemp1,mpTemp2);
		[epstatus,misepFields] = compare_structures(epTemp1,epTemp2);

		mpdisregard = false(1,length(mismpFields));
		for j = 1:length(mismpFields)
			mpdisregard(j) = any(strcmp(mismpFields{j},mainskip));
		end;				% don't include certain exceptions for 'mainParams' ..
		if all(mpdisregard), mpstatus = true; end;

		epdisregard = false(1,length(misepFields));
		for j = 1:length(misepFields)
			epdisregard(j) = any(strcmp(misepFields{j},expskip));
		end;				% .. and 'expParams'
		if all(epdisregard), epstatus = true; end;

		matchok = matchok && mpstatus && epstatus;
	end;
end; % if nFile %

if ~matchok
	disp('Chosen CITest runs were not all conducted using the same stimulus parameters.');
	loadFile = {}; loaddir = '';
end;

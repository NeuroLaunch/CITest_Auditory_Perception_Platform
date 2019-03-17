function varargout = CITest(varargin)
% CITest M-file for CITest.fig
% Last Modified by GUIDE v2.5 03-Nov-2009 15:35:19
%
%	Graphical user interface for controlling BEDCS-based psychophysical experiments. A number
% of "experiment types" are currently supported (e.g. threshold, psych. tuning curves), as well as
% various "runtime modes" for running these experiments (e.g. 2-interval forced choice, Bekesy-style.
% tracking), Additional experiment types and runtime modes can be added by creating new GUIs
% in a standard format recognized by CITEST. See "CITest Documentation.docx" for more details.
%
% VERSION HISTORY
%	CITest_v01.22 started on January 20, 2015 by SMB. Previous version was 1.21.
%	2015.03.02. Moved code that positions the run-time GUI to the main m-file. Added 'bedcsParam' as
% an argument to the initial run-time GUI call, as this structure contains the BEDCS parameters
% needed to set the reference (fixed) stimulus for the "Two-step Adjust" mode.
%	2015.03.10. Similarly, moved the portion of code that makes sure start level does not exceed max
% level from the run GUIS to the main GUI (for both primary channel w/ 'mainParam' and secondary
% channel w/ 'expParam').
%	2015.04.08. Changed default sigma of primary channel to 0.9 (for pTP and sQP configurations).
%	2015.09.25. Added probe channel to file name, for PTC experiments.
%	3015.05.06. Adjust 'tbase' to larger values if the pulse rate is low enough. This is to avoid an
% excessive number of zeros in the BEDCS pulse table, which crashes the program. (Sad times.)
%

% --- Begin initialization code - DO NOT EDIT --- %
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% --- End initialization code - DO NOT EDIT --- %


% --- Executes just before CITest is made visible --- %
% Note that variables in ALLCAPS are lab-specific settings managed by CITEST_USERSETTINGS.
function CITest_OpeningFcn(hObject, eventdata, handles, varargin)

% Lab-specific settings and general run-time options %
COMPUTERID = 'BiererLaptop';       		%#ok<*NASGU> %% <---- Set this line every time a new CITest version is uploaded %%
VERSION = 1.240;

CITest_UserSettings;					% facilitating script to set user-specific run-time variables

% Check and adjust expected directory for BEDCS files %
if ~exist(handles.bedcsinfo.dir,'dir')
	maindir = mfilename('fullpath'); maindir = fileparts(maindir);
	newdir = fullfile(maindir,handles.bedcsinfo.dir);
	handles.bedcsinfo.dir = newdir;
end;
if ~exist(handles.bedcsinfo.dir,'dir')	% last chance
	error('BEDCS directory was not found. Check the ''bedcsinfo.dir'' setting in CITEST_USERSETTINGS.M.');
end;

% Set some button action, display, and storage defaults %
xypos = get(hObject,'Position'); xypos(1:2) = handles.xydefault.main;
set(hObject,'Position',xypos);

namestr = sprintf('Cochlear Implant Testing - Control Panel  (CITest v%.3f)',VERSION);
set(hObject,'Name',namestr);
										% starting config codes for each config mode
configStruct = struct('type','sQP','pTP',0.9,'sQP',0.9,'BP',0);
set(handles.config_popup,'UserData',configStruct);

set([handles.start_pushbutton handles.pause_pushbutton],'Enable','Off');
set(handles.expblank_uipanel,'Visible','Off');

set(handles.seebedcs_togglebutton,'ForegroundColor',[.10 .15 .00],'Value',0);
set(handles.seeresults_togglebutton,'ForegroundColor',[0 .5 0],'Value',1);

% Initialize storage structures for electrodes and channels %
achan = 8;									% GUI default is for just one channel ..
atype = 'sQP'; asigma = 0.9;				% .. in the steered quadrupolar configuration ..
aalpha = 1.0;								% .. and with no current steering (GUI figure at opening should reflect this)

chanProfile.onoff = false(1,16);			% stores the Channel Selector subGUI field values, one entry per electrode
chanProfile.onoff(achan) = true;
chanProfile.threshold = nan(1,16);
chanProfile.mcl = nan(1,16);
chanProfile.impedance = nan(1,16);
chanProfile.compliance = 333*ones(1,16);

chanProfile.alphatype = 1;				% Channel Sel. alpha-related field values; '.alphatype' "1" is "Single Value"
chanProfile.alphaval = aalpha;			% '.alphaval' can be a single value or step size for a range of values
chanProfile.alphavector = aalpha;		  % (dep. on '.alphatype')

chanProfile.stimspec = [];				% '.stimspec' keeps track of the stimulus parameters that MCL/THR apply to
chanProfile.stimspec.configtype = atype;
chanProfile.stimspec.configval = asigma;
chanProfile.stimspec.phdur = 99;		% these values are just place holders
chanProfile.stimspec.traindur = 999;
chanProfile.stimspec.pulserate = 1000;

handles.chanProfile = chanProfile;		% updated with changes to active elec, config, or alpha (main gui) or Ch. Selector
handles.chanProfileHistory = [];		% this will track past channel settings as long as CITest is open

% Set up a few other run-time and storage variables %		% pulse parameters mostly overwritten in _SetupStim()
pulseSettings = struct('type','','tbase',12*44/49,'tbase_init',12*44/49,'phframes',9,'plsframes',18,'ipframes',75,'numpulses',200,...
  'phdur',100,'pulserate',1000,'traindur',200,'dataUI',[],'expgui','');

handles.mainParam = struct('exptype','','expabbr','','expgui','','subtype','','runmode','Manual Level',...
  'runabbr','MNL','electrode',8,'configtype',atype,'configcode',asigma,'pulseSettings',pulseSettings,...
  'chanSettings',[],'level',[],'minlevel',[],'maxlevel',[]);

handles.expParam = [];
handles.expHandles.uipanel = [];
handles.expHandles.expgui = [];
handles.runnumber = 1;
handles.runHistory = {};

if DEMOMODE
	set(handles.demomode_menu,'Checked','On');
else set(handles.demomode_menu,'Checked','Off');
end;

handles.demomode = DEMOMODE;
handles.version = VERSION;
handles.output = hObject;

guidata(hObject, handles);

% Set up external GUIs %				% facilitating function to open Results View window and hide it
hresults = CITest_ResultsViewSetup(hObject);

setappdata(hObject,'hrun',[]);			% these will store the handle and m-file name of the extenal run-time GUI
setappdata(hObject,'rungui','');
setappdata(hObject,'hactx',[]);			% and the BEDCS application
setappdata(hObject,'hresults',hresults);% and the Results View figure; ## no longer keeping the 'hview' axes handle
setappdata(hObject,'runactive',false);
setappdata(hObject,'hchselect',[]);		% and the Channel Selector GUI

assignin('base','hctrl',hObject);		% this is handy to have in the workspace, for debugging purposes

% Set up keyboard shortcuts when main GUI or Results Window is in scope (run-time subGUI will be set later) %
try
	handlset = [hObject hresults];
	set(handlset,'WindowKeyPressFcn',{@CITest_KeyPress,hObject});
catch						% earlier MATLAB versions don't recognize "Window" key functions
	handlset = [hObject hresults handles.start_pushbutton handles.pause_pushbutton];
	set(handlset,'KeyPressFcn',{@CITest_KeyPress,hObject});
end;

% Final set up, including pulse phase and rate as well as the file name %
CITest_SetupStimParam(handles.exp_popup,[],handles);	% GUIDATA() is called once more


% --- Outputs from this function are returned to the command line.
function varargout = CITest_OutputFcn(hObject, eventdata, handles)

varargout{1} = handles.output;



%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Make one last parameter check, launch the runtime GUI, and run the selected experiment --- %
function start_pushbutton_Callback(hObject, eventdata, handles)

% Determine the most up-to-date stimulus parameters %
% Note that upon return of Channel Selector, some parameters are updated (via "UserData" property).
expgui = handles.expHandles.expgui;

configStruct = get(handles.config_popup,'UserData');
configtype = configStruct.type;
configval = get(handles.config1_edittext,'UserData');
									% store necessary info from various UI fields
chanSettings.electrode = get(handles.activeelec_popup,'UserData'); % (some entries will be overwritten below)
chanSettings.configtype = configtype; % redundancy later with 'mainParam', but that's OK
chanSettings.configval = configval(1);% reiterating that this is a scalar and not a vector
chanSettings.alpha = get(handles.config2_edittext,'UserData');
chanSettings.configcode = [];		% set below

chanSettings.impedance = handles.chanProfile.impedance;
chanSettings.compliance = handles.chanProfile.compliance;
chanSettings.threshold = handles.chanProfile.threshold;
chanSettings.mcl = handles.chanProfile.mcl;
									% also redundancy with respect to pulse settings
chanSettings.phdur = handles.mainParam.pulseSettings.phdur;
chanSettings.traindur = handles.mainParam.pulseSettings.traindur;
chanSettings.pulserate = handles.mainParam.pulseSettings.pulserate;
chanSettings.ratestr = get(handles.rate_text,'String');
									% make sure the threshold and mcl values from Channel Selector are valid
mlmatch = CITest_ChannelSelector('CITest_ChannelSelector_Match',chanSettings,handles.chanProfile);
if ~mlmatch							% if config., phase duration, etc don't match, reset threshold and mcl values
	chanSettings.threshold = nan(1,16); % (the 'chanProfile' entries are NOT updated, however)
	chanSettings.mcl = nan(1,16);
end;
									
% Interpret configuration and electrode settings to define every channel for the experiment %
if strcmp(configtype,'pTP') || strcmp(configtype,'sQP')
	electrode = repmat(chanSettings.electrode,length(chanSettings.alpha),1);
	electrode = electrode(:)';		% 'electrode' consists of one row; each entry is a different "channel"
	ccrow2 = repmat(chanSettings.alpha,1,length(chanSettings.electrode)); % (elec./alpha combo)
	ccrow1 = chanSettings.configval * ones(1,length(ccrow2));
	configcode = [ccrow1 ; ccrow2];	% 'configcode' consists of two rows: sigma and alpha ..
else % 'BP' %
	electrode = chanSettings.electrode;
	ccrow1 = configval * ones(1,length(electrode));
	ccrow2 = nan(1,length(electrode));
	configcode = [ccrow1 ; ccrow2];	% .. or for BP, channel separation (minus 1 by convention) and undefined
end;

chanSettings.electrode = electrode;	% update for _Exp_GetParameters(), below
chanSettings.configcode = configcode;

pulseSettings = handles.mainParam.pulseSettings;

% Determine experiment-specific parameters %
[levelParam, expParam] = feval(expgui,'CITest_Exp_GetParameters',handles,chanSettings,pulseSettings);

if isempty(levelParam) && ischar(expParam)
	warnstr = sprintf('One or more level settings are invalid. %s',expParam);
	hw = warndlg(warnstr,'Bad Level Setup','modal');
	uiwait(hw);
	return;
elseif isempty(expParam) || ischar(expParam)
	warnstr = sprintf('One or more experiment settings are invalid. %s',expParam);
	hw = warndlg(warnstr,'Bad Experiment Setup','modal');
	uiwait(hw);						% string 'expParam' acts as an error description
	return;
elseif length(levelParam.chanidx) < length(electrode);
	hw = warndlg('This experiment and run-time mode can support only a subset of defined channels.',...
	  'Using Fewer Channels','modal');
	uiwait(hw);						% for some exp/subexps, only one or a subset of defined channels will be used
	electrode = electrode(levelParam.chanidx);
	configcode = configcode(:,levelParam.chanidx);
end;

% Store level and other parameters in 'mainParam' %
mainParam = handles.mainParam;		% start with already stored parameters (includes '.pulseSettings', 'runmode', etc)

mainParam.electrode = electrode;
mainParam.configtype = configtype;
mainParam.configcode = configcode;

mainParam.level = levelParam.value;
mainParam.minlevel = levelParam.minlimit;
mainParam.maxlevel = levelParam.maxlimit;
									% for record keeping, also store the "raw" channel settings
chanSettings.electrode = get(handles.activeelec_popup,'UserData');
mainParam.chanSettings = chanSettings;				% revert to original electrode vector for this purpose
mainParam.chanSettings.configStruct = configStruct;	% add a few other bits as well
mainParam.chanSettings.levelstr = levelParam.valuestring;
mainParam.chanSettings.maxstr = levelParam.maxstring;

% Do a final validity check for electrical current levels %
highind = mainParam.level > mainParam.maxlevel;
if any(highind)						% force primary standard (start) level to be no greater than max level
	hw = warndlg('One or more levels are too high. Resetting to maximum.','Resetting high values','modal');
	uiwait(hw);
	if length(mainParam.maxlevel)>1, mainParam.level(highind) = mainParam.maxlevel(highind);
	else mainParam.level(highind) = mainParam.maxlevel;
	end;
end;

lvlProfile = struct('mcl',chanSettings.mcl,'compliance',chanSettings.compliance);
invalid_levels = CITest_EvaluateLevels(mainParam,lvlProfile,handles.deviceProfile.currentlimit);

if any(invalid_levels)				% don't proceed if any channel level is invalid
	disp('Run cannot be started because a current limit would be exceeded for the primary channel.');
	return;
end;

if isfield(expParam,'electrode2')	% if a secondary channel defined (e.g. for masking), certain parameters
	highind = expParam.level > expParam.maxlevel; % MUST have been defined in '_Exp_GetParameters'
	if any(highind)					% force (start) level to be no greater than max level
	  hw = warndlg('One or more secondary levels are too high. Resetting to maximum.',...
		'Resetting high values','modal');
	  uiwait(hw);
	  if length(expParam.maxlevel)>1, expParam.level(highind) = expParam.maxlevel(highind);
	  else expParam.level(highind) = expParam.maxlevel;
	  end;
	end;
	
	chanSettings2 = expParam.chanSettings;
	lvlProfile2 = struct('mcl',chanSettings2.mcl,'compliance',chanSettings2.compliance);
	chgdur2 = expParam.chgdur;		% use phase duration for secondary channel (usually same as for primary)
	invalid_levels = CITest_EvaluateLevels(expParam,lvlProfile2,handles.deviceProfile.currentlimit,chgdur2);

	if any(invalid_levels)			% as with primary channel, don't proceed if any level is invalid
	  disp('Run cannot be started because a current limit would be exceeded for the secondary channel.');
	  return;
	end;
end; % if ~isempty(expParam) %

if strcmpi(mainParam.configtype,'pTP') || strcmpi(mainParam.configtype,'sQP')
  sigmaval = mainParam.configcode(1,1);	% make sure configuration parameters are valid, mainly for safety
  alphaval = mainParam.configcode(2,:);
  if sigmaval<0 || sigmaval>1 || length(unique(mainParam.configcode(1,:)))~=1
	disp('Invalid sigma value for the primary channel.');
	return;								% at present, sigma can't be a variable for primary channel
  end;
  if any(alphaval<0) || any(alphaval>1)
	disp('Invalid alpha value for the primary channel.');
	return;
  end;
end;

if isfield(expParam,'configtype') && (strcmpi(expParam.configtype,'pTP') || strcmpi(expParam.configtype,'sQP'))
  sigmaval = expParam.configcode(1,:);
  alphaval = expParam.configcode(2,:);
  if any(sigmaval<0) || any(sigmaval>1)
	disp('Invalid sigma value for the primary channel.');
	return;								% sigma CAN be a variable for secondary channel
  end;
  if any(alphaval<0) || any(alphaval>1)
	disp('Invalid alpha value for the primary channel.');
	return;
  end;
end;

% Transform the stimulus parameters into BEDCS variables and other commands for the subject-interaction GUI %
[bedcsParam, ctrlParam] = feval(expgui,'CITest_Exp_TransformParameters',mainParam,expParam,handles.deviceProfile);

handles.mainParam = mainParam;			% store the stimulus and control parameters
handles.expParam = expParam;
handles.bedcsParam = bedcsParam;
handles.ctrlParam = ctrlParam;

guidata(hObject,handles);				% give a stamp of approval to all that storage

loadpath = fullfile(handles.bedcsinfo.dir,bedcsParam.bedcsexp);

if isempty(bedcsParam.bedcsexp)
	hw = warndlg('The chosen experiment type is not defined.','Experiment Type Undefined','modal');
	uiwait(hw);					% don't continue if experiment type/subtype is undefined or otherwise invalid
	return;
elseif ~exist(loadpath,'file')
	warnstr = sprintf('The BEDCS definition file [%s] cannot be found.',bedcsParam.bedcsexp);
	hw = warndlg(warnstr,'Experiment Type Undefined','modal');
	uiwait(hw);					% don't continue if experiment type/subtype is undefined or otherwise invalid
	return;
elseif isempty(ctrlParam)
	hw = warndlg('There was an error executing the chosen run-time mode.','Run-time Mode Undefined','modal');
	uiwait(hw);					% same with the run-time mode
	return
end;

% Load the BEDCS experiment file and initialize its parameters %
hactx = CITest_OpenApplication(handles); % this also stores 'hactx' via SETAPPDATA()

if ~hactx.Online && ~handles.demomode
	fprintf(1,'Initializing BEDCS.');
	hactx.Online = 1;
	waittime = 0;
	while ~hactx.IsCIIReady && waittime<=20
		fprintf(1,'.');					% give the program time to come on-line when it's first opened
		pause(0.25);
		waittime = waittime + .25;
	end;
	fprintf(1,'\n');
	if waittime > 20					% after 20 seconds, give a warning and terminate execution
		hw = warndlg('ERROR: BEDCS connection to the implant failed.','BEDCS Error','modal');
		uiwait(hw);
		hactx.Online = 0;
		return;
	end;
	hactx.ULevelMode = 1;
	hactx.Visible = 0;

elseif handles.demomode
	hactx.Online = 0;

elseif hactx.Visible == 1					% if BEDCS already open, warn user that it's still open
	disp('BEDCS is open, which may cause stability issues.');

end; % if ~hactx && ~demomode

hactx.LoadExpFile(loadpath);			% load the BEDCS experiment file and set some common parameters
hactx.DataPath = handles.fileinfo.directory;

tbase_bedcs = hactx.Get_ControlVarVal('tbase');
if char(tbase_bedcs), tbase_bedcs = str2num(tbase_bedcs); end;
tbase = mainParam.pulseSettings.tbase;	% check for expected 'tbase' value in BEDCS file (to nearest .01)
if round(tbase_bedcs*100) ~= round(tbase*100)
% 	hw = warndlg('The BEDCS time base parameter does not match the CITEST setting.','Experiment Error','modal');
% 	uiwait(hw);
% 	return;
	hactx.Let_ControlVarVal('tbase',mainParam.pulseSettings.tbase);
	disp('The time base parameter has been adjusted to accommodate a change in pulse train rate.');
end;

parNames = fieldnames(bedcsParam);		% the first field in 'bedcsPars' is always the BEDCS file name
parNames = parNames(2:end);
for i = 1:length(parNames)				% set the initial BEDCS stimulus parameters
	hactx.Let_ControlVarVal(parNames{i},bedcsParam.(parNames{i}));
end;
pause(0.2);

% Launch the subject interaction / run-time GUI %
[hrun,postype] = feval(ctrlParam.rungui,ctrlParam,bedcsParam,handles.citest,handles.demomode);
if isempty(hrun)						% ##2015.09: changed to 'isempty()' because R2014+ represents handles as structures
	hw = warndlg('One or more run-time GUI parameters is invalid.','Experiment Error','modal');
	uiwait(hw);
	return;
end;

xynew = handles.xydefault.(postype);
runpos = get(hrun,'Position');		% re-position run-time GUI depending on desired user (controller or subject)
runpos(1:2) = xynew;				% (putting code out here overcomes issue with displaying on a second monitor)
set(hrun,'Position',runpos,'Name','');

setappdata(handles.citest,'hrun',hrun);
setappdata(handles.citest,'rungui',ctrlParam.rungui);

stimInfo.mainParam = mainParam;		% push stimulus and other variables to the base workspace
stimInfo.expParam = expParam;		  % (for debugging and other purposes)
stimInfo.ctrlParam = ctrlParam;
stimInfo.bedcsParam = bedcsParam;

assignin('base','stimInfo',stimInfo);
assignin('base','hrun',hrun);

CITest_UpdateFileName(handles,1);	% update displayed file name one last time before the run starts
handles = guidata(hObject);

try									% set up "P" and "R" keyboard shortcuts for the run-time GUI
  kpstatus = get(hrun,'WindowKeyPressFcn'); % (if keyboard shortcuts are already defined in the run-time GUI,
  if isempty(kpstatus)						%  don't do anything)
	set(hrun,'WindowKeyPressFcn',{@CITest_KeyPress,handles.citest});
  end;
catch
  kpstatus = get(hrun,'KeyPressFcn');
  if isempty(kpstatus)				% include all uicontrols with an empty keypress property
	handlset = get(hrun,'Children')';
	handlset = [hrun handlset( ismember(handlset,findobj(hrun,'type','uicontrol','keypressfcn','')) )];
	set(handlset,'KeyPressFcn',{@CITest_KeyPress,handles.citest});
  end;
end;

hresults = getappdata(handles.citest,'hresults');
hanalysis = findobj(hresults,'tag','pushbutton_analysis');

% Start the experiment with the run-time GUI %
set(hObject,'Enable','Off');					% disable the START button and other ui elements
set([handles.demomode_menu handles.seebedcs_togglebutton],'Enable','Off');
set(hanalysis,'Enable','Inactive');
set(handles.pause_pushbutton,'Enable','On');	% enable the PAUSE button
if ishandle(hrun) && ~getappdata(hrun,'ready')
	uiwait(hrun);								% if subGUI has a READY button, wait for that
end;

setappdata(handles.citest,'runactive',true);	% start stimulation and wait for the run-time GUI to end
runOutput = feval(ctrlParam.rungui,'CITest_RunGUI_Start',hrun);

% Close the run-time GUI %
setappdata(handles.citest,'runactive',false);

fprintf('\n');
if isfield(runOutput,'message')				
	disp(runOutput.message);
else disp('Closing run-time GUI.');
end;

if ishandle(hrun)					% the runtime GUI should normally still be open (no reason to [X] close)
	delete(hrun);					% if so, close it now
end;

% Analyze and optionally display the results of the experiment %
try
	[runResults,runSummary] = feval(expgui,'CITest_Exp_ProcessResults',mainParam,ctrlParam,runOutput);
catch								% unformatted 'runOutput' --> formatted 'runResults'
	runResults = runOutput;
	runSummary = [];				% be wary of errors, as each exp's _ProcessResults will be changed often
	fprintf(1,'\nThe standard analysis routine encountered an error.\n');
end;

filestr = fullfile(handles.fileinfo.directory,handles.fileinfo.filename);
subjstr = get(handles.subject_edittext,'String');
sesnstr = get(handles.session_edittext,'String');

runInfo = struct('subject',subjstr,'session',str2num(sesnstr),'run',handles.runnumber,...
  'experiment',mainParam.exptype,'mode',mainParam.runmode,'date',datestr(now,'yyyy/mm/dd HH:MM'), ...
  'user',handles.userid,'software',[],'savedfile',filestr);
runInfo.mfiles = struct('maingui',mfilename('fullpath'),'version',handles.version,'expgui',handles.expHandles.expgui,...
  'rungui',ctrlParam.rungui,'custom',handles.customanalysis);
									% perform additional custom analysis, if specified in CITEST_USERSETTINGS
[runResults.custom,menuEntry] = CITest_ProcessExtra(runResults,runInfo,stimInfo,handles.customanalysis);
									% push the results to the workspace ('stimInfo' already there)
assignin('base','runInfo',runInfo); assignin('base','runResults',runResults);

% Set up additional analysis options and perform post-run clean-up %
if ~isempty(runSummary)				% set up Results View summary panel, to be refreshed on tab change
	setappdata(hresults,'newSummary',runSummary);
	setappdata(hresults,'refresh',true);
else
	setappdata(hresults,'refresh',false);
end;
									% add analysis routines to context menu on Results View "Analysis" button
hanalysis = findobj(hresults,'tag','pushbutton_analysis');
hmenu = get(hanalysis,'UIContextMenu');
delete(hmenu);						% clear current menu set and add the default routine
hmenu = uicontextmenu('Parent',hresults);
uimenu(hmenu,'Label','CITest default','Callback',{@resultsview_default_Callback,expgui,mainParam,ctrlParam,runOutput});

if ~isempty(menuEntry)				% add custom routines to analysis menu, if defined in _ProcessExtra() above
	for i = 1:length(menuEntry)
		if ischar(menuEntry{i})
			uimenu(hmenu,'Label',menuEntry{i},'Callback',menuEntry{i});
		end;
	end;
end;
set(hanalysis,'UIContextMenu',hmenu);

set(hObject,'Enable','On');			% re-enable or re-disable various buttons and features
set([hanalysis handles.demomode_menu handles.seebedcs_togglebutton],'Enable','On');
set(handles.pause_pushbutton,'Enable','Off');

% Save the results of the experiment %
if ~handles.fileinfo.autosave || ~runResults.complete
  qsave = questdlg('Save results and experiment info to file?','Request to save','Yes');
  if strcmp(qsave,'No')
	fprintf(1,'Results not saved to file (but they are available in the workspace).\n\n');
	runInfo.savedfile = '';
	assignin('base','runInfo',runInfo);
	return;							% if results aren't saved, run number will not be incremented
  end;
end;
if exist(filestr,'file')
  savingfile = uiputfile('.mat','File name conflict. Choose a new file name.',filestr);
  if savingfile						% deal with naming conflicts (unlikely given inclusion of a time stamp!)
	filestr = fullfile(handles.fileinfo.directory,savingfile);
	runInfo.savedfile = filestr;
	assignin('base','runInfo',runInfo);
  end;
end;

if ~exist(handles.fileinfo.directory,'dir')
	mkdir(handles.fileinfo.directory);
	fprintf(1,'Session directory {%s} created.\n',handles.fileinfo.directory);
end;

saveCell = {'runInfo','stimInfo','runResults'};
save(filestr,saveCell{:});			% save results to a uniquely named m-file
fprintf(1,'Results saved to file %s.\n\n',filestr);
									% store the basic information about this run, then increment run number
handles.runHistory(handles.runnumber) = {runInfo};
handles.runnumber = handles.runnumber + 1;
set(handles.run_edittext,'String',sprintf('%02.0f',handles.runnumber),'UserData',handles.runnumber);

CITest_UpdateFileName(handles,0);	% update file name with new run number for NEXT time; stores 'handles'

% #### end of start_pushbutton_Callback ###############################################################


% --- Handle calls to the Experiment Type popup menu --- %
function exp_popup_Callback(hObject, eventdata, handles) 

expchoice = get(hObject,'Value');
if expchoice~=get(hObject,'UserData')	% avoid double callback execution in older MATLAB versions
	CITest_SetupStimParam(hObject,[],handles);
	set(hObject,'UserData',expchoice);
end;


% --- Handle calls to the Experiment Subtype popup menu --- %
% Update the subtype of experiment and initialize the Pulse Settings subGUI tool.
% As of CITest version 1.24, I am only allowing the standard pulse train choice in this menu.
% The main reason is that the time base is reset, and its potential incompatibility with
% pulse rate is not currently checked.
function subexp_popup_Callback(hObject, eventdata, handles)

subtypeStr = get(hObject,'String'); subtypeval = get(hObject,'Value');
if subtypeval ~= 1						% ##2016.06.01: for the time being, only one option is available in the subexp menu
	hw = warndlg('Non-standard "sub-experiment" pulse types are not currently supported.','Subexp Non-functioning','modal');
	set(hObject,'Value',1);
	uiwait(hw);
	return;
end;

if strcmp(subtypeStr{subtypeval},handles.mainParam.subtype);
	return;											% avoid double callback execution in older MATLAB versions
end;

handles.mainParam.subtype = subtypeStr{subtypeval};
expgui = handles.mainParam.expgui;
													% determine new pulse type for this experiment subtype
[pulsetype,dataUI,tbase] = feval(expgui,'CITest_Exp_GetPulseInfo',handles,handles.mainParam.subtype);
pulseInput.type = pulsetype; pulseInput.dataUI = dataUI; pulseInput.tbase = tbase;
[pulseUI,tbase] = CITest_PulseOptions([],pulseInput); % initialize UI settings, without opening subGUI

bgcol = get(handles.setuppulse_pushbutton,'BackgroundColor');
set(handles.setuppulse_pushbutton,'BackgroundColor',[.827 .71 .82]);

handles.mainParam.pulseSettings.type = pulsetype;
handles.mainParam.pulseSettings.tbase = tbase;
handles.mainParam.pulseSettings.dataUI = pulseUI;
phdur_text_Callback(handles.phdur_text,[],handles);	% this will update new info in 'handles' via GUIDATA

pause(0.1);											% just a color flash to signal an update in pulse info
set(handles.setuppulse_pushbutton,'BackgroundColor',bgcol);


% --- Handle calls to the PAUSE pushbutton --- %
% A button press will automatically suspend the run-time GUI until the controller
% makes a choice to continue or stop.
function pause_pushbutton_Callback(hObject, eventdata, handles)

hrun = getappdata(handles.citest,'hrun');
rungui = getappdata(handles.citest,'rungui');

if ~ishandle(hrun)						% this shouldn't happen... but just in case
	set(hObject,'Enable','Off');
	return;
end;

origcolor = get(hObject,'BackgroundColor');
set(hObject,'BackgroundColor','r');

evalstr = cat(2,rungui,'(''CITest_RunGUI_Pause'',hrun);');
eval(evalstr);							% evoke utility function in the subGUI's m-file to suspend action

qbutton = questdlg('Continue or stop run?','EXPERIMENT PAUSED','CONTINUE','STOP','CONTINUE');
switch qbutton
case 'STOP'
	evalstr = cat(2,rungui,'(''CITest_RunGUI_Stop'',hrun);');
	eval(evalstr);
otherwise
	evalstr = cat(2,rungui,'(''CITest_RunGUI_Unpause'',hrun);');
	eval(evalstr);
end;

set(hObject,'BackgroundColor',origcolor);


% --- Make the Results Window visible during experiment runs --- %
function seeresults_togglebutton_Callback(hObject, eventdata, handles)

hrun = getappdata(handles.citest,'hrun');
if ~ishandle(hrun)			% first make sure whether there is an active runtime GUI
	setappdata(handles.citest,'runactive',false);
end;

hresults = getappdata(handles.citest,'hresults');

toggleval = get(hObject,'Value');
if toggleval				% toggling on allows the Results Window to open during a run
	setappdata(hresults,'display',true);
 	set(hObject,'ForegroundColor',[0 .5 0]);
							% reveal figure (even if run is not active, provides access to run history)
	set(hresults,'Visible','On');
	rhandles = guihandles(hresults);	% force current results to be the displayed tab
	set(rhandles.buttongroup_tab,'SelectedObject',rhandles.radiobutton_current);
	evtData.NewValue = rhandles.radiobutton_current;
	CITest_ResultsViewTabs(rhandles.radiobutton_current,evtData);

	if getappdata(handles.citest,'runactive')
		figure(hrun);		% make sure runtime GUI window still has scope (for key presses, etc)
	end;
else						% toggling off closes the Results Window and prevents it from opening during a run
	setappdata(hresults,'display',false);
 	set(hObject,'ForegroundColor',[.10 .15 .00]);
	set(hresults,'Visible','Off');
	if getappdata(handles.citest,'runactive')
		figure(hrun);
	end;
end;


% --- Make the BEDCS application visible --- %
% Starting with BEDCS version 1.18, if the BEDCS application is made visible, it will automatically
% be put OUT of "U-level" mode (i.e. it will assume U Levels have alread been set) in a way that
% can't be altered in MATLAB.
function seebedcs_togglebutton_Callback(hObject, eventdata, handles)

hactx = CITest_OpenApplication(handles);

toggleval = get(hObject,'Value');
if toggleval
	if ~handles.demomode
		hw = warndlg('WARNING: Making BEDCS visible may crash the experiment.','BEDCS Visible Error','modal');
		uiwait(hw);
	end;
	hactx.Visible = 1; hactx.ULevelMode = 0;
	set(hObject,'ForegroundColor',[0 .5 0]);
else
	hactx.Visible = 0; hactx.ULevelMode = 1;
	set(hObject,'ForegroundColor',[.10 .15 .00]);
end;


% --- Update the top-level directory for saving data --- %
function setdir_pushbutton_Callback(hObject, eventdata, handles)

newdir = uigetdir(handles.fileinfo.directories.top,'Set Top-level Directory');
if ~newdir, return; end;

handles.fileinfo.directories.top = newdir;
[handles.fileinfo.directory, handles.fileinfo.filename] = CITest_CreateFileName(handles,0);
guidata(hObject,handles);

set(handles.filename_text,'String',sprintf('%s\\\n%s',handles.fileinfo.directory,handles.fileinfo.filename));


% --- Handle calls to the subject text field --- %
function subject_edittext_Callback(hObject, eventdata, handles)

inputstr = get(hObject,'String');

if isempty(inputstr)
	valid = false;
else
	idx = regexpi(inputstr, '\w');		% look for all alphabetic, numeric, and underscore characters
	valid = ~isempty(idx);
end;

if ~valid								% if invalid string, revert to last valid one ..
	newstr = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
else
	newstr = inputstr;					% .. otherwise accept it
	newstr = newstr(idx);				% disregard invalid characters
end;

if ~isempty(handles.chanProfileHistory) && ~strcmp(newstr,get(hObject,'UserData'))
	query = questdlg('Changing subject ID will reset the channel profile history. Continue anyway?',...
	  'New Subject or Session','Yes');
	if strcmp(query,'Yes')
		handles.chanProfileHistory = [];
	else
		newstr = get(hObject,'UserData');
	end;
end;

dirstr0 = handles.fileinfo.directories.top;
dirstrE = '';
if isfield(handles.fileinfo.directories,handles.mainParam.exptype)
	dirstrE = handles.fileinfo.directories.(handles.mainParam.exptype);
end;
dirsbj = fullfile(dirstr0,dirstrE,newstr,'');

if ~exist(dirsbj,'dir')
	msgbox('A new directory will be created for this subject.','New Subject','modal');
end;

if handles.runnumber ~= 1
	msgbox('If run # should be 1, it must be manually reset.','Reset Run #','modal');
end;
											% update the displayed and stored strings
set(hObject,'String',newstr,'UserData',newstr);

CITest_UpdateFileName(handles,0);			% update handles and the GUI text field that displays the file name


% --- Handle calls to the session and run text fields --- %
function sessrun_edittext_Callback(hObject, eventdata, handles)

inputval = sscanf(get(hObject,'String'),'%d');

if isempty(inputval), valid = false;
else valid = inputval>=1 && inputval<=999;
end;

if ~valid									% if invalid string, revert to last valid one ..
	newval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
else
	newval = inputval;						% .. otherwise accept it
end;

if hObject==handles.session_edittext && ~isempty(handles.chanProfileHistory) && newval~=get(hObject,'UserData')
	query = questdlg('Changing session # will reset the channel profile history. Continue anyway?',...
	  'New Subject or Session','Yes');
	if strcmp(query,'Yes')
		handles.chanProfileHistory = [];
	else
		newval = get(hObject,'UserData');
	end;
elseif hObject==handles.run_edittext
	query = questdlg('Run numbers may become duplicated or out of sequence. Continue anyway?',...
	  'Change Run Number','Yes');
	if strcmp(query,'Yes')
		handles.runnumber = newval;
	else
		newval = get(hObject,'UserData');
	end;
end;

if hObject==handles.session_edittext && handles.runnumber ~= 1
	msgbox('If run # should be 1, it must be manually reset.','Reset Run #','modal');
end;
											% format the displayed string, and update the stored code
set(hObject,'String',sprintf('%02.0f',newval),'UserData',newval);

CITest_UpdateFileName(handles,0);			% update handles and the GUI text field that displays the file name


% --- Open the Channel Selection subGUI, for specifiying multiple channels and/or steered channels --- %
function setupactive_pushbutton_Callback(hObject, eventdata, handles)

configStruct = get(handles.config_popup,'UserData');
									% store necessary info from various UI fields
chanSettings.electrode = get(handles.activeelec_popup,'UserData'); % (not identical to start button's 'chanSettings')
chanSettings.configtype = configStruct.type;
chanSettings.configval = get(handles.config1_edittext,'UserData');
chanSettings.alpha = get(handles.config2_edittext,'UserData');

chanSettings.phdur = handles.mainParam.pulseSettings.phdur;
chanSettings.traindur = handles.mainParam.pulseSettings.traindur;
chanSettings.pulserate = handles.mainParam.pulseSettings.pulserate;
chanSettings.ratestr = get(handles.rate_text,'String');
									% create new Ch. Selector subGUI only if one is not already open
hchselect = getappdata(handles.citest,'hchselect');
if isempty(hchselect) || ~ishandle(hchselect)
	hchselect = CITest_ChannelSelector([],'Channel Selector - Primary Channel');
	setappdata(handles.citest,'hchselect',hchselect);
end;

try									% seed subGUI with last saved channel profile, and wait until it returns
	chanProfile = CITest_ChannelSelector('CITest_ChannelSelector_UpdateFields',hchselect,handles.chanProfile,chanSettings);
catch
	chanProfile = [];
end;

if isempty(chanProfile)				% if empty, Channel Selector was cancelled or (*GASP*) an error occurred
	disp('Primary channel settings were not saved.');
	if ishandle(hchselect), set(hchselect,'Visible','Off'); end;
	return;
end;

if ~strcmpi(chanSettings.configtype,'sQP')
	chanProfile.alphatype = 1;		% ignore changes to alpha for pTP and BP modes
	chanProfile.alphaval = 0.5;
	chanProfile.alphavector = 0.5;
end;
									% update the active electrode and alpha UI fields (changeable in Ch. Selector)
set(handles.config2_edittext,'String','','UserData',chanProfile.alphavector);
config2_edittext_Callback(handles.config2_edittext,[],handles);

chanvec_old = get(handles.activeelec_popup,'UserData');
chanvec_new = find(chanProfile.onoff);
set(handles.activeelec_popup,'Value',17,'UserData',chanvec_new); % (value = 17 is a safe default)
checkchan = length(chanvec_new)==length(chanvec_old) && all(chanvec_new==chanvec_old);
if checkchan						% don't reset start/max levels if channel set didn't change
	activeelec_popup_Callback(handles.activeelec_popup,0,handles);
else
	activeelec_popup_Callback(handles.activeelec_popup,[],handles);
end;

handles.chanProfile = chanProfile;	% overwrite the old profile and backup the new one (for current CITest session)
nProfile = length(handles.chanProfileHistory);
if ~nProfile
	handles.chanProfileHistory = chanProfile;
else
	handles.chanProfileHistory(nProfile+1) = chanProfile;
end;
guidata(hObject,handles);


% --- Handle calls to the configuration UI components --- %
% Currently, only the partial tripolar and steered quadrupolar configurations are supported.
% Note that the parameter "alpha" is interpreted differently for these two configurations.
% For pTP, alpha = 0.5 is centered on the active electrode; for sQP, alpha = 1.0 is centered.
function config_popup_Callback(hObject, eventdata, handles)

configStr = get(hObject,'String');	% for convenience, store config mode in 'UserData'
configtype = configStr{get(hObject,'Value')};

configStruct = get(hObject,'UserData');
configStruct.type = configtype;		% configuration type is changed with no validity checks
set(hObject,'UserData',configStruct);

alphaok = false;

switch configtype					% update text label for config code
case 'pTP'
	configlabel = 'Sigma';			% current steering is not supported with pTP (alpha = 0.5)
case 'sQP'
	configlabel = 'Sigma';			% current steering is supported via the Channel Select menu
	alphaok = true;
case 'BP'
	configlabel = 'BP sep.';
end;

if alphaok							% revert to default alpha values
	set(handles.config2_edittext,'String','1.00','UserData',1.0,'Enable','On');
else
	set(handles.config2_edittext,'String','0.50','UserData',0.5,'Enable','Off');
end;
									% force call to CONFIG1_EDITTEXT to set last valid code
set(handles.configlabel1_text,'String',configlabel); % this also checks active electrode and updates file name
config1_edittext_Callback(handles.config1_edittext, 1, handles);


% The spatial selectivity parameter, either sigma for pTP and sQP or electrode separation for BP %
function config1_edittext_Callback(hObject, eventdata, handles)

configval = get(hObject,'String');	% the unprocessed string appearing in the text field

configStruct = get(handles.config_popup,'UserData');
configtype = configStruct.type;

aelec = get(handles.activeelec_popup,'UserData');
aelec_min = min(aelec);				% 'aelec' can be a vector, if multiple electrodes are defined (in Channel Selector)
aelec_max = max(aelec);

switch configtype					% process the 'configval' string according to the configuration mode 'configtype'
case 'pTP'
	configval = sscanf(configval,'%f');
	if isempty(configval), valid = false;
	else valid = configval>=0 && configval<=1;
	end;
	if configval > 0				% make sure flanking electrodes are available
		valid = valid && (aelec_min-1)>=1 && (aelec_max+1)<=16;
	end;
	strformat = '%.2f';
case 'sQP'
	configval = sscanf(configval,'%f');
	if isempty(configval), valid = false;
	else valid = configval>=0 && configval<=1;
	end;
	if configval > 0				% one extra apical electrode compared to 'pTP' above
		valid = valid && (aelec_min-2)>=1 && (aelec_max+1)<=16;
	end;
	strformat = '%.2f';
case 'BP'							% electrode separation is one more than written integer value
	configval = sscanf(configval,'%d'); % (e.g. val = 1 for "BP+1" which is a separation of TWO electrodes)
	if isempty(configval), valid = false;
	else valid = configval>=0 && configval<=6 && (aelec_min-configval-1)>=1;
	end;							% make sure most apical return electrode is available
	strformat = '%+2d';
end;

if ~isempty(eventdata) || ~valid	% if callback was evoked by CONFIG_POPUP (see above) OR current value is invalid
	configval = configStruct.(configtype); % use instead the last valid value for the current configuration mode
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;
									% format the displayed string, and update the stored code
set(hObject,'String',sprintf(strformat,configval),'UserData',configval);
									% also update the stored value for the "last valid code"
configStruct.(configtype) = configval;
set(handles.config_popup,'UserData',configStruct);
									% check active electrode, and if invalid set it to a safe electrode (8)
activeelec_popup_Callback(handles.activeelec_popup,8,handles) % also reset file name and current lvl, with GUIDATA() call


% The steering parameter, alpha %
function config2_edittext_Callback(hObject, eventdata, handles)

inputstr = get(hObject,'String');
newval = sscanf(inputstr,'%f');

if isempty(newval)
	valid = false;
else
	valid = newval >= 0 && newval <= 1;
end;

if ~valid						% if new value is invalid, use instead the last valid value
	newval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

if length(newval) >  1			% vector values of 'alpha' are indicated by the display text "range"
	newstr = 'range';
	tipstr = sprintf('%d values from %.1f to %.1f',length(newval),newval(1),newval(end));
else
	newstr = sprintf('%.2f',newval);
	tipstr = '';
end;
set(hObject,'String',newstr,'UserData',newval,'TooltipString',tipstr);


% --- Handle changes to the active electrode popup menu --- %
% Currently, this assumes there are exactly 16 electrode channels. 
function activeelec_popup_Callback(hObject, eventdata, handles)

oldelec = get(hObject,'UserData');	% this could be a scalar or vector (the latter if set in Channel Selector)
newval = get(hObject,'Value');

if newval <= 16						% for most cases, the menu entry order is identical to the channel number
	newelec = newval;
else								% if user chooses the menu entry "multiple", resort to the stored electrode value
	newelec = oldelec;
end;
aelec_min = min(newelec);			 % 'aelec' can be a vector, if multiple electrodes are defined (in Channel Selector)
aelec_max = max(newelec);

configStruct = get(handles.config_popup,'UserData');
configtype = configStruct.type;
configval = get(handles.config1_edittext,'UserData');

switch configtype					% acceptable electrode channel depends on configuration
case 'pTP'
	if configval>0
		valid = (aelec_min-1)>=1 && (aelec_max+1)<=16;
	else
		valid = aelec_min>=1 && aelec_max<=16;
	end;
case 'sQP'
	if configval>0
		valid = (aelec_min-2)>=1 && (aelec_max+1)<=16;
	else
		valid = (aelec_min-1)>=1 && aelec_max<=16;
	end;
case 'BP'
	valid = aelec_min-configval-1>=1 && aelec_max<=16;
end;

if ~valid && ~isempty(eventdata)
	newelec = eventdata;
	newval = 17;
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
elseif ~valid
	newelec = oldelec;
	newval = 17;
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

if newval>16 && length(newelec)==1
	newval = newelec;				% don't display "multiple" if electrode value is just a scalar
end;

if length(newelec) > 1
	elecstr = sprintf('%d ',newelec);
	tipstr = sprintf('%d electrodes chosen: [ %s]',length(newelec),elecstr);
else
	tipstr = '';
end;

set(hObject,'Value',newval,'UserData',newelec,'TooltipString',tipstr);

CITest_UpdateFileName(handles,0);			% GUIDATA() is called here

if ~(~isempty(eventdata) && eventdata==0)	% set current level to minimum for safety, unless suppressed via input argument
	feval(handles.expHandles.expgui,'CITest_Exp_ResetLevel',handles);
end;


% --- Populate and launch the Pulse Modification subGUI --- %
function setuppulse_pushbutton_Callback(hObject, eventdata, handles)
							% launch subGUI with UI settings stored in 'pulseSettings' and wait for subGUI to return
pulseUI = CITest_PulseOptions(hObject,handles.mainParam.pulseSettings);
handles.mainParam.pulseSettings.dataUI = pulseUI;
							% force validity of other pulse parameters (calls GUIDATA); no need to reset level
phdur_text_Callback(handles.phdur_text,0,handles); % so 'eventdata' argument = 0


% --- Handles changes to the "Phase duration" text field --- %
% The phase duration value will always be a multiple of the current "time base", or frame rate.
% For pulse trains, the time base is ~10.7 usec; for single pulses, it can be a factor of 12 lower.
% See CITEST_PULSEOPTIONS for 'tbase' settings of standard pulse types.
% Note that a call to this function also forces pulse rate and train duration to update.
% Because of this, it serves as the de facto manner to update the main CITEST pulse parameters
% following any changes made in the Pulse Modification subGUI (which handles additional pulse
% parameters like interphase gap). 
%	By default, evoking this function will force a resetting of levels (via a call to the experiment
% m-file). The reset can be prevented by setting 'eventdata' to a nonempty value.
function phdur_text_Callback(hObject, eventdata, handles)

phval = sscanf(get(hObject,'String'),'%f');
pulseSettings = handles.mainParam.pulseSettings;
								% force phase duration to be a multiple of the time base
phframes = round(phval/pulseSettings.tbase);
phval = pulseSettings.tbase * phframes;

if isempty(phval)
	valid = false;
else							% check against phase duration limits (but no longer rate)
	valid = phval>=0 && phval<=handles.deviceProfile.phaselimit;
end;

if ~valid						% if new value is invalid, use instead the last valid value
	phval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;
								% update the stored phase info and format the displayed string
[plsframes,ipframes] = CITest_PulseOptions([],pulseSettings,phframes);

pulseSettings.phframes = phframes;
pulseSettings.plsframes = plsframes;
pulseSettings.ipframes = ipframes;
pulseSettings.phdur = phval;
if isempty(ipframes)			% for single pulses, treat pulse rate and train duration as special cases
	pulseSettings.pulserate = 0;
	pulseSettings.numpulses = 1;
	pulseSettings.traindur = 0;
end;

handles.mainParam.pulseSettings = pulseSettings;
guidata(hObject,handles);

tipstr = sprintf('# of pulse entries is %d (time base is %0.3f usec)',plsframes,pulseSettings.tbase);
set(hObject,'String',sprintf('%.1f',phval),'UserData',phval,'ToolTipString',tipstr);
								
if isempty(ipframes)			% for single pulses, turn off the rate and duration UI elements
	set([handles.rate_text handles.traindur_text],'String','--','Enable','Off');
	if ~isempty(handles.mainParam.expgui) && isempty(eventdata)
		feval(handles.mainParam.expgui,'CITest_Exp_ResetLevel',handles);
	end;
else							% .. otherwise update displayed values for pulse train rate and duration
	set([handles.rate_text handles.traindur_text],'String','','Enable','On');
    if ischar(eventdata)        % special case when iterating from a 'tbase' change made in RATE_TEXT_CALLBACK
        set(handles.rate_text,'String',eventdata);
    end;
	rate_text_Callback(handles.rate_text,eventdata,handles);
end;


% --- Handle changes to the "Pulse rate" text field --- %
% The minimum allowed pulse period is 2 times the current value of 'pulseSettings.plsframes', which
% itself was determined in PHDUR_TEXT_CALLBACK. For simple biphasic pulses, this limit corresponds to
% one cathodic and one anodic phase plus an equal number of interpulse zero-amplitude phases. (In other
% words, the duty cycle can't be more than 0.5.) The key value is 'ipframes', the number of
% zero-amplitude time frames in between pulses, which is stored in 'pulseSettings.ipframes'.
% If the pulse type is for a single pulse, pulse train rate is undefined and the UI disabled.
function rate_text_Callback(hObject, eventdata, handles)

ratestr = get(hObject,'String');
rateval = sscanf(ratestr,'%f');

pulseSettings = handles.mainParam.pulseSettings;
tbase = pulseSettings.tbase;			% most recently calculated # of time frames per pulse
tbase_init = pulseSettings.tbase_init;
plsframes = pulseSettings.plsframes;

pulseperiod = (1./rateval) * 1e6;		% in units of usec; this will be adjusted to nearest time frame below
minperiod = plsframes*tbase_init * 2;	% maximum pulse rate corresponds to a 1:1 duty cycle
maxperiod = 2 * 1e6;					% 2 second maximum period corresponds to maximum train duration

if isempty(rateval)
	valid = false;
else
	valid = pulseperiod<=maxperiod && pulseperiod>=minperiod;
end;

if ~valid && pulseSettings.pulserate==0;
	pulseperiod = (1./get(hObject,'UserData')) * 1e6;
elseif ~valid						% if new value is invalid, use instead the last valid value OR a default
	pulseperiod = (1./pulseSettings.pulserate) * 1e6;
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;
                                    % increase time base if the number of total elements is too large
if valid && pulseperiod/tbase > 255
	pfact = ceil( (pulseperiod/tbase_init)/256 );
	mfact = ceil(pfact/2)*2;		% get closest even integer that is GREATER THAN or EQUAL to the factor needed to push pp/tbase under 255

    handles.mainParam.pulseSettings.tbase = pulseSettings.tbase_init * mfact;  % note: this should resolve on one loop
	guidata(hObject,handles);
    set(hObject,'ForegroundColor','m'); pause(0.2);
	set(hObject,'ForegroundColor','k');
    phdur_text_Callback(handles.phdur_text,ratestr,handles);
    return;							% decrease back to standard time base if a new entered rate allows it
elseif valid && tbase > 1.05*pulseSettings.tbase_init && pulseperiod/pulseSettings.tbase_init < 250
    handles.mainParam.pulseSettings.tbase = pulseSettings.tbase_init;
    guidata(hObject,handles);
    set(hObject,'ForegroundColor','g'); pause(0.2);
	set(hObject,'ForegroundColor','k');
    phdur_text_Callback(handles.phdur_text,ratestr,handles);
    return;
end;
									% calculate final number of interpulse zeros
ipframes = round( (pulseperiod - plsframes*tbase)/tbase );

% if ipframes > 225					% ##SMB: This was my original validity check on pulse table size; 'pulseperiod' is better
%     handles.mainParam.pulseSettings.tbase = pulseSettings.tbase * 1.5;  % note: this should resolve on one loop
%     guidata(hObject,handles);
%     set(hObject,'ForegroundColor','m'); pause(0.2);
% 	set(hObject,'ForegroundColor','k');
%     phdur_text_Callback(handles.phdur_text,0,handles);
%     return;
% elseif tbase > 1.05*pulseSettings.tbase_init
%     testSettings = pulseSettings; testSettings.tbase = testSettings.tbase_init;
% 	testSettings.phframes = round(pulseSettings.phframes
%     phframes = round(phval/pulseSettings.tbase);
% phval = pulseSettings.tbase * phframes;   
%     [plstest,iptest] = CITest_PulseOptions([],testSettings,round(phval/pulseSettings.tbase_init));
% end;
								% store zeros value and update display of the equivalent rate (in pulses/sec)
pulseperiod = (plsframes + ipframes) * tbase;
tipstr = sprintf('# of interpulse zeros is %d',ipframes);
set(hObject,'String',sprintf('%.1f',1/(pulseperiod/1e6)),'UserData',1/(pulseperiod/1e6),'TooltipString',tipstr);

pulseSettings.ipframes = ipframes;
pulseSettings.pulserate = 1/(pulseperiod/1e6);

handles.mainParam.pulseSettings = pulseSettings;
guidata(hObject,handles);
								% update pulse train duration
traindur_text_Callback(handles.traindur_text,eventdata,handles);


% --- Handles changes to the "Pulse train duration" text field --- %
% The train duration value will always be a multiple of the current pulse period, as determined
% by the sum of 'pulseSettings.plsframes' and 'pulseSettings.ipframes'. Both of these values are,
% in turn, updated in the previous callback functions handling pulse phase and pulse train rate.
% Note that by this definition, 10 pulses presented at 100 pulses/sec will span exactly 100 msec.
% If the pulse type is for a single pulse, pulse train duration is undefined and the UI disabled.
function traindur_text_Callback(hObject, eventdata, handles)

durval = sscanf(get(hObject,'String'),'%f');

pulseSettings = handles.mainParam.pulseSettings;
tbase = pulseSettings.tbase;				% most recently calculated # of time frames per pulse
plsframes = pulseSettings.plsframes;
ipframes = pulseSettings.ipframes; 

pulseperiod = plsframes + ipframes;			% base period = during-pulse + inter-pulse durations (= 1/pulserate)
pulseperiod = pulseperiod * tbase * 1e-3;	% convert to msec
durval = pulseperiod * round(durval/pulseperiod); % force train duration to be a multiple of the pulse period

if isempty(durval)
	valid = false;
else
	valid = durval>=pulseperiod && durval<=2000;
end;

if ~valid							% if new value is invalid, use instead the last valid value
	durval = get(hObject,'UserData');
	durval = pulseperiod * round(durval/pulseperiod);
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;
									% update the stored duration value
numpulses = floor(durval/pulseperiod);
tipstr = sprintf('# of pulses is %d',numpulses);
set(hObject,'String',sprintf('%.1f',durval),'UserData',durval,'TooltipString',tipstr);

pulseSettings.numpulses = numpulses;
pulseSettings.traindur = durval;

handles.mainParam.pulseSettings = pulseSettings;
guidata(hObject,handles);

if ~isempty(handles.mainParam.expgui) && isempty(eventdata)
	feval(handles.mainParam.expgui,'CITest_Exp_ResetLevel',handles);
end;								% set current level to minimum, for safety, unless flagged by evtdata


% --- Define the context menus --- %
function runoptions_menu_Callback(hObject, eventdata, handles)


function demomode_menu_Callback(hObject, eventdata, handles)

checkstatus = get(hObject,'Checked');
if strcmpi(checkstatus,'off');
	handles.demomode = true;
	set(hObject,'Checked','on');
else
	handles.demomode = false;
	set(hObject,'Checked','off');
end;

guidata(hObject,handles);


function resetstart_menu_Callback(hObject, eventdata, handles)
							% sometimes UI elements want to do their own thing
set([handles.seebedcs_togglebutton handles.start_pushbutton],'Enable','On');
set(handles.pause_pushbutton,'Enable','Off');
set(handles.demomode_menu,'Enable','On');

setappdata(handles.citest,'runactive',false);

hrun = findall(0,'tag','citest_rungui');
delete(hrun);				% sometimes the run-time GUI window can't be closed

hselect = findall(0,'tag','citest_selectgui');
delete(hselect);			% sometimes the Channel Selector window can't be closed

huipanels = findall(handles.citest,'tag','uipanel');
huipanels = huipanels(huipanels~=handles.expHandles.uipanel);
delete(huipanels);			% error during experiment loading can cause old uipanels to hang around

hresults = getappdata(handles.citest,'hresults');
if ~ishandle(hresults)		% in the rare case that the Results window just disappears
	hresults = CITest_ResultsViewSetup(handles.citest);
	setappdata(handles.citest,'hresults',hresults);
end;
hanalysis = findobj(hresults,'tag','pushbutton_analysis');
hpush = findobj(hresults,'tag','pushbutton_push');
set([hpush hanalysis],'Enable','On');

handles.mainParam.exptype = '';		% reload uipanel and parameters of the current experiment
guidata(hObject,handles);
CITest_SetupStimParam(handles.exp_popup,[],handles);


% -- Handle an attempt to close the GUI figure -- % 
function CITest_CloseFcn(handles)

query = questdlg('Do you wish to close the experiment control panel?', 'Close Request', 'No');

if strcmp(query,'Yes')				% prevent an accidental closure of the GUI window
	hactx = getappdata(handles.citest,'hactx');
	if ishandle(hactx)
		hactx.Visible = 1;			% disconnect from the BEDCS application
		hactx.release;
	end;

	hresults = getappdata(handles.citest,'hresults');
	if ishandle(hresults)			% close the (usually invisible) results window
		delete(hresults);
	end;

	hchselect = getappdata(handles.citest,'hchselect');
	if ishandle(hchselect)
		delete(hchselect);			% close the invisible Channel Selector window
	end;

	closereq;						% finally, close the main figure
end;


% -- Handle key presses for the GUI -- %
% These are the callbacks for the "(Window)KeyPressFcn" and '(Window)KeyReleaseFcn" properties
% of the main GUI figure. Valid keys are "P" for Pause and "R" for Results Window.
function CITest_KeyPress(src,eventdata,hmain)

handles = guidata(hmain);			% in case of external call (e.g. runtime GUI), don't use 'src'
k = eventdata.Key;

switch k
case 'p'							% only pause if the button is enabled
  if strcmpi(get(handles.pause_pushbutton,'Enable'),'on')
	pause_pushbutton_Callback(handles.pause_pushbutton, [], handles);
  end;
case 'r'							% force a toggle of the Results View button
	if strcmpi(get(gco(hmain),'Type'),'uicontrol') && strcmpi(get(gco(hmain),'Style'),'edit')
		return;						% (but skip if the current uicontrol is an edit box)
	end;

	toggleval = get(handles.seeresults_togglebutton,'Value');
	set(handles.seeresults_togglebutton,'Value',~toggleval);
	seeresults_togglebutton_Callback(handles.seeresults_togglebutton, [], handles);
end;



%%%% AUXILIARY FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Initialize 'mainParam' structure and output file name, based on subject info and UI stimulus defaults --- %
% This function serves as the callback to both the main experiment type and runtime mode (it's no longer pegged
% to a uipanel's radio buttons, since version 1.201.)
%
% The current list of recognized experiment types and their associated UI values and ID strings is:
%	1. Threshold			'threshold'
%   2. Max. Comfort Level	'mcl'
%	3. Loudness Balancing	'bal'
%	4. Psych. Tuning Curve	'ptc'
%
function CITest_SetupStimParam(hObject,eventdata,handles)

% Some preliminaries %
mainParam = handles.mainParam;		% load the main stimulus parameter structure

expchoice = get(handles.exp_popup,'Value');
exptype_last = mainParam.exptype;	% keep track if a change in experiment mode was made

% Transfer experiment-specific UI panel to the main GUI figure %
switch expchoice					% set experiment mode		
case 1
	mainParam.exptype = 'threshold'; mainParam.expgui = 'CITest_Exp_Threshold';
	mainParam.expabbr = 'THR';
case 2
	mainParam.exptype = 'mcl'; mainParam.expgui = 'CITest_Exp_Threshold';
	mainParam.expabbr = 'MCL';
case 3
	mainParam.exptype = 'bal'; mainParam.expgui = 'CITest_Exp_Balancing';
	mainParam.expabbr = 'BAL';
case 4
	mainParam.exptype = 'ptc'; mainParam.expgui = 'CITest_Exp_PsychTuningCurve';
	mainParam.expabbr = 'PTC';
otherwise							% if a new radio button isn't supported, default to 'threshold' mode
	hw = warndlg('This experiment type is not yet supported.','Undefined Experiment','modal');
	uiwait(hw);
	set(handles.exp_popup,'Value',1);
	mainParam.exptype = 'threshold'; mainParam.expgui = 'CITest_Exp_Threshold';
	mainParam.expabbr = 'THR';
end;
										
if ~strcmp(mainParam.exptype,exptype_last)
	handles.mainParam = mainParam;		% store the stimulus information thus far

	if ~isempty(handles.expHandles.uipanel) && ishandle(handles.expHandles.uipanel);
		delete(handles.expHandles.uipanel);
	end;								% only do this part if a new experiment is being chosen

	figstr = mainParam.expgui;			% open figure containing the experiment UI panel, but don't display it
	hfig = openfig(figstr,'reuse','invisible');
	hpanel = findobj(hfig,'Tag','uipanel'); % the value for 'expHandles.uipanel' is set here
	handles.expHandles = guihandles(hfig);
										% position the UI panel over the place-holder panel
	panelpos = get(handles.expblank_uipanel,'Position');
	set(hpanel,'Parent',handles.citest,'Position',panelpos);
	close(hfig);						% close the original figure or face the consequences!!

	handles.expHandles.expgui = figstr;	% store the figure name because its m-file's functions are necessary
	handles.fileinfo.autosave = false;	% this defaults to "false" when exp. is changed (to match Manual mode)

	[runmode,runabbr,subtypeStr] = feval(figstr,'CITest_Exp_GetRunMode',handles);
	mainParam.runmode = runmode;		% because experiment GUI's "Opening Function" is skipped
	mainParam.runabbr = runabbr;
										% populate menu with choices of experiment subtype; revert to default
	set(handles.subexp_popup,'String',subtypeStr,'Value',1);
	mainParam.subtype = subtypeStr{1};
										% reset the pulse type info, which will be used in various UI calls
	[pulsetype,tbase,pulseUI] = feval(figstr,'CITest_Exp_GetPulseInfo',handles,mainParam.subtype);
	pulseInput.type = pulsetype; pulseInput.tbase = tbase; pulseInput.dataUI = pulseUI; 
	[pulseUI,tbase] = CITest_PulseOptions([],pulseInput);
										% initialize UI settings, without opening pulse subGUI,
	mainParam.pulseSettings.type = pulsetype; % and update 'pulseSettings' (this is important!)
	mainParam.pulseSettings.tbase = tbase;
    mainParam.pulseSettings.tbase_init = tbase;
	mainParam.pulseSettings.dataUI = pulseUI;
	mainParam.pulseSettings.expgui = figstr;
	handles.mainParam = mainParam;
										% also make sure rate and duration (and time base!) are set properly
	ratestr = get(handles.rate_text,'String');
	phdur_text_Callback(handles.phdur_text,ratestr,handles);
	handles = guidata(hObject);			% above callback evoked GUIDATA, so update 'handles' locally
	mainParam = handles.mainParam;
										% initialize exp subGUI settings, especially the pulse parameters
	feval(figstr,'CITest_Exp_Initialize',handles);
end;

handles.mainParam = mainParam;			% store the stimulus information (again)
CITest_UpdateFileName(handles,0);		% update the displayed file name (and store 'handles' again w/ GUIDATA)

set(handles.start_pushbutton,'Enable','On');


% --- Update the file directory and name, which depends on experiment type, probe channel, etc --- %
function CITest_UpdateFileName(handles,tstamp)

[dirstr, filestr] = CITest_CreateFileName(handles,tstamp);
set(handles.filename_text,'String',sprintf('%s\\\n%s',dirstr,filestr));

handles.fileinfo.directory = dirstr;	% store the result
handles.fileinfo.filename = filestr;

guidata(handles.citest,handles);		% update the handle structure


function [dirstr, filestr] = CITest_CreateFileName(handles,tstamp)

dirstr0 = handles.fileinfo.directories.top;
dirstrE = '';
if isfield(handles.fileinfo.directories,handles.mainParam.exptype)
	dirstrE = handles.fileinfo.directories.(handles.mainParam.exptype);
end;

subjstr = get(handles.subject_edittext,'String');
sesnstr = get(handles.session_edittext,'String');
dirstrSI = subjstr;						% no longer requiring the field string to be a numeral
dirstrSS = sprintf('Session%s',sesnstr);
										% the final directory for writing BEDCS/stim and MATLAB/results files
dirstr = fullfile(dirstr0,dirstrE,dirstrSI,dirstrSS,'');

exp_str = handles.mainParam.expabbr;	% piece together the file name from electrode, configuration, etc
sub_str = handles.mainParam.runabbr;
rnum_str = num2str(handles.runnumber,'%02d');

configStruct = get(handles.config_popup,'UserData');
configtype = configStruct.type;
config = get(handles.config1_edittext,'UserData');
alpha = get(handles.config2_edittext,'UserData');

aelec = get(handles.activeelec_popup,'UserData');
if length(aelec) > 1
	aelec_str = 'XX';					% this is adjusted below if "alpha" steering is set up
else
	aelec_str = num2str(aelec,'%02d');
end;

switch configtype
case 'pTP'
	cfg_lbl = 'PTP';
	if any(alpha~=0.5), aelec_str = [aelec_str 's']; end;
	cfg_str = num2str(config*100,'%03.0f');
case 'sQP'
	cfg_lbl = 'SQP';
	if any(alpha~=1.0), aelec_str = [aelec_str 's']; end;
	cfg_str = num2str(config*100,'%03.0f');
case 'BP'
	cfg_lbl = 'BP';
	cfg_str = num2str(config,'%+2d');
end;

selec_str = '';							% ##2015.09.25: add secondary channel to file name
switch handles.mainParam.exptype
case 'ptc'
  if isfield(handles.expParam,'electrode2')
	selec = handles.expParam.electrode2;
	selec_str = sprintf('-%02d',selec);
  end;
end;

elec_str = cat(2,aelec_str,selec_str);

if tstamp								% get date and run number
	time_str = datestr(now,'yyyymmdd-HHMM');
else
	time_str = cat(2,datestr(now,'yyyymmdd'),'-0000');
end;

filestr = cat(2,exp_str,'-',sub_str,'_',time_str,'_',cfg_lbl,cfg_str,'_');
filestr = cat(2,filestr,'EL',elec_str,'_Run',rnum_str,'.mat');


% --- Determine if current levels for all defined channels are valid --- %
% Note that the input argument 'testParam' can relate to the primary channels (i.e. as defined in 'mainParam')
% or a set of secondary channels (such as masking channels defined in the experiment subGUI). Same with 'lvlProfile'
% (which is 'chanProfile' if it describes the primary channel). With this structure, CITEST_EVALUATELEVELS
% can be used generically, just as the Channel Selector interface can be used to set up channels that have different
% roles (probe, masker, etc). Optional argument 'chgdur' is the effective phase duration to use for calculating
% charge-based current limit; if left undefined, the 'pulseSettings.phdur' value will be used from 'testParam'.
function invalid = CITest_EvaluateLevels(testParam,lvlProfile,cLimits,chgdur)

if isfield(testParam,'electrode2')
	testParam.electrode = testParam.electrode2;	% for secondary channel, just duplicate the field
end;

if nargin < 4
	chgdur = testParam.pulseSettings.phdur;		% grab phase duration from regular settings, unless indicated
end;

phsec = chgdur / 1e6;							% phase duration in seconds, to determine charge-based limit

sigmavec = testParam.configcode(1,:);			% all the other required information
alphavec = testParam.configcode(2,:);
elecvec = testParam.electrode;
levelvec = testParam.level;
maxlevelvec = testParam.maxlevel;

if length(unique(sigmavec)) > 1
	warning('Multiple sigma values are currently not supported by CITest. Only the first value will be used.');
end;
sigmaval = sigmavec(1);

% First analyze the levels themselves %
switch testParam.configtype			% NEW METHOD: now it's the level, not limit, evaluated for sigma and alpha
case 'pTP'
	LvlArray = nan(3,16);
	MaxLvlArray = nan(3,16);
	for i = 2:15					% for compliance, etc, convert to the effective current going through each elec.
	  eind = elecvec==i;
	  if sum(eind)>0				% start with the apical flanking electrodes (1 less than each 'elecvec') ..
		LvlArray(1,i-1) = max( sigmaval/2 * levelvec(eind) );
		MaxLvlArray(1,i-1) = max( sigmaval/2 * maxlevelvec(eind) );
		LvlArray(2,i) = max( levelvec(eind) );					% .. then the center electrodes
		MaxLvlArray(2,i) = max( maxlevelvec(eind) );
		LvlArray(3,i+1) = max( sigmaval/2 *  levelvec(eind) );	% .. then the basal flanking electrodes ..
		MaxLvlArray(3,i+1) = max( sigmaval/2 * maxlevelvec(eind) );
	  end;
	end;
	leveleff = max(LvlArray,[],1);	% .. and finally take the maxium across the different electrode roles
	maxleveleff = max(MaxLvlArray,[],1); % (conveniently, NaNs are igmored by MAX())

	bestmcl = lvlProfile.mcl(elecvec);

case 'sQP'
	LvlArray = nan(4,16);			% repeat for sQP, but with a different number of electrodes
	MaxLvlArray = nan(4,16);
	for i = 3:15
	  eind = elecvec==i;
	  if sum(eind)>0
		LvlArray(1,i-2) = max( sigmaval/2 * levelvec(eind) );
		MaxLvlArray(1,i-2) = max( sigmaval/2 * maxlevelvec(eind) );
		LvlArray(2,i-1) = max( (1-alphavec(eind)) .* levelvec(eind) );
		MaxLvlArray(2,i-1) = max( (1-alphavec(eind)) .* maxlevelvec(eind) );
		LvlArray(3,i) = max( alphavec(eind) .* levelvec(eind) );
		MaxLvlArray(3,i) = max( alphavec(eind) .* maxlevelvec(eind) );
		LvlArray(4,i+1) = max( sigmaval/2 * levelvec(eind) );
		MaxLvlArray(4,i+1) = max( sigmaval/2 * maxlevelvec(eind) );
	  end;
	end;
	leveleff = max(LvlArray,[],1);
	maxleveleff = max(MaxLvlArray,[],1);
									% this assumes MCL was obtained for alpha = 1; ignore apical ctr elec if alpha = 1
	bestmcl = lvlProfile.mcl(elecvec-1).*(1-alphavec) + lvlProfile.mcl(elecvec).*alphavec; % (in case of NaN value)
	bestmcl(alphavec==1) = lvlProfile.mcl(elecvec(alphavec==1)).*alphavec(alphavec==1);

otherwise % BP %
	sep = sigmaval + 1;				% for BP, translate config. code to separation, not sigma
	LvlArray = nan(2,16);
	MaxLvlArray = nan(2,16);
	for i = 2:16
	  eind = elecvec==i;
	  if sum(eind)>0				% start with the apical electrode of the pair ..
		LvlArray(1,i-sep) = max( levelvec(eind) );
		MaxLvlArray(1,i-sep) = max( maxlevelvec(eind) );
		LvlArray(2,i) = max( levelvec(eind) );			% .. then the basal electrode
		MaxLvlArray(2,i) = max( maxlevelvec(eind) );
	  end;
	end;
	leveleff = max(LvlArray,[],1);	% .. and finally take the maxium across the different electrode roles
	maxleveleff = max(MaxLvlArray,[],1); % (conveniently, NaNs are igmored by MAX())

	bestmcl = lvlProfile.mcl(elecvec);
end; % switch .configtype %

% Then compare levels to various limits %
limit_compliance = lvlProfile.compliance; % this is a vector, one for each electrode

limit_default = (cLimits.TPdefault-cLimits.MPdefault)*sigmaval + cLimits.MPdefault;
limit_absolute = cLimits.absolute;		% these are scalar, being the same for every electrode
limit_charge = cLimits.charge/phsec;	% charge limit converted to current limit for known phase duration

limit_mcl = bestmcl;					% this is a vector, one for each channel (elec + config)

invalid_abs = (leveleff > limit_absolute) | (maxleveleff > limit_absolute);
invalid_chg = (leveleff > limit_charge) | (maxleveleff > limit_charge);
invalid_cmp = (leveleff > limit_compliance) | (maxleveleff > limit_compliance);
invalid_mcl = (levelvec > limit_mcl*1.10) | (maxlevelvec > limit_mcl*1.10);
invalid_def = (levelvec > limit_default) | (maxlevelvec > limit_default);

if any(invalid_abs)					% apply the various current limits, in order of criticalness
	warndlg('Level for one or more channels is above the maximum allowable current for the device.');
elseif any(invalid_chg)
	warndlg('Level for one or more channels is above the charge-based current limit for .12 mm^2 electrodes.');
elseif any(invalid_cmp)
	highelec = find(invalid_cmp); highelec = highelec(1);
	wstr = sprintf('Level for active electrode %d, and possibly others, is above the compliance limit.',highelec);
	warndlg(wstr);
elseif any(invalid_mcl)				% this logic expression is robust to NaN entries for MCL
	highelec = elecvec(invalid_mcl); highelec = highelec(1);
	wstr = sprintf('Level for channel %d, and possibly others, is 10 percent or more above the listed MCL.',highelec);
	wstr = cat(2,wstr,' Press YES to continue with run.');
	query = questdlg(wstr,'Possible High Current','No');
	if strcmp(query,'Yes')			% sometimes, going above MCL is OK
		invalid_mcl = false;
		invalid_def = false;
	end;
elseif any(invalid_def)
% 	highelec = find(invalid_def); highelec = highelec(1);
% 	wstr = sprintf('Level for channel %d, and possibly others, is above the typical MCL.',highelec);
	highidx = find(invalid_def); highidx = highidx(1);
	wstr = sprintf('Level for channel %d, and possibly others, is above the typical MCL.',elecvec(highidx));
	wstr = cat(2,wstr,' Press YES to continue with run.');
	query = questdlg(wstr,'Possible High Current','No');
	if strcmp(query,'Yes')
		invalid_def = false;
	end;
end;
									% keep track of each channel's status
invalid = invalid_abs | invalid_chg | invalid_cmp | any(invalid_mcl | invalid_def);


% --- Open the correct version of BEDCS based on the user settings --- %
function hactx = CITest_OpenApplication(handles)

hactx = getappdata(handles.citest,'hactx');
if isempty(hactx) || ~ishandle(hactx)	% initialize the BEDCS application
	appstr = handles.bedcsinfo.actx;
	hactx = actxserver(appstr);
	setappdata(handles.citest,'hactx',hactx);
end;


% --- Interpret string instructions for setting relative current level (e.g. re: threshold or MCL) --- %
% This function returns a valid version of a level "code" if the input string can be interpreted,
% as well as a structure containing instructions for setting the current level;
% otherwise it returns an empty matrix. Valid code types are threshold
% (indicated by the string 'thr'), maximum comfort level ('mcl'), and percent dynamic range ('pdr').
% The first of these basis strings to occur, in the order written here, is taken as
% the code type. Following the code type is a number giving the offset (from mcl or thr, signed)
% or value (of dr, unsigned) to set the level in a channel-specific manner. Finally, a units code
% for the offset/value number is expected. For mcl and thr, it can be 'uA', 'dB', or '%'
% (defined on the linear uA scale, as percent of base current); for dynamic range, it can be either
% 'uA' or 'dB', interpreted as a percent within the range between thr and mcl. In all cases, if the
% unit is not specified it's assumed to be 'uA'.
%	Note that a validity check to make sure a threshold or mcl exists for the given electrode is not
% made until the START button is pressed in CITEST.
%	As of 9/02/2013, UI controls that invoke this function can be found in CITEST_EXP_THRESHOLD.M.
function levelCode = CITest_ParseLevelCode(src,inputstr)

levelCode = [];
if isempty(inputstr) || ~ischar(inputstr)
	return;
end;

idxBases = regexpi(inputstr,{'thr','mcl','pdr','cmp'});
[idxnum_a,idxnum_b] = regexpi(inputstr,'[0-9]*\.?[0-9]*');
idxUnits = regexpi(inputstr,{'ua','db','%'});

if ~isempty(idxBases{1})
	basestr = 'thr';
elseif ~isempty(idxBases{2})
	basestr = 'mcl';
elseif ~isempty(idxBases{3})
	basestr = 'pdr';
elseif ~isempty(idxBases{4})
	basestr = 'cmp';
elseif ~isempty(idxUnits{2})	% ##2014.08 new parsing of "dB" entries w/o relative level
	if ~isempty(idxnum_a)
		dbval = str2num(inputstr(idxnum_a(1):idxnum_b(1)));
		numval = 10^(dbval/20);	% convert value from dB to uA
		numstr = sprintf('%0.1f',numval);
		numval = str2num(numstr);
		levelCode = numval;		% output is a number, not a structure, in this case
	end;
	return;
else
	return;
end;

if ~isempty(idxnum_a)
	numval = str2num(inputstr(idxnum_a(1):idxnum_b(1)));
	numstr = sprintf('%0.1f',numval);	% keep and show one decimal place for current levels
	numval = str2num(numstr);

	if idxnum_a(1)>1					 % look for a possible negative sign preceding the number
		idxneg = regexpi(inputstr(1:idxnum_a(1)-1),'-');
	else
		idxneg = [];
	end;								% percent dynamic range is always a positive number
	if ~isempty(idxneg) && ~strcmp(basestr,'pdr')
		numval = -1 * numval;
		numstr = ['- ' numstr];
	elseif ~strcmp(basestr,'pdr')
		numstr = ['+ ' numstr];
	else
		numstr = ['+ ' numstr '%'];
	end;
else
	numstr = '+ 0';
	numval = 0;
end;

if ~isempty(idxUnits{1})
	unitstr = 'ua';
elseif ~isempty(idxUnits{2})
	unitstr = 'db';
elseif ~isempty(idxUnits{3}) && strcmp(basestr,'pdr')
	unitstr = 'ua';
elseif ~isempty(idxUnits{3})
	unitstr = '%';
else
	unitstr = 'ua';
end;

levelCode.base = basestr;
levelCode.value = numval;
levelCode.unit = unitstr;
levelCode.codestr = cat(2,basestr,' ',numstr,' ',unitstr);


% --- Transform a level code (as defined in above function) and channel definitions to actual levels --- %
% There will be one level for every defined channel (i.e. electrode + configuration combo). If threshold
% or mcl is not defined for a channel (because there is no corresponding entry in the associated electrode's
% Channel Selector threshold or mcl field, OR that of its steering neighbor), then that entry for 'levelvec'
% will be NaN.
function levelvec = CITest_InterpretLevelCode(levelCode,chSettings,cLimits)

nChan = length(chSettings.electrode);
levelvec = nan(1,nChan);		% initialize to "no valid levels"

eidx = chSettings.electrode;
if any(chSettings.threshold > chSettings.mcl)
	return;						% no weirdness... just move on
end;

deltaval = levelCode.value; baselvl_unit = levelCode.unit;
newlvl_elec = nan(1,16);

switch levelCode.base
case 'thr'
	if any(isnan(chSettings.threshold(eidx)))
	  return;					% check that threshold settings are valid
	elseif strcmp(baselvl_unit,'db')
	  newlvl_elec = 20*log10(chSettings.threshold) + deltaval;
	  newlvl_elec = 10.^(newlvl_elec/20);
	elseif strcmp(baselvl_unit,'%')
	  newlvl_elec = chSettings.threshold * (100+deltaval)/100;
	elseif strcmp(baselvl_unit,'ua')
	  newlvl_elec = chSettings.threshold + deltaval;
	end;
case 'mcl'
	if any(isnan(chSettings.mcl(eidx)))
	  return;					% check that mcl settings are valid
	elseif strcmp(baselvl_unit,'db')
	  newlvl_elec = 20*log10(chSettings.mcl) + deltaval;
	  newlvl_elec = 10.^(newlvl_elec/20);
	elseif strcmp(baselvl_unit,'%')
	  newlvl_elec = chSettings.mcl * (100+deltaval)/100;
	elseif strcmp(baselvl_unit,'ua')
	  newlvl_elec = chSettings.mcl + deltaval;
	end;
case 'pdr'
	if any(isnan(chSettings.threshold(eidx))) || any(isnan(chSettings.mcl(eidx)))
	  return;					% check that threshold settings are valid
	elseif strcmp(baselvl_unit,'db')
	  dynrng = 20*log10(chSettings.mcl) - 20*log10(chSettings.threshold);
	  newlvl_elec = 20*log10(chSettings.threshold) + (deltaval/100)*dynrng;
	  newlvl_elec = 10.^(newlvl_elec/20);
	elseif strcmp(baselvl_unit,'ua')
	  dynrng = chSettings.mcl - chSettings.threshold;
	  newlvl_elec = chSettings.threshold + (deltaval/100)*dynrng;
	end;
case 'cmp'
	if any(isnan(chSettings.compliance(eidx)))
	  return;					% check that compliance settings are valid
	elseif strcmp(baselvl_unit,'db')
	  newlvl_elec = 20*log10(chSettings.compliance) + deltaval;
	  newlvl_elec = 10.^(newlvl_elec/20);
	elseif strcmp(baselvl_unit,'%')
	  newlvl_elec = chSettings.compliance * (100+deltaval)/100;
	elseif strcmp(baselvl_unit,'ua')
	  newlvl_elec = chSettings.compliance + deltaval;
	end;

	chglimit = cLimits.charge/(chSettings.phdur/1e6);
	abslimit = cLimits.absolute; % if levels too high, keep to known limits
	lvllimit = min(chglimit,abslimit);
	newlvl_elec(newlvl_elec>lvllimit) = lvllimit;
end;

newlvl_elec(newlvl_elec<1) = 1;	% convert any values less than 1 uA to 1 uA

alphavec = chSettings.configcode(2,:);

switch chSettings.configtype	% evaulation of level depends on configuration (i.e. one or more electrodes)
case 'pTP'
	levelvec = newlvl_elec(eidx); % for p.tripolar, steering parameter is ignored... so be careful!
case 'sQP'
	lvlbasal = newlvl_elec(eidx); % for q.polar, level is a weighted sum of the interpreted level on the two elec.s
	lvlapical = newlvl_elec(eidx-1); % (a NaN for the -1 electrode will propagate to final 'levelvec'; but if
	lvlapical(alphavec==1) = 0;		 % that apical electrode isn't actually used, overwrite the NaN with 0)
	levelvec = (1-alphavec).*lvlapical + alphavec.*lvlbasal;
otherwise % BP %
	levelvec = newlvl_elec(eidx); % for bipolar, steering parameter is not relevant
end;


% --- Perform additional results processing using a custom function, as defined in CITest_UserSettings --- %
% The custom m-file must be set up in CITEST_USERSETTINGS as 'handles.customanalysis.threshold' and so on
% (with the field name depending on the experiment name). The custom m-file executed can either run an analysis
% routine and return the results immediately, or simply set up a menu item accessible from CITest. Or both.
function [runExtra,menuEntry] = CITest_ProcessExtra(runResults,runInfo,stimInfo,customAnalysis)

runExtra = []; menuEntry = [];
maindir = fileparts(runInfo.mfiles.maingui);

 if isfield(customAnalysis,runInfo.experiment)
	mfilestr = customAnalysis.(runInfo.experiment);
	if ~exist(mfilestr,'file')
		mfilestr = fullfile(maindir,mfilestr);
	end;					% append working CITest directory or its root if necessary
	if ~exist(mfilestr,'file')
		mfilestr = customAnalysis.(runInfo.experiment);
		mfilestr = fullfile(maindir,'..',mfilestr);
	end;

	if exist(mfilestr,'file')
	  olddir = pwd;			% best to separate string, as 'feval()' can't handle file names over 63 characters
	  try
		[funcpath,funcfile] = fileparts(mfilestr);
		if exist(funcpath,'dir'), cd(funcpath);
		else cd(fileparts(which(mfilestr)));
		end;				% run analysis and/or define an entry for the Analysis button's context menu
		[runExtra,menuEntry] = feval(funcfile,runResults,runInfo,stimInfo);
	  catch
		disp('The custom analysis function encountered an error.');
		runExtra = 'Custom analysis failed';
	  end;
	  cd(olddir);
	else
	  disp('The custom analysis m-file specified in User Settings was not found.');
	  runExtra = 'Custom analysis m-file was not found';
	end;

end; % if isfield() %


% -- Set up Results View window -- %
% This is called in the Opening Function, as well as after forcing a reset.
% Defines 'runSummary', a structure that stores a running tally of the most recent runs of a particular
% experiment and run mode. The information is used to fill the "Summary" panel of the Results View
% window (see CITEST_RESULTSVIEWTABS).
function hresults = CITest_ResultsViewSetup(hmain)
									% window is initially invisible; pressing [R] button will reveal it
hresults = openfig('CITest_ResultsView.fig','reuse','invisible'); % (two button presses (off then on) may be nec.)

rhandles = guihandles(hresults);	% make "current" (axes) panel visible, and hide the "summary" panel
set(rhandles.uipanel_current,'Visible','On');
set(rhandles.uipanel_summary,'Visible','Off');

hsumset = get(rhandles.uipanel_summary,'Children');
delete(hsumset);					% clear the summary panel of all objects

col = get(rhandles.pushbutton_push,'ForegroundColor');
set(rhandles.pushbutton_push,'ForegroundColor',col);

set(rhandles.buttongroup_tab,'SelectionChangeFcn',@CITest_ResultsViewTabs);
set(rhandles.buttongroup_tab,'SelectedObject',rhandles.radiobutton_current);
									% define the essential 'viewSummary' structure
viewSummary = struct('paramid',{},'paramunits',{},'paramvec',{},'resultsid',{},'resultsunit',{},'resultsvec',{},...
  'exptype',{},'runmode',{},'stimSpecs',{},'runnumber',{},'gridstyle',{},'gridentry',{},'pushtype',{});

setappdata(hresults,'hmain',hmain);	% store important attributes within the subGUI
setappdata(hresults,'display',true);
setappdata(hresults,'refresh',false);
setappdata(hresults,'viewSummary',viewSummary);
setappdata(hresults,'newSummary',viewSummary);

try						% establish key press functionality
	set(hresults,'WindowKeyPressFcn',{@CITest_KeyPress,hmain});
catch
	set(hresults,'KeyPressFcn',{@CITest_KeyPress,hmain});
end;


% -- Other Results View handling and callbacks -- %
function CITest_ResultsViewTabs(src,eventdata)

rhandles = guihandles(src);
hresults = rhandles.citest_resultsview;
hchoice = eventdata.NewValue;

switch hchoice			% reveal panel corresponding to the radio button choice; hide the other one	
case rhandles.radiobutton_current
	set(rhandles.uipanel_current,'Visible','On');
	set(rhandles.uipanel_summary,'Visible','Off');

case rhandles.radiobutton_summary
	if getappdata(hresults,'refresh')
		viewSummary = getappdata(hresults,'viewSummary');
		newSummary = getappdata(hresults,'newSummary');
						% refresh will add or rewrite content on "Summary" panel
		viewSummary = CITest_ResultsViewRefresh(rhandles.uipanel_summary,viewSummary,newSummary);

		setappdata(hresults,'viewSummary',viewSummary);
		setappdata(hresults,'refresh',false);
	end;

	set(rhandles.uipanel_current,'Visible','Off');
	set(rhandles.uipanel_summary,'Visible','On');
end; % switch hchoice %


function updatedSummary = CITest_ResultsViewRefresh(hsummary,viewSummary,newSummary)

% compare stim info
% if match, delete old children (if necessary) and refill or add to panel per instructions
% create new view summary by combining
% if not match, new summary becomes view summary

try				% ##SMB: merging structures and Summary display shown here are just placeholders
	updatedSummary = cat(2,viewSummary,newSummary);
	delete(get(hsummary,'Children'));
	txtstr = sprintf('Number of entries: %d',length(updatedSummary));
	uicontrol(rhandles.uipanel_summary,'Style','Text','String',txtstr,'units','normalized',...
	  'Position',[.2 .5 .25 .05]);
catch
	disp('The new summary data does not conform to the standard structure.');
	hw = warndlg('There was an error processing data for the summary panel.','Summary Error','modal');
	uiwait(hw);
	updatedSummary = viewSummary;
end;


function CITest_ResultsView_CloseFcn(hresults)

hctrl = getappdata(hresults,'hmain');
									% when CITest is open, just make the figure invisible ..
if ~isempty(hctrl) && ishandle(hctrl)
	disp('Results View window has been hidden.');
	set(hresults,'Visible','Off');
else								% .. but if CITest has crashed or was never launched, go ahead and close it
	closereq;						  % (useful if the window was opened by itself, such as for debugging)
end;


% These pushbuttons are in a separate GUI figure, CITest_ResultsView.fig. As such, the
% handles argument will belong to that figure, not CITest.fig.
function resultsview_analysis_Callback(hObject, eventdata, rhandles)

set(hObject,'Units','Pixels','Selected','Off');
pos = get(hObject,'Position');		% the context menu will appear when Analysis button is pressed
jobj = findjobj(hObject); set(jobj,'FocusPainted',0);

hmenu = get(hObject,'UIContextMenu');
set(hmenu,'Position',pos([1 2]),'Visible','On');


function resultsview_push_Callback(hObject, eventdata, rhandles)

% viewSummary.pushtype will determine what happens
% for thr, mcl, bal, make sure that (effective) channel numbers are integers; do this at time of field filling
% highlight values (select AVG fields) to be pushed in the summary window, right after pressing that PUSH button
% ask before pushing, and warn if any Ch Sel. value would be overwritten and/or primary stim parameters would change
% Ch Sel. window will then open, showing pushed values!! At Ch Sel. closure, ask one more time if primary settings
%    should be changed (push updated flag to OK, usually NOTOK); autosave and then fill settings in main CITest

function resultsview_import_Callback(hObject, eventdata, rhandles)

% grab a 'viewSummary' from workspace, created by conforming analysis scripts


% Callback syntax requires the GUI object handle and 'eventdata' as initial arguments.
function resultsview_default_Callback(hObject, eventdata, expgui, mainParam, ctrlParam, runOutput)

fprintf(1,'-- Repeating default analysis --------\n');

feval(expgui,'CITest_Exp_ProcessResults',mainParam,ctrlParam,runOutput);

if isfield(runOutput,'message')				
	fprintf(1,'%s\n--------------------------------------\n',runOutput.message);
end;

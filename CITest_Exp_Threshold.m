function varargout = CITest_Exp_Threshold(varargin)
% Experiment definition for the "Threshold" experiment mode.
%	This utility GUI creates a uipanel used in 'CITest' to specify
% experiment-specific stimuli, and also defines the BEDCS and runtime
% paramters to play those stimuli.
%
% REVISION HISTORY
%	Created on January 11, 2013 by SMB.
%	2013.08.29. Began implementing "thr", "mcl", and other keywords
% for the start and maximum current level fields.
%	2013.09.18. Added fields to implement an extra set of up/down steps, 
% to be used after a set number of reversals.
%	2014.08.01. Stated to overhaul code to incorporate the Pulse Modification
% manner of setting pulse phase, rate, and other parameters.
%	2014.08.13. Now, starting and maximum levels won't be reset if the current
% setting is based on a relative level like threshold or MCL.
%	2014.08.20. Single pulse support added for sQP and pTP configurations.
%	2014.09.10. BEDCS definition for the MP configuration is now used as a special case
% for pTP and sQP when sigma = 0. This increases the total number of allowable active
% electrodes. (Version 1.205)
%	2015.02.02. Changing handling of some parameters depending on whether chosen experiment
% is threshold or MCL. Specfically, the directions of current change following a button press
% or release in the channel sweep run mode are opposite.
%

% --- Begin initialization code - DO NOT EDIT --- %
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_Exp_Threshold_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_Exp_Threshold_OutputFcn, ...
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


% --- Executes just before CITest_UIThreshold is made visible --- %
% Because the main CITest GUI opens this subGUI using OPENFIG, this callback is never executed.
function CITest_Exp_Threshold_OpeningFcn(hObject, eventdata, handles, varargin)


% --- Outputs from this function are returned to the command line --- %
% Again, this callback is never executed.
function CITest_Exp_Threshold_OutputFcn(hObject, eventdata, handles) 

% varargout{1} = handles.output;



%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- The mandatory experiment run-mode pulldown menu --- %
% Set generic run-time settings (like "autosave" mode), and toggle exp. menu items on or off.
function [runmode, runabbr] = runmode_popupmenu_Callback(hObject, eventdata, handles)

modeval = get(hObject,'Value');
modeString = get(hObject,'String');
runmode = modeString{modeval};

dir_enable = 'off';
updownstep_enable = 'off'; updownend_enable = 'off';
intvl_enable = 'on'; sweep_enable = 'off';
rev_enable = 'off'; avg_enable = 'off';
autosave = true;

switch runmode					% turn features on or off, as appropriate to the mode
case 'Manual Level'
	runabbr = 'MNL';
	intvl_enable = 'off';
	autosave = false;
case '2-Interval Forced Choice'
	runabbr = '2IFC';
	rev_enable = 'on'; avg_enable = 'on';
	updownstep_enable = 'on'; updownend_enable = 'on';
case '3-Interval Forced Choice'
	runabbr = '3IFC';
	rev_enable = 'on'; avg_enable = 'on';
	updownstep_enable = 'on'; updownend_enable = 'on';
case 'Channel Sweep'
	runabbr = 'SWP';
	sweep_enable = 'on'; dir_enable= 'on';
	updownstep_enable = 'on';
otherwise
	runabbr = 'NIL';
end;

set(handles.expHandles.swdir_popupmenu,'Enable',dir_enable);
set(handles.expHandles.interval_text,'Enable',intvl_enable);
set(handles.expHandles.chanstep_text,'Enable',sweep_enable);
set(handles.expHandles.upstep_text,'Enable',updownstep_enable);
set(handles.expHandles.downstep_text,'Enable',updownstep_enable);
set(handles.expHandles.upstepend_text,'Enable',updownend_enable);
set(handles.expHandles.downstepend_text,'Enable',updownend_enable);
set(handles.expHandles.switchstep_text,'Enable',updownend_enable);
set(handles.expHandles.reversals_text,'Enable',rev_enable);
set(handles.expHandles.averages_text,'Enable',avg_enable);

drawnow;

if strcmpi(updownstep_enable,'on')	% make sure step and average settings are valid re: # reversals
	reversals_text_Callback(handles.expHandles.reversals_text, [], handles);
end;

if isempty(eventdata)			% this invokes GUIDATA, so skip it if called via CITEST_EXP_INITIALIZE
	handles.fileinfo.autosave = autosave;	% (and thereby avoid a CITEST_UPDATEFILENAME loop)
	handles.mainParam.runmode = runmode; handles.mainParam.runabbr = runabbr;
	CITest('CITest_UpdateFileName',handles,0);
end;


% --- Handle changes to the "Starting level" and "Maximum level" text fields --- %
% Only the absolute current limit of the device is imposed in this function. Behavioral-based (dependent on
% configuration) and compliance-based current limits are not imposed until the START button is pressed in CITest.
function levels_text_Callback(hObject, eventdata, handles)

levelstr = get(hObject,'String');
levelval = sscanf(levelstr,'%f'); 
dbflag = regexpi(levelstr,'db');

if isempty(levelval) || ~isempty(dbflag)
	levelCode = CITest('CITest_ParseLevelCode',hObject,levelstr);
	valid = ~isempty(levelCode);
	levelval = levelCode;
else
	valid = levelval>=1 && levelval<=handles.deviceProfile.currentlimit.absolute;
end;

if ~valid							% revert to last field entry if the input is not an acceptable number or code
	levelval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end

if isstruct(levelval)				% update UI properties depending on whether input is a number or a code
	tipstr = 'Variable level';
	set(hObject,'String',levelval.codestr,'UserData',levelval,'TooltipString',tipstr);
else
	tipstr = sprintf('%.1f dB',20*log10(levelval));
	set(hObject,'String',sprintf('%.1f',levelval),'UserData',levelval,'TooltipString',tipstr);
end;


% --- Handle changes to the "Stimulus interval" text field --- %
% This parameter represents the stimulus interval, from the start of one pulse train to the next.
% Entered values are immediately compared to the current pulse train duration AND to the inherent
% processing delay of the hardware AND the 20 msec minimum delay necessary for uploading parameters
% to the hardware.
% A final check against the pulse train duration is made when the START button is pressed.
function interval_text_Callback(hObject, eventdata, handles)

intvlval = sscanf(get(hObject,'String'),'%f');

intvlmin = round( get(handles.traindur_text,'UserData') + handles.deviceProfile.intvldelay );
intvlmax = 5000;					% in msec

if isempty(intvlval)
	valid = false;
else
	valid = intvlval>=intvlmin && intvlval<=intvlmax;
end;

if ~valid
	intvlval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

intvlval = round(intvlval);			% integer values only

set(hObject,'String',sprintf('%.0f',intvlval),'UserData',intvlval);
chanstep_text_Callback(handles.expHandles.chanstep_text,[],handles);


% --- Handle changes to the "Channel Sweep interval" text field --- %
% This parameter represents the duration to play a series of stimuli before moving on to the
% next "block" parameter. Checks are made against the main stimulus interval (above).
% A final check against the pulse train duration is made when the START button is pressed.
function chanstep_text_Callback(hObject, eventdata, handles)

intvlval = sscanf(get(hObject,'String'),'%f');

intvlmin = get(handles.expHandles.interval_text,'UserData');
intvlmax = 20000;					% in msec

if isempty(intvlval)
	valid = false;
else								% force the sweep interval to be a multiple of the stimulus interval
	intvlval = intvlmin * round(intvlval/intvlmin);
	valid = intvlval>=intvlmin && intvlval<=intvlmax;
end;

if ~valid
	intvlval = 4*intvlmin;			% default to four times the stimulus interval
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

intvlval = floor(intvlval);
set(hObject,'String',sprintf('%.0f',intvlval),'UserData',intvlval);


% --- Handle changes to the "Number of Reversals Step/Stop/Avg" text fields --- %
% Stop = end run after that # of reversals reached; Avg = average over that many reversals.
function reversals_text_Callback(hObject, eventdata, handles)

nrev = sscanf(get(hObject,'String'),'%f');
navg = get(handles.expHandles.averages_text,'UserData');
nswitch = get(handles.expHandles.switchstep_text,'UserData');

if isempty(nrev)
	valid = false;
else
	valid = nrev>=1 && nrev<=15;
end;

if ~valid
	nrev = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

nrev = floor(nrev);
set(hObject,'String',sprintf('%.0f',nrev),'UserData',nrev);

if navg > nrev				% if # averages is too high, set it to # reversals
	set(handles.expHandles.averages_text,'String','','UserData',nrev);
	averages_text_Callback(handles.expHandles.averages_text,[],handles);
end;

if nswitch >= nrev			% if step size transition is too high, set it to # reversals
	set(handles.expHandles.switchstep_text,'String','','UserData',nrev);
end;						% either way, run the 'switchstep' callback to update uicontrols
switchstep_text_Callback(handles.expHandles.switchstep_text,[],handles);


function averages_text_Callback(hObject, eventdata, handles)

navg = sscanf(get(hObject,'String'),'%f');
nrev = get(handles.expHandles.reversals_text,'UserData');

if isempty(navg)
	valid = false;			% # averages can't be higher than # reversals
else
	valid = navg>=1 && navg<=nrev;
end;

if ~valid
	navg = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

navg = floor(navg);
set(hObject,'String',sprintf('%.0f',navg),'UserData',navg);


function switchstep_text_Callback(hObject, eventdata, handles)

nswitch = sscanf(get(hObject,'String'),'%f');
nrev = get(handles.expHandles.reversals_text,'UserData');

if isempty(nswitch)
	valid = false;			% # rev.s for changing step size can't be higher than total #
else
	valid = nswitch>=1 && nswitch<=nrev;
end;

if ~valid
	nswitch = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

nswitch = floor(nswitch);
set(hObject,'String',sprintf('%.0f',nswitch),'UserData',nswitch);

if nswitch == nrev			% turn off second set of step sizes for this special case
	set([handles.expHandles.upstepend_text handles.expHandles.downstepend_text],'Enable','Off');
elseif strcmpi(get(handles.expHandles.switchstep_text,'Enable'),'on')
	set([handles.expHandles.upstepend_text handles.expHandles.downstepend_text],'Enable','On');
end;						% and turn on the second set if they normally would be on


% --- This gives the size of current level steps, both up and down, in dB --- %
function updownstep_text_Callback(hObject, eventdata, handles)

udstep = sscanf(get(hObject,'String'),'%f');
intvlsec = get(handles.expHandles.interval_text,'UserData')/1000;

if isempty(udstep)
	valid = false;
else
	valid = udstep>=.01 && udstep<=20;
end;

if ~valid
	udstep = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

tipstr = sprintf('%.2f dB/sec',udstep/intvlsec);
set(hObject,'String',sprintf('%.2f',udstep),'UserData',udstep,'ToolTipString',tipstr);





%%%% ESSENTIAL EXPERIMENT-SPECIFIC FUNCTIONS CALLED FROM CITEST %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- This performs what the Opening Function would have normally --- %
% The main part of this function invokes the internal callback for the runtime mode popup
% menu. Note that file saving mode and updating the CITEST file name is not needed, unlike when
% RUNMODE_POPUPMENU is called from the experiment subGUI itself.
%	Don't store handles using GUIDATA in this function, as the integration of 'expHandles' into
% 'handles' is done within the main CITest GUI.
function [runmode,runabbr,subtypeStr] = CITest_Exp_GetRunMode(handles)

[runmode,runabbr] = runmode_popupmenu_Callback(handles.expHandles.runmode_popupmenu, false, handles);
										% subtype of experiment determines pulse type and other details
subtypeStr = {'Standard Pulse Train','Standard Single Pulse'};


% -- Define and initialize useful variables to be used internally -- %
% At minimum, this should set the description of the primary electrode in the "Stimulus Parameters" panel.
function CITest_Exp_Initialize(handles)
										% required
set(handles.eleclabel_text,'String','Active electrode');

exptype = handles.mainParam.exptype;	% (OK because 'handles.mainParam' was set before call from CITEST)
if strcmpi(exptype,'mcl')				% this particular experiment panel/m-file has dual use
	set(handles.expHandles.uipanel,'Title','MCL Parameters');
end;


% --- Force starting level to be at a low, safe value --- %
% A function with this name is common to all experiment definitions. It is called from the main
% control GUI, CITest.
function CITest_Exp_ResetLevel(handles)

levelval = get(handles.expHandles.startlevel_text,'UserData');
if ~isstruct(levelval)		% don't reset if a relative level is being used
	set(handles.expHandles.startlevel_text,'String','RESET','UserData',1);
	levels_text_Callback(handles.expHandles.startlevel_text, [], handles);
end;

levelval = get(handles.expHandles.maxlevel_text,'UserData');
if ~isstruct(levelval)
	set(handles.expHandles.maxlevel_text,'String','RESET','UserData',9);
	levels_text_Callback(handles.expHandles.maxlevel_text, [], handles);
end;


% --- Outputs the stimulus parameters associated with this utility GUI --- %
% A function with this name is common to all experiment definitions. Note that 'handles' is the structure
% of handles and variables from the MAIN control GUI; use 'handles.expHandles' for UI elements in THIS subGUI.
%	The pulse shape parameters for first-phase polarity and interphase gap should be set here, even if
% the BEDCS experiment doesn't require them.
function [levelParam, expParam] = CITest_Exp_GetParameters(handles,chanSettings,pulseSettings)

modeval = get(handles.expHandles.runmode_popupmenu,'Value');
modeString = get(handles.expHandles.runmode_popupmenu,'String');
runmode = modeString{modeval};
subtype = handles.mainParam.subtype;
								% process level information
startentry = get(handles.expHandles.startlevel_text,'UserData');
startstr = get(handles.expHandles.startlevel_text,'String');
maxentry = get(handles.expHandles.maxlevel_text,'UserData');
maxstr = get(handles.expHandles.maxlevel_text,'String');

cLimits = handles.deviceProfile.currentlimit;

nChan = length(chanSettings.electrode);
if isstruct(startentry)			% handle numeric values and structure "level codes" differently ..
	startlevel = CITest('CITest_InterpretLevelCode',startentry,chanSettings,cLimits);
else
	startlevel = startentry * ones(1,nChan);
end;
if isstruct(maxentry)			% .. either way, ascribe (for now) one level for every defined channel
	maxlevel = CITest('CITest_InterpretLevelCode',maxentry,chanSettings,cLimits);
else
	maxlevel = maxentry * ones(1,nChan);
end;

if any(isnan(startlevel)) || any(isnan(maxlevel))
	levelParam = [];			% force a quick exit if there is an illegal level (due to undefined THR or MCL)
	expParam = 'Check THR and MCL entries of active and flanking electrodes.';
	return;
end;

% if any(startlevel > maxlevel)	% force start level to be no greater than max level, for numeric or code entries
% 	startentry = maxentry;		% a more complete level check for safety is made in CITest
% 	set(handles.expHandles.startlevel_text,'UserData',startentry,'String','');
% 	levels_text_Callback(handles.expHandles.startlevel_text,[],handles);
% end;

switch runmode					% for some run modes, define a level for every defined channel
case {'Channel Sweep','Manual Level'}
	chanidx = 1:nChan;
otherwise						% for others, only one channel is allowed
	configtype = chanSettings.configtype;
	configcode = chanSettings.configcode;
	if strcmp(configtype,'sQP')	% .. in which case, take first non-steered (via alpha) channel if available ..
		chanidx = find(configcode(2,:)==1);
		if isempty(chanidx), chanidx = 1;
		else chanidx = chanidx(1);
		end;
	elseif strcmp(configtype,'pTP')
		chanidx = find(configcode(2,:)==0.5);
		if isempty(chanidx), chanidx = 1;
		else chanidx = chanidx(1);
		end;
	else
		chanidx = 1;			% .. and otherwise take the first defined channel
	end;
end;

levelParam = struct();			% define level parameters
levelParam.value = startlevel(chanidx);
levelParam.maxlimit = maxlevel(chanidx);
levelParam.minlimit = ones(1,length(chanidx));
levelParam.chanidx = chanidx;
levelParam.valuestring = startstr;
levelParam.maxstring = maxstr;

expParam = struct();			% define non-level experiment-specific parameters
expParam.stimintvl = get(handles.expHandles.interval_text,'UserData');
expParam.sweepintvl = get(handles.expHandles.chanstep_text,'UserData');

expParam.nrevswitch = get(handles.expHandles.switchstep_text,'UserData');
expParam.nreversals = get(handles.expHandles.reversals_text,'UserData');
expParam.naverages = get(handles.expHandles.averages_text,'UserData');

expParam.upstep = get(handles.expHandles.upstep_text,'UserData'); % these are unsigned values; "up" and "down"
expParam.downstep = get(handles.expHandles.downstep_text,'UserData'); % refer to levels here, not key press status
expParam.upstepend = get(handles.expHandles.upstepend_text,'UserData');
expParam.downstepend = get(handles.expHandles.downstepend_text,'UserData');

dirString = get(handles.expHandles.swdir_popupmenu,'String');
dirval = get(handles.expHandles.swdir_popupmenu,'Value');
expParam.direction = dirString{dirval};

switch subtype								% define experiment subtype-specific parameters
case {'Standard Pulse Train','Standard Single Pulse'}
	expParam.polarity = 'cathodic';			% these two pulse-shape parameters are mandatory
	expParam.phgap = 0;
otherwise									% for all Threshold sub-experiments, values are fixed
	expParam.polarity = 'cathodic';			  % (otherwise, this would be the place to set these pulse
	expParam.phgap = 0;						  % parameters from 'pulseSettings.dataUI')
end;


% --- Outputs the BEDCS and other parameters necessary to run the experiment associated with this m-file --- %
% A function with this name is common to all experiment definitions. Returned output 'bedcsParam' 
% contains everything required by the BEDCS experiment file, and 'ctrlParam' contains everything necessary
% to control those variables via the runtime subGUI. If either is empty, CITEST won't run the experiment.
function [bedcsParam, ctrlParam] = CITest_Exp_TransformParameters(mainParam,expParam,deviceProfile)

pulseSet = mainParam.pulseSettings;
stimdur = pulseSet.traindur;			% some upfront paperwork
configtype = mainParam.configtype;

if strcmpi(configtype,'pTP') && mainParam.configcode(1,1)==0
	configtype = 'MP';					% ##2015.02.12: simplified by putting more checks in main CITest routine
elseif strcmpi(configtype,'sQP') && mainParam.configcode(1,1)==0
	configtype = 'sMP';
end;

% Set BEDCS Parameters ######################################################### %
bedcsMain = {'IStim'};		% by default, block parameter is the channel (electrode, sigma, alpha)
bedcsBlock = {'elec','sigma','alpha'}; % note: channel info MUST be in alpha order for "Channel Sweep" mode
bedcsBlockValues = {mainParam.electrode,mainParam.configcode(1,:),mainParam.configcode(2,:)};

switch mainParam.subtype	% BEDCS experiment file (and maybe some parameters) depends on experiment subtype
case 'Standard Pulse Train'
	displaystr = 'Pulse Train Threshold (uA)';
							% start with the most typical 'bedcsParam' setup; changes are made below
	bedcsParam = struct('bedcsexp','','nPulses',pulseSet.numpulses,...
	  'elec',mainParam.electrode(1),'sigma',mainParam.configcode(1,1),'alpha',mainParam.configcode(2,1),...
	  'nPhase',pulseSet.phframes,'nZero',pulseSet.ipframes,'IStim',mainParam.level(1));

	switch configtype
	case 'pTP'
		bedcsexp = 'CITest_pulsetrainPTP.bExp';
	case 'sQP'
		bedcsexp = 'CITest_pulsetrainSQP.bExp';
	case 'sMP'				% a dedicated MP definition file allows more electrodes to be defined
		bedcsexp = 'CITest_pulsetrainSMP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma'});
		bedcsBlock = {'elec','alpha'};
		bedcsBlockValues = {mainParam.electrode,mainParam.configcode(2,:)};
	case 'MP'				% a dedicated MP definition file allows more electrodes to be defined
		bedcsexp = 'CITest_pulsetrainMP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma','alpha'});
		bedcsBlock = {'elec'};
		bedcsBlockValues = {mainParam.electrode};
	case 'BP'
		bedcsexp = 'CITest_pulsetrainBP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma','alpha'});
		bedcsParam = setfield(bedcsParam,'sep',mainParam.configcode(1,1)+1);
		bedcsBlock = {'elec','sep'};
		bedcsBlockValues = {mainParam.electrode,mainParam.configcode(1,:)+1};
	otherwise
		bedcsexp = '';
	end;

case 'Standard Single Pulse'
	displaystr = '1-pulse Threshold (uA)';

	bedcsParam = struct('bedcsexp','','elec',mainParam.electrode(1),...
	  'sigma',mainParam.configcode(1,1),'alpha',mainParam.configcode(2,1),...
	  'nPhase',pulseSet.phframes,'IStim',mainParam.level(1));

	switch configtype
	case 'pTP'				% mainly same as with pulse trains
		bedcsexp = 'CITest_singlepulsePTP.bExp';
	case 'sQP'
		bedcsexp = 'CITest_singlepulseSQP.bExp';
	case 'sMP'
		bedcsexp = 'CITest_singlepulseSMP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma'});
		bedcsBlock = {'elec','alpha'};
		bedcsBlockValues = {mainParam.electrode};
	case 'MP'
		bedcsexp = 'CITest_singlepulseMP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma','alpha'});
		bedcsBlock = {'elec'};
		bedcsBlockValues = {mainParam.electrode,mainParam.configcode(2,:)};
	case 'BP'
		bedcsexp = 'CITest_singlepulseBP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma','alpha'});
		bedcsParam = setfield(bedcsParam,'sep',mainParam.configcode(1,1)+1);
		bedcsBlock = {'elec','sep'};
		bedcsBlockValues = {mainParam.electrode,mainParam.configcode(1,:)+1};
	otherwise
		bedcsexp = '';
	end;

otherwise
	displaystr = 'Invalid';
	bedcsexp = '';			% a non-defined BEDCS file will cause CITEST execution to safely terminate

end; % switch mainParam.subtype %

bedcsParam.bedcsexp = bedcsexp;

% Set Control Parameters ################################################################## %
% viewSetup = struct('hfigure',[],'haxes',[],'xlabel',[],'xvalues',[]);
viewSetup = struct('xlabel',[],'xvalues',[]);

intvl = expParam.stimintvl;	% other run-time control parameters
intvldelay = deviceProfile.intvldelay;
blockintvl = expParam.sweepintvl;

switch mainParam.runmode
case 'Manual Level'
	rungui = 'CITest_RunGUI_Manual';

	runSetup.steplabels = {'linear (uA)','log (dB uA)'};
	runSetup.stepsizes = {[1 5 10 20],[.1 .5 2 20*log10(2)]};
	runSetup.stepstart = 2;			% 1 = linear, 2 = log (per above)
	runSetup.stepscale = 1;			% unused right now (might be useful for non-current stimulus variables)
	runSetup.format = '%.1f';		% for display of the stimulus variable
	runSetup.tipunit = 'db';

	intvl = 0; dwell = 0;

	querystr = '';

	if strcmp(mainParam.configtype,'sQP')
		xval = (mainParam.electrode-1) +  mainParam.configcode(2,:);
		xlbl = 'Chan:';
	else
		xval = 1:length(mainParam.electrode);
		xlbl = 'Ch Idx:';
	end;
	viewSetup.xlabel = xlbl;
	viewSetup.xvalues  = xval;

case {'2-Interval Forced Choice','3-Interval Forced Choice'}
	rungui = 'CITest_RunGUI_2IFC';		% 3-IFC gui name and other exceptions are listed below

	runSetup.upstep = expParam.upstep;
	runSetup.downstep = expParam.downstep;
	runSetup.upstepend = expParam.upstepend;
	runSetup.downstepend = expParam.downstepend;
	runSetup.revswitch = min(expParam.nrevswitch,expParam.nreversals);

	runSetup.stepunit = 'db';
	runSetup.stepsign = +1;
	runSetup.upcorrect = 2;				% i.e. a two-up, one-down procedure
	runSetup.downwrong = 1;
	runSetup.offvalues = [0];			% current level is 0 uA for off-interval stimuli

	runSetup.oncolor = [1 1 .4];
	runSetup.offcolor = [.90 .90 0.82];

	runSetup.minstop = 6;
	runSetup.maxstop = 6;
	runSetup.stimstop = 60;

	runSetup.nreversals = expParam.nreversals;
	runSetup.naverages = expParam.naverages; 

	intvl = expParam.stimintvl; dwell = 0;

	querystr = 'Which interval contained the sound?';

	bedcsBlock = {''};					% left empty, the 2-IFC GUI will use the main variable as the interval
	bedcsBlockValues = {[]};

	viewSetup.xlabel = 'Stim #:';
	viewSetup.xvalues  = [];

	if strcmp(mainParam.runmode,'3-Interval Forced Choice')
		runSetup.offvalues = [0 0];		% special conditions for the 3-IFC mode, so it can use the 2IFC m-file
	end;

case 'Channel Sweep'
	rungui = 'CITest_RunGUI_Tracking';
										% distinguish between THR and MCL experiments
	if strcmpi(mainParam.exptype,'threshold')
		querystr = 'Press <SPACEBAR> when you hear the sound. Release when you don''t.';

		runSetup.buttondown.label = '';
		runSetup.buttondown.color = [.77 .87 .77];		% green when button is pressed, orange when not
		runSetup.buttonup.label = '';
		runSetup.buttonup.color = [1.00 .80 .60];
														% rate of variable change (in parameter units per interval)
		runSetup.buttondown.rate = -expParam.downstep;	% LOWER the current when spacebar button is pressed
		runSetup.buttonup.rate = +expParam.upstep;		% RAISE the current when spacebar button is released
		runSetup.rateunit = 'db';
	else % MCL %
		querystr = 'Press <SPACEBAR> when the sound is too soft. Release when it is too loud.';

		runSetup.buttondown.label = '';
		runSetup.buttondown.color = [1.00 0.00 .20];	% red when button is pressed, orange when not
		runSetup.buttonup.label = '';
		runSetup.buttonup.color = [1.00 .80 .60];
														% rate of variable change (in parameter units per interval)
		runSetup.buttondown.rate = +expParam.upstep;	% RAISE the current when spacebar button is pressed
		runSetup.buttonup.rate = -expParam.downstep;	% LOWER the current when spacebar button is released
		runSetup.rateunit = 'db';
	end; % switch exptype %

	runSetup.direction = expParam.direction;	% direction of sweeping, and extra number of '.pad' blocks at start
	runSetup.pad = 12;							% max number of non-sweeping blocks at start (overrides '.padrev')
	runSetup.padrev = 2;						% stop padding after '.padrev' number of reversals
												% time to pause after a stimulus presentation (in msec)
	dwell = round(intvl - intvldelay - stimdur);

	if strcmp(mainParam.configtype,'sQP')
		xval = (mainParam.electrode-1) +  mainParam.configcode(2,:);
		xlbl = 'Elec:';
	else
		xval = 1:length(mainParam.electrode);
		xlbl = 'Ch Idx:';
	end;
	viewSetup.xlabel = xlbl;
	viewSetup.xvalues  = xval;		% for Tracking, one x-value for each defined channel (block)

otherwise							% an empty 'rungui' signifies a non-operational runmode
	rungui = '';

end; % switch mainParam.runmode %

if isempty(rungui)
	ctrlParam = [];
else
	ctrlParam = struct('rungui',rungui,'runSetup',runSetup,'mainVars',{bedcsMain},'maxval',mainParam.maxlevel,...
	  'minval',mainParam.minlevel,'startval',mainParam.level,'blockVars',{bedcsBlock},'blockValues',{bedcsBlockValues},...
	  'displaytext',displaystr,'querytext',querystr,'intvl',intvl,'stimdur',stimdur,'dwell',dwell,...
	  'blockintvl',blockintvl,'viewSetup',viewSetup);
end;


% --- Provide information about pulse parameters depending on the subtype of experiment --- %
% This function works in two modes. Mode 1 returns the name of the pulse type, and possibly
% instructions for the Pulse Modification subGUI, given the subtype of experiment. Mode 2
% returns some information about the pulse train sequence given the number of 'tbase' time
% frames of the primary phase duration. The former mode is called in various places by CITEST;
% the latter mode is called only through CITEST_PULSEOPTIONS (and indirectly from CITEST).
%	Experiment subtypes must match those listed in CITest_Exp_Initialize(). Pulse types
% must match those expected in CITEST_PULSEOPTIONS.
function varargout = CITest_Exp_GetPulseInfo(handles,pulseIn,phframes)

% Mode 1 - string input is the experiment subtype %
if ischar(pulseIn)
	dataUI = [];				% empty if using only standard (non-custom) pulse types
	tbase = [];

	switch pulseIn
	case 'Standard Pulse Train'
		pulsetype = 'Simple Biphasic';
	case 'Standard Single Pulse'
		pulsetype = 'Simple Biphasic 1-Pulse';
	end;

	varargout{1} = pulsetype;
	varargout{2} = tbase;		% for standard pulse types, tbase and UI instr.s defined in CITEST_PULSEOPTIONS
	varargout{3} = dataUI; varargout{2} = tbase;

% Mode 2 - structure input is current pulse information and # of phase time frames %
elseif nargin > 2
	plsframes = []; ipframes = [];

	varargout{1} = plsframes;	% custom pulse info not needed for any Threshold experiment subtypes
	varargout{2} = ipframes;

else
	error('Not enough input arguments.');
end;


% --- Format results from the run-time GUI and create experiment-specific display, if desired ---- %
% For some experiment types, formatting won't need to change compared to the run-time GUI output.
% The main CITest program will use default if there is an error in this function.
% Also, note that the 'runSummary' format must be the same as in CITest_ResultsViewSetup().
function [runResults,runSummary] = CITest_Exp_ProcessResults(mainParam,ctrlParam,runOutput)

runResults = runOutput;								% start with the default outputs

runSummary = struct('paramid','ch','paramunits','#','paramvec',[],'resultsid','current','resultsunit','uA',...
  'resultsvec',[],'exptype',mainParam.exptype,'runmode',mainParam.runmode,'stimSpecs',[],'runnumber',[],...
  'gridstyle','','gridentry',[],'pushtype','threshold');
runSummary.paramvec = [mainParam.electrode - 1 + mainParam.configcode(1,:)];
runSummary.resultsvec = runOutput.results;
runSummary.stimSpecs = {'std-config','std-pulse'};	% checks config and pulse settings; leaves level + chan alone

switch mainParam.runmode

case 'Manual Level'

case {'2-Interval Forced Choice','3-Interval Forced Choice'}
	if isempty(runResults.results)
		disp('Some analysis for ''runResults'' could not be completed.')
		return;
	end;

	figure;
	plot(1:length(runResults.results),runResults.results,'o-');
	hold on;
	revidx = find(runResults.reversals);
	plot(revidx,runResults.results(revidx),'r*');

	avgnum = min(length(revidx),ctrlParam.runSetup.naverages);
	revidx = revidx(end-avgnum+1:end);

	valuesdb = 20*log10(runResults.results);
	avgthrdb = mean(valuesdb(revidx));
	stdthrdb = std(valuesdb(revidx));
	avgthr = 10.^(avgthrdb/20);

	runResults.avgthr = avgthr;
	runResults.avgthrdb = avgthrdb;
	runResults.stdthrdb = stdthrdb;

	fprintf(1,'Average threshold over last %d reversals is %0.1f uA (%0.1f +/- %0.2f dB uA)\n',...
	  avgnum,avgthr,avgthrdb,stdthrdb);
	if sum(runResults.reversals) < ctrlParam.runSetup.nreversals
		fprintf(1,'* Target number of reversals, %d, was not met for this run.\n',ctrlParam.runSetup.nreversals);
	end;
	fprintf(1,'\n');

case 'Channel Sweep'
	if isempty(runResults.results)
		return;
	end;

	if strcmp(mainParam.configtype,'sQP')
		xval = (mainParam.electrode - 1) +  mainParam.configcode(2,:);
	elseif strcmp(mainParam.configtype,'pTP')
		xval = (mainParam.electrode - 0.5) +  mainParam.configcode(2,:);
	else % BP %
		xval = mainParam.electrode;
	end;

	fwdind = runResults.blockdir==+1; revind = runResults.blockdir==-1;
	fwdblock = runResults.blockidx(fwdind); revblock = runResults.blockidx(revind);

	figure;
	plot(xval(fwdblock),runResults.results(fwdind),'bo');
	hold on;
	plot(xval(revblock),runResults.results(revind),'ro');
	xlabel('Steered Channel #'); ylabel('Current Level (uA)');

	xlim([min(xval)-.2, max(xval)+.2]);

	if ~isempty(fwdblock) && ~isempty(revblock)
		legend 'Fwd' 'Rev';
	elseif ~isempty(fwdblock)
		legend 'Fwd';
	elseif ~isempty(revblock)
		legend 'Rev';
	end;

end; % switch mainParam.runmode %


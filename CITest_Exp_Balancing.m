function varargout = CITest_Exp_Balancing(varargin)
% Experiment definition for the "Balancing" experiment mode.
%	This utility GUI creates a uipanel used in 'CITest' to specify
% experiment-specific stimuli, and also defines the BEDCS and runtime
% paramters to play those stimuli.
%	Several UI elements are identical to those defined in CITEST_EXP_THRESHOLD,
% where the callbacks for those elements are executed.
%
% REVISION HISTORY
%	Created on January 23, 2014 by SMB. Started with code from CITEST_EXP_PSYCHTUNING
% CURVE. For now, the function is focused solely on loudness balancing via changes in
% current level.
%	2015.04.09. Block parameter now supports a manually input vector by using brackets
% in the Block Start field.
%	2015.10.05. Added callback for the 'interval_text' uicontrol, because it differs
% enough from the one in _EXP_THRESHOLD.
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
function CITest_Exp_Balancing_OpeningFcn(hObject, eventdata, handles, varargin)


% --- Outputs from this function are returned to the command line --- %
% Again, this callback is never executed.
function CITest_Exp_Balancing_OutputFcn(hObject, eventdata, handles) 



%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- The mandatory experiment run mode pulldown menu --- %
% Set generic run-time settings (like "autosave" mode), and setup UI menu items depending on run mode.
function [runmode, runabbr] = runmode_popupmenu_Callback(hObject, eventdata, handles)

modeval = get(hObject,'Value');
modeString = get(hObject,'String');
runmode = modeString{modeval};

rdm_enable = 'on';
autosave = true;

switch runmode					% turn features on or off, as appropriate to the mode
case 'TwoStep Adjustment'
	runabbr = 'ADJ';
	autosave = false;
case 'Manual Level'
 	runabbr = 'MNL';
 	rdm_enable = 'off';
 	autosave = false;
otherwise
	runabbr = 'NIL';
end;

set(handles.expHandles.randomblock_checkbox,'Enable',rdm_enable);
set(handles.expHandles.randomlevel_checkbox,'Enable',rdm_enable);

if isempty(eventdata)			% this invokes GUIDATA, so skip it if called via CITEST_EXP_INITIALIZE
	handles.fileinfo.autosave = autosave;	% (and thereby avoid a CITEST_UPDATEFILENAME repeat)
	handles.mainParam.runmode = runmode; handles.mainParam.runabbr = runabbr;
	CITest('CITest_UpdateFileName',handles,0);
end;


% --- Handles changes to the block variable pulldown menu --- %
function blockvar_popup_Callback(hObject, eventdata, handles)

blockvar = get(hObject,'Value');
blockTypes = get(hObject,'String');
blockvar = blockTypes{blockvar};

switch blockvar					% set safe defaults when choosing variable type
case 'Channel'
	aelec = get(handles.activeelec_popup,'UserData');
	startval = min(aelec); endval = max(aelec);
	if startval==endval, stepval = 0;
	else stepval = 1;
	end;
case 'Sigma'
	startval = 1; endval = 1;
	stepval = 0;
otherwise						% for now, all other choices are deflected to 'Sigma'
	set(hObject,'Value',2);
	startval = 1; endval = 1;
	stepval = 0;
end;

set(handles.expHandles.blockstart_text,'String','','UserData',startval);
set(handles.expHandles.blockend_text,'String','','UserData',endval);
set(handles.expHandles.blockstep_text,'String','','UserData',stepval);

blockstartend_text_Callback(handles.expHandles.blockstart_text,0,handles);
blockstartend_text_Callback(handles.expHandles.blockend_text,0,handles);
blockstartend_text_Callback(handles.expHandles.blockstep_text,[],handles);


% --- Handle calls to start, end, and step size text fields for the block variable --- %
% Handling of inputs depends on the block parameter chosen in the popup menu.
function blockstartend_text_Callback(hObject, eventdata, handles)

inputstr = get(hObject,'String');
uitag = get(hObject,'tag');
valid = true;

blockvar = get(handles.expHandles.blockvar_popup,'Value');
blockTypes = get(handles.expHandles.blockvar_popup,'String');
blockvar = blockTypes{blockvar};

configval = get(handles.config1_edittext,'UserData');
configStruct = get(handles.config_popup,'UserData');
configtype = configStruct.type;		% reference stimulus config comes from the main STIM PARAMETERS panel

switch blockvar						% assess input validity depending on the parameter type
case 'Channel'
	if length(inputstr)>1 && any(strcmp({inputstr(1),inputstr(2)},'[')) && strcmp(uitag,'blockstart_text')
		val = str2num(inputstr);
		val = floor(val);			% allow vector inputs, delineated by brackets; take integer part only
		strformat = '%2d';
	elseif strcmp(uitag,'blockstep_text') && strcmpi(configtype,'sQP')
		val = sscanf(inputstr,'%f');
		strformat = '%.2f';			% 'sQP' steps can be non-integer (for steering)
	else
		val = sscanf(inputstr,'%d');
		strformat = '%2d';
	end;

	switch configtype				% electrode range depends on configuration
	case 'pTP'
		if isempty(val), valid = false;
		elseif configval>0, valid = all(val>=2 & val<=15);
		else valid = all(val>=1 && val<=16);
		end;
	case 'sQP'
		if isempty(val), valid = false;
		elseif configval>0, valid = all(val>=3 & val<=15);
		else valid = all(val>=2 & val<=16);
		end;
	case 'BP'
		if isempty(val), valid = false;
		else valid = all(val-configval-1>=1 & val<=16);
		end;
	end;
									% apply different rule if specifying channel step size
	if strcmp(uitag,'blockstep_text')
		if isempty(val), valid = false;
		else valid = val>=0 && val<=15;
		end;
	end;

case 'Sigma'
	aelec = get(handles.activeelec_popup,'UserData');
	aelec = min(aelec);				% only one active electrode allowed for reference stimulus; choose the first

	switch configtype				% process the input value string according to the configuration mode 'configtype'
	case 'pTP'
		val = sscanf(inputstr,'%f');
		if isempty(val), valid = false;
		else valid = val>=0 && val<=1;
		end;
		if val > 0					% make sure flanking electrodes are available
			valid = valid && (aelec-1)>=1 && (aelec+1)<=16;
		end;
		strformat = '%.1f';
		if strcmp(uitag,'blockstep_text')
			strformat = '%.2f';
		end;
	case 'sQP'
		val = sscanf(inputstr,'%f');
		if isempty(val), valid = false;
		else valid = val>=0 && val<=1;
		end;
		if val > 0					% one extra apical electrode compared to 'pTP' above
			valid = valid && (aelec-2)>=1 && (aelec+1)<=16;
		end;
		strformat = '%.1f';
		if strcmp(uitag,'blockstep_text')
			strformat = '%.2f';
		end;
	case 'BP'						% electrode separation is one more than written integer value
		val = sscanf(inputstr,'%d'); % (e.g. val = 1 for "BP+1" which is a separation of TWO electrodes)
		if isempty(val), valid = false;
		else valid = val>=0 && val<=6 && (aelec-val-1)>=1;
		end;						% make sure most apical return electrode is available
		strformat = '%+2d';
	end; % switch configtype %

end; % switch blockvar %

if ~valid							% if current value is invalid use last valid value
	val = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;
									% format the displayed string, and update the stored code
if length(val) > 1
	set(hObject,'String',cat(2,'[',num2str(val),']'),'UserData',val);
else
	set(hObject,'String',sprintf(strformat,val),'UserData',val);
end;

if length(val) > 1					% if entering a vector, make the other block fields inactive ..
	set(handles.expHandles.blockend_text,'Enable','Off');
	set(handles.expHandles.blockstep_text,'Enable','Off');
elseif strcmp(uitag,'blockstart_text') % .. but undo when reverting back to a scalar
	set(handles.expHandles.blockend_text,'Enable','On');
	set(handles.expHandles.blockstep_text,'Enable','On');
end;
									% double check that all values are orderly
if isempty(eventdata) && length(val)==1
	startval = get(handles.expHandles.blockstart_text,'UserData');
	endval = get(handles.expHandles.blockend_text,'UserData');
	stepval = get(handles.expHandles.blockstep_text,'UserData');

	if endval < startval			% iterate callback once if values aren't right
		endval = startval;			  % ('eventdata' argument set to 0 to avoid loops)
		set(handles.expHandles.blockend_text,'String','','UserData',endval);
		blockstartend_text_Callback(handles.expHandles.blockend_text,0,handles);
	end;
	if stepval > (endval-startval)
		stepval = 0;
		set(handles.expHandles.blockstep_text,'String','','UserData',stepval);
		blockstartend_text_Callback(handles.expHandles.blockstep_text,0,handles);
	end;

	if stepval						% interpret 0 step size as using only the start value
		blockvec = startval:stepval:endval;
	else blockvec = startval;
	end;

	if length(blockvec) > 30
		hw = warndlg('The number of block parameters is greater than 30.','Excessive Steps','modal');
		uiwait(hw);
	end;

	tipstr = sprintf('%d values from %.2f to %.2f',length(blockvec),blockvec(1),blockvec(end));
	hset = [handles.expHandles.blockstep_text handles.expHandles.blockstart_text handles.expHandles.blockend_text];
	set(hset,'TooltipString',tipstr);

elseif isempty(eventdata)
	tipstr = sprintf('vector: [%s]',num2str(val));
	hset = [handles.expHandles.blockstep_text handles.expHandles.blockstart_text handles.expHandles.blockend_text];
	set(hset,'TooltipString',tipstr);

end;


% --- Handle changes to the "Stimulus interval" text field --- %
% Modeled from the uicontrol callback in _EXP_THRESHOLD.
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


% --- Handle calls for the current step size text fields, both large and small --- %
function stepsize_text_Callback(hObject, eventdata, handles)

levelstr = get(hObject,'String');
levelval = sscanf(levelstr,'%f'); 

if isempty(levelval)
	valid = false;
else
	valid = levelval>=0 && levelval<=5;
end;

if ~valid					% revert to last field entry if the input is not in acceptable range
	levelval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

set(hObject,'String',sprintf('%.2f',levelval),'UserData',levelval);

if isempty(eventdata)
	lgval = get(handles.expHandles.steplarge_text,'UserData');
	smval = get(handles.expHandles.stepsmall_text,'UserData');

	if lgval < smval		% iterate callback once if values aren't right
		lgval = smval;		  % ('eventdata' argument set to 0 to avoid loops)
		set(handles.expHandles.steplarge_text,'String','','UserData',lgval);
		stepsize_text_Callback(handles.expHandles.steplarge_text,0,handles);
	end;
end;


% --- Handle calls for the current step size text fields, both large and small --- %
function repnum_text_Callback(hObject, eventdata, handles)

inputval = sscanf(get(hObject,'String'),'%d');

if isempty(inputval), valid = false;
else valid = inputval>=1 && inputval<=20;
end;

if ~valid								% if invalid string, revert to last valid one ..
	newval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
else
	newval = inputval;					% .. otherwise accept it
end;

set(hObject,'String',sprintf('%d',newval),'UserData',newval);



%%%% ESSENTIAL EXPERIMENT-SPECIFIC FUNCTIONS CALLED FROM CITEST %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- This performs what the Opening Function would have normally --- %
% This function and the next invokes the internal callback for the runtime mode popup
% menu. Note that file saving mode and updating the CITEST file name is not needed, unlike when
% RUNMODE_POPUPMENU is called from the experiment subGUI itself.
function [runmode,runabbr,subtypeStr] = CITest_Exp_GetRunMode(handles)

[runmode,runabbr] = runmode_popupmenu_Callback(handles.expHandles.runmode_popupmenu, false, handles);
										% subtype of experiment determines pulse type and other details
subtypeStr = {'Standard Pulse Train','Standard Single Pulse'};


% -- Define and initialize useful variables to be used internally -- %
% This is separate than the function above to allow the main pulse parameters to be adjusted, if needed, in CITEST.
function CITest_Exp_Initialize(handles)
										% required
set(handles.eleclabel_text,'String','Ref. electrode');
										% set fields to default using this callback
blockvar_popup_Callback(handles.expHandles.blockvar_popup,[],handles);

% set(handles.expHandles.blockstart_text,'String','1.0','UserData',1.0);
% set(handles.expHandles.blockend_text,'String','1.0','UserData',1.0);
% set(handles.expHandles.blockstep_text,'String','1.0','UserData',1.0);
% blockstartend_text_Callback(handles.expHandles.blockstart_text, [], handles);


% --- Force starting level to be at a low, safe value --- %
% A function with this name is common to all experiment definitions. It is called from the main
% control GUI, CITest. Set flag to non-zero if only primary channel levels get reset.
function CITest_Exp_ResetLevel(handles,resetflag)

if nargin < 2, resetflag = false; end;

if ~resetflag		% reset primary channel levels
levelval = get(handles.expHandles.startlevel_text,'UserData');
if ~isstruct(levelval)		% don't reset if a relative level is being used
	set(handles.expHandles.startlevel_text,'String','RESET','UserData',1);
	feval('CITest_Exp_PsychTuningCurve','levels_text_Callback',handles.expHandles.startlevel_text,[],handles);
end;

levelval = get(handles.expHandles.maxlevel_text,'UserData');
if ~isstruct(levelval)
	set(handles.expHandles.maxlevel_text,'String','RESET','UserData',1);
	feval('CITest_Exp_PsychTuningCurve','levels_text_Callback',handles.expHandles.maxlevel_text,[],handles);
end;
end; % if ~resetflag %
					% reset secondary channel level
levelval = get(handles.expHandles.reflevel_text,'UserData');
if ~isstruct(levelval)
	set(handles.expHandles.reflevel_text,'String','RESET','UserData',9);
	feval('CITest_Exp_PsychTuningCurve','levels_text_Callback',handles.expHandles.reflevel_text,[],handles);
end;


% --- Outputs the stimulus parameters associated with this utility GUI --- %
% A function with this name is common to all experiment definitions. Note that 'handles' is the structure
% of handles and variables from the MAIN control GUI; use 'handles.expHandles' for UI elements in THIS subGUI.
%	The pulse shape parameters for first-phase polarity and interphase gap should be set here, even if
% the BEDCS experiment doesn't require them.
function [levelParam, expParam] = CITest_Exp_GetParameters(handles,chanSettings,pulseSettings)

levelParam = 'Invalid Experiment';

if length(chanSettings.electrode) > 1
	expParam = 'Only one reference channel can be chosen for this experiment.';
	return;						% make sure there is only one reference channel defined
end;
								% important definitions
modeval = get(handles.expHandles.runmode_popupmenu,'Value');
modeString = get(handles.expHandles.runmode_popupmenu,'String');
runmode = modeString{modeval};
subtype = handles.mainParam.subtype;

blockval = get(handles.expHandles.blockvar_popup,'Value');
blockString = get(handles.expHandles.blockvar_popup,'String');
blockvar = blockString{blockval};

block_a = get(handles.expHandles.blockstart_text,'UserData');
block_b = get(handles.expHandles.blockend_text,'UserData');
block_step = get(handles.expHandles.blockstep_text,'UserData');

if block_step == 0			% 0 step size means there is only 1 value (the start)
	block_b = block_a;
	block_step = 1;
end;
							% catch various inconsistencies
if strcmp(blockvar,'Channel') && length(block_a)==1
	if mod(block_step,1) && ~strcmp(chanSettings.configtype,'sQP')
		expParam = 'Only integer step sizes are allowed for BP and pTP mode.';
		return;
	elseif (block_a-chanSettings.configval-1)<1 && strcmp(chanSettings.configtype,'BP')
		expParam = 'Apical electrode is out of range for BP mode.';
		return;
	elseif (block_a<3 || block_b>15) && chanSettings.configval(1)>0 && strcmp(chanSettings.configtype,'sQP')
		expParam = 'Electrode is out of range for sQP mode.';
		return;
	elseif block_a<2 && strcmp(chanSettings.configtype,'sQP')
		expParam = 'Electrode is out of range for sQP (sigma=0) mode.';
		return;
	end;
end;

if length(block_a) > 1			% interpret vector and scalar start inputs differently
	blockvec = block_a;			  % (vector simply overrides end point and step size inputs)
else
	blockvec = block_a:block_step:block_b;
end;

chanSettings2 = chanSettings;	% test channels initially inherit reference channel parameters
configtype2 = chanSettings2.configtype;
electrode2 = chanSettings2.electrode(1); %#ok<NASGU>
configval2 = chanSettings2.configval(1);
alpha2 = chanSettings2.alpha(1); %#ok<NASGU> % initally assumed to be scalar for test channel (as ref)

switch blockvar					% replace block variable depending on experiment UI settings
case 'Channel'
	if strcmp(configtype2,'sQP')
		chanvec = blockvec;
		electrode2 = floor(chanvec+1); alpha2 = mod(chanvec,1);
% 		if length(chanvec)>1	% ##2015.05.27: removed 'if' to force a single test channel to use alpha=1
		  ind0 = alpha2==0;		% bias toward alpha=1 instead of 0, except for channels < 3
		  ind0 = ind0 & chanvec>2;
		  electrode2(ind0) = electrode2(ind0) - 1;
		  alpha2(ind0) = 1;
% 		end;
	elseif strcmp(configtype2,'pTP')
		electrode2 = blockvec;
		alpha2 = 0.5;
	else % BP %
		electrode2 = blockvec;
		alpha2 = NaN;
	end;
case 'Sigma'
	expParam = 'Sigma option is not actually supported yet. Sorry to get your hopes up.';
	return;
otherwise
	expParam = 'The block variable type chosen is not currently supported.';
	return;
end;
								% interpret configuration and electrode settings (should work for vector
ccrow1 = configval2 * ones(1,length(electrode2)); % 'electrode2' OR 'configval2')
ccrow2 = alpha2;				% either 'configval2' or 'electrode2' is a vector, not both
if length(ccrow2)==1,ccrow2=ccrow2*ones(1,length(ccrow1)); end;
configcode2 = [ccrow1 ; ccrow2];

alpha2(isnan(alpha2)) = 0;		% BP alpha value should default to 0

chanSettings2.electrode = electrode2;
chanSettings2.alpha = unique(alpha2);	% for secondary chan, channel #s ~= permutations of elec + alpha
chanSettings2.configval = configval2;	  % (because of the way channel number is specified as a range)
chanSettings2.configcode = configcode2;
										% process level information for reference channel
refentry = get(handles.expHandles.reflevel_text,'UserData');

cLimits = handles.deviceProfile.currentlimit;

if isstruct(refentry)					% this will be a scalar
	reflevel = CITest('CITest_InterpretLevelCode',refentry,chanSettings,cLimits);
else
	reflevel = refentry;
end;
										% process level information for the test channel/s
startentry = get(handles.expHandles.startlevel_text,'UserData');
startstr = get(handles.expHandles.startlevel_text,'String');
maxentry = get(handles.expHandles.maxlevel_text,'UserData');
maxstr = get(handles.expHandles.maxlevel_text,'String');

nChan2 = length(chanSettings2.electrode);
if isstruct(startentry) && ~strcmp(blockvar,'Channel')
	if ~strcmp(startentry.base,'cmp')
	startlevel = nan(1,nChan2);	% handle numeric values and structure "level codes" differently ..
	else startlevel = CITest('CITest_InterpretLevelCode',startentry,chanSettings2,cLimits);
	end;						% .. and allow only compliance codes for non-channel block variables
elseif isstruct(startentry)
	startlevel = CITest('CITest_InterpretLevelCode',startentry,chanSettings2,cLimits);
else
	startlevel = startentry * ones(1,nChan2);
end;
if isstruct(maxentry) && ~strcmp(blockvar,'Channel')
	if ~strcmp(maxentry.base,'cmp'), maxlevel = nan(1,nChan2);
	else maxlevel = CITest('CITest_InterpretLevelCode',maxentry,chanSettings2,cLimits);
	end;
elseif isstruct(maxentry)		% .. either way, ascribe (for now) one level for every defined channel
	maxlevel = CITest('CITest_InterpretLevelCode',maxentry,chanSettings2,cLimits);
else
	maxlevel = maxentry * ones(1,nChan2);
end;

if any(isnan(reflevel)) 
	levelParam = [];			% force a quick exit if there is an illegal level (due to undefined THR or MCL)
	expParam = 'Check THR and MCL entries of reference channel.';
	return;
end;

if any(isnan(startlevel)) || any(isnan(maxlevel))
	levelParam = [];			% extra scrutiny for test channels
	expParam = 'Only absolute and compliance levels are allowed for test channels with the chosen block variable.';
	return;
end;
								% unless using special MP BEDCS files, watch out for illegal test electrodes
if strcmpi(configtype2,'pTP') && any(configval2~=0)
	if any(electrode2<2)  || any(electrode2>15)
		expParam = 'A test electrode is out of range.';
		return;
	end;
elseif strcmpi(configtype2,'sQP') && any(configval2~=0)
	if any(electrode2<3)  || any(electrode2>15)
		expParam = 'A test electrode is out of range.';
		return;
	end;
elseif strcmpi(configtype2,'sQP') && all(configval2==0)
	if any(electrode2<2)
		expParam = 'A test electrode is out of range.';
		return;
	end;
end;

switch runmode					% zero uA minimum level is only allowed for Manual mode
case 'Manual Level'
	minlimit = 0;
otherwise						% >= 1 assures dB steps are meaningful
	minlimit = 1;
end;
startlevel(startlevel<minlimit) = minlimit;

levelParam = struct();			% define level parameters for primary channel
levelParam.value = reflevel;	% (min/max level is more relevant for the test channel, below)
levelParam.maxlimit = reflevel;
levelParam.minlimit = 0;
levelParam.chanidx = 1;
levelParam.valuestring = startstr;
levelParam.maxstring = '';

expParam = struct();			% define experiment-specific parameters, incl. current level for secondary channel
expParam.blockvar = blockvar;

expParam.stimintvl = get(handles.expHandles.interval_text,'UserData');
expParam.largestep = get(handles.expHandles.steplarge_text,'UserData');
expParam.smallstep = get(handles.expHandles.stepsmall_text,'UserData');
expParam.nreps = get(handles.expHandles.repnum_text,'UserData');

expParam.rdmblock = logical(get(handles.expHandles.randomblock_checkbox,'Value'));
expParam.rdmmain = logical(get(handles.expHandles.randomlevel_checkbox,'Value'));

expParam.electrode2 = electrode2;
expParam.configtype = configtype2;
expParam.configcode = configcode2;
expParam.level = startlevel;
expParam.levelstr = startstr;
expParam.minlevel = minlimit;
expParam.maxlevel = maxlevel;
expParam.maxstr = maxstr;

chanSettings2.electrode2 = unique(electrode2);
expParam.chanSettings = chanSettings2;		% as in CITest, revert to "raw" electrode list for storage
expParam.chgdur = pulseSettings.phdur;

switch subtype								% define experiment subtype-specific parameters
case {'Standard Pulse Train','Standard Single Pulse'}
	expParam.polarity = 'cathodic';			% these two pulse-shape parameters are mandatory; however ..
	expParam.phgap = 0;
otherwise									% .. for all Threshold sub-experiments, values are fixed
	expParam.polarity = 'cathodic';			% (otherwise, this would be the place to set these pulse
	expParam.phgap = 0;						  % parameters from 'pulseSettings.dataUI'
end;


% --- Outputs the BEDCS and other parameters necessary to run the experiment associated with this m-file --- %
% A function with this name is common to all experiment definitions. Returned output 'bedcsParam' 
% contains everything required by the BEDCS experiment file, and 'ctrlParam' contains everything necessary
% to control those variables via the runtime subGUI. If either is empty, CITEST won't run the experiment.
%	Note that 'ctrlParam.minval' can be 0 for the ref channel but not the test channel.
function [bedcsParam, ctrlParam] = CITest_Exp_TransformParameters(mainParam,expParam,deviceProfile)

pulseSet = mainParam.pulseSettings;
stimdur = pulseSet.traindur;		% some upfront paperwork
configtype = mainParam.configtype;
blockvar = expParam.blockvar;

if strcmpi(configtype,'pTP') && mainParam.configcode(1,1)==0 && all(expParam.configcode(1,1)==0)
	configtype = 'MP';
elseif strcmpi(configtype,'sQP') && mainParam.configcode(1,1)==0 && all(expParam.configcode(1,1)==0)
	configtype = 'sMP';
end;

% Set BEDCS Parameters ######################################################### %
bedcsMain = {'IStim'};		% single-channel BEDCS file used, even though secondary channel may be defined

switch blockvar
case {'Channel','Sigma'}	% 'bedcsBlockValues' contains TEST channel's parameters ..
	bedcsBlock = {'elec','sigma','alpha'};
	bedcsBlockValues = {expParam.electrode2,expParam.configcode(1,:),expParam.configcode(2,:)};
otherwise					% (new 'blockvar' options added later may require update to config-dependent changes)
	bedcsBlock = {'elec','sigma','alpha'};
	bedcsBlockValues = {expParam.electrode2,expParam.configcode(1,:),expParam.configcode(2,:)};
end;

switch mainParam.subtype
case 'Standard Pulse Train'
	displaystr = 'Loudness Balancing (uA)';
							% ..but 'bedcsParam' contains REFERENCE channel's parameters (most are same as test chan)
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
		bedcsBlockValues = {expParam.electrode2,expParam.configcode(2,:)};
	case 'MP'
		bedcsexp = 'CITest_pulsetrainMP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma','alpha'});
		bedcsBlock = {'elec'};
		bedcsBlockValues = {expParam.electrode2};
	case 'BP'
		bedcsexp = 'CITest_pulsetrainBP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigma','alpha'});
		bedcsParam = setfield(bedcsParam,'sep',mainParam.configcode(1,1)+1);
		bedcsBlock = {'elec','sep'};
		bedcsBlockValues = {expParam.electrode2,expParam.configcode(1,:)+1};
	otherwise
		bedcsexp = '';
	end;

case 'Standard Single Pulse'
	displaystr = '1-pulse Loudness Balancing (uA)';

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

% Set Control Parameters ######################################################### %
viewSetup = struct('xlabel',[],'xvalues',[]);

if strcmp(mainParam.configtype,'sQP')
	xval = (expParam.electrode2-1) +  expParam.configcode(2,:);
	xlbl = 'Test Ch:';		% ##'blockvar' options other than 'Channel' will require a diff. x-value defn
else
	xval = expParam.electrode2;
	xlbl = 'Test El:';
end;
viewSetup.xlabel = xlbl;
viewSetup.xvalues  = xval;

switch mainParam.runmode
case 'Manual Level'
	rungui = 'CITest_RunGUI_Manual';

	runSetup.steplabels = {'linear (uA)','log (dB uA)'};
	runSetup.stepsizes = {[1 5 10 20],[.1 .5 2 20*log10(2)]};
	runSetup.stepstart = 2;			% 1 = linear, 2 = log (per above)
	runSetup.stepscale = 1;			% unused right now (might be useful for non-current stimulus variables)
	runSetup.format = '%.1f';		% for display of the stimulus variable
	runSetup.tipunit = 'db';

	intvl = expParam.stimintvl; dwell = 0;
	nreps = 1;

	querystr = '';

case {'TwoStep Adjustment'}
	rungui = 'CITest_RunGUI_TwoStepAdjust';
											% unsigned step changes for current level
	runSetup.upstepsm = expParam.smallstep;
	runSetup.downstepsm = expParam.smallstep;
	runSetup.upsteplg = expParam.largestep;
	runSetup.downsteplg = expParam.largestep;

	runSetup.stepunit = 'db';
	runSetup.stepsign = +1;					% +1 means that runGUI arrows will cause expected up/down parameter change

	runSetup.rdmblock = expParam.rdmblock;	% true or false whether to randomize block vector
	runSetup.rdmmain = expParam.rdmmain;	% true or false whether to start each block +/-X with uniform prob. (next entry)
	runSetup.rdmmain_limit = 1;				% max amount of random change, in same units as 'runSetup.stepunit'

	runSetup.oncolor = [1 1 .4];
	runSetup.offcolor = [.82 .82 .78];

	intvl = expParam.stimintvl; dwell = 0;
	nreps = expParam.nreps;

	querystr = 'Adjust loudness of 2 until it matches 1, then press NEXT.';

otherwise							% an empty 'rungui' signifies a non-operational runmode
	rungui = '';

end; % switch mainParam.runmode %

if isempty(rungui)
	ctrlParam = [];
else
	ctrlParam = struct('rungui',rungui,'runSetup',runSetup,'mainVars',{bedcsMain},'maxval',expParam.maxlevel,...
	  'minval',expParam.minlevel,'startval',expParam.level,'blockVars',{bedcsBlock},'blockValues',{bedcsBlockValues},...
	  'displaytext',displaystr,'querytext',querystr,'intvl',intvl,'stimdur',stimdur,'dwell',dwell,...
	  'nreps',nreps,'viewSetup',viewSetup);
end;


% --- Provide information about pulse parameters depending on the subtype of experiment --- %
% This function works in two modes. Mode 1 returns the name of the pulse type, and possibly
% instructions for the Pulse Modification subGUI, given the subtype of experiment. Mode 2
% returns some information about the pulse train sequence given the number of 'tbase' time
% frames of the primary phase duration. The former mode is called in various places by CITEST;
% the latter mode is called only through CITEST_PULSEOPTIONS (and indirectly from CITEST).
%	Experiment subtypes must match those listed in CITest_Exp_Initialize(). Pulse types
% must match those expected in CITEST_PULSEOPTIONS. Tbase is defined
function varargout = CITest_Exp_GetPulseInfo(handles,pulseIn,phframes)

% Mode 1 - string input is the experiment subtype %
if ischar(pulseIn)
	dataUI = [];				% empty if using only standard (non-custom) pulse types
	tbase = [];

	switch pulseIn
	case 'Standard Pulse Train'
		pulsetype = 'Simple 2-Chan Biphasic';
	case 'Standard Single Pulse'
		pulsetype = 'Simple 2-Chan Biphasic 1-Pulse';
	end;

	varargout{1} = pulsetype;
	varargout{3} = tbase;		% for standard pulse types, tbase and UI instr.s defined in CITEST_PULSEOPTIONS
	varargout{2} = dataUI;

% Mode 2 - structure input is current pulse information and # of phase time frames %
elseif nargin > 2
	plsframes = []; ipframes = [];

	varargout{1} = plsframes;	% custom pulse info not needed for any PTC experiment subtypes
	varargout{2} = ipframes;

else
	error('Not enough input arguments.');
end;


% --- Format results from the run-time GUI and create experiment-specific display, if desired ---- %
function [runResults,runSummary] = CITest_Exp_ProcessResults(mainParam,ctrlParam,runOutput)

runResults = runOutput;
runSummary = [];

switch mainParam.runmode

case 'Manual Level'

case 'TwoStep Adjustment'
	if isempty(runResults.results)
		disp('Some fields of ''runResults'' could not be set.')
		return;
	end;

	xval = ctrlParam.viewSetup.xvalues;
	xlbl = ctrlParam.viewSetup.xlabel;

	valuesdb = 20*log10(runResults.results);
	avgthrdb = nanmean(valuesdb,1);
	stdthrdb = nanstd(valuesdb,0,1);
	avgthr = 10.^(avgthrdb/20);

	figure;
	plot(xval',valuesdb','bo');
	hold on;
	plot(xval',avgthrdb','r*');
	xlabel(xlbl); ylabel('Current (dB)');

	runResults.avgthr = avgthr;
	runResults.avgthrdb = avgthrdb;
	runResults.stdthrdb = stdthrdb;

	fprintf(1,'%16s  ',xlbl); fprintf(1,'%3.2f  ',xval); fprintf(1,'\n');
	fprintf(1,'Avg current (uA): '); fprintf(1,'%3.1f  ',avgthr); fprintf(1,'\n');
	fprintf(1,'Avg current (dB): '); fprintf(1,'%3.1f  ',avgthrdb); fprintf(1,'\n');
	fprintf(1,'STD current (dB): '); fprintf(1,'%3.2f  ',stdthrdb); fprintf(1,'\n\n');

end; % switch mainParam.runmode %


function varargout = CITest_Exp_PsychTuningCurve(varargin)
% Experiment definition for the "PTC" experiment mode.
%	This utility GUI creates a uipanel used in 'CITest' to specify
% experiment-specific stimuli, and also defines the BEDCS and runtime
% paramters to play those stimuli.
%	Several UI elements are identical to those defined in CITEST_EXP_THRESHOLD,
% where the callbacks for those elements are executed.
%
% REVISION HISTORY
%	Created on August 23, 2014 by SMB. Started with code from CITEST_EXP_THRESHOLD.
%	2014.09.10. Noticed that the BEDCS method of defining pulse tables (via the Pulse
% Designer panel) forces the probe and masker to have the same pulse rate. So be it.
% However, the infrastructure to handle duel rates (e.g. with 'nZerosM' and 'nZerosP')
% is still in place. One can hope.
%	2014.09.10. BEDCS definition for the MP configuration is now used as a special case
% for pTP and sQP when sigma = 0. This increases the total number of allowable active
% electrodes. (Version 1.205)
%	2014.10.05. Polarity of masker current level changes was corrected for 2IFC and
% Tracking run modes. When the target sound (probe) is heard, the masker level must
% change in the opposite direction compared to the Threshold experiment.
%	2015.11.18. Probe electrode 2 is now allowed for sQP configuration, but it is
% interpreted as active electrode 3 with an alpha of 0. Also, simplified gathering
% of 'chanSettings2' info by invoking the 'setupprobe_pushbutton' callback.
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

% --- The mandatory experiment run mode pulldown menu --- %
% Set generic run-time settings (like "autosave" mode), and setup UI menu items depending on run mode.
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
case 'Manual Level - Masker'
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
								% make sure step and average settings are valid re: # reversals
if strcmpi(updownstep_enable,'on')
	CITest_Exp_Threshold('reversals_text_Callback',handles.expHandles.reversals_text,[],handles);
end;

if isempty(eventdata)			% this invokes GUIDATA, so skip it if called via CITEST_EXP_INITIALIZE
	handles.fileinfo.autosave = autosave;	% (and thereby avoid a CITEST_UPDATEFILENAME repeat)
	handles.mainParam.runmode = runmode; handles.mainParam.runabbr = runabbr;
	CITest('CITest_UpdateFileName',handles,0);
end;


% --- Handle changes to the "Probe fixed level" field and the "Masker starting" and "Masker max level" fields --- %
% Only the absolute current limit of the device is imposed in this function. Behavioral-based (dependent on
% configuration) and compliance-based current limits are not imposed until the START button is pressed in CITest.
%	Note that, to allow probe-only and masker-only stimulation, zero currents are allowed. Keep in mind that dB changes
% won't alter a 0 uA current level.
%	As of CITest v01.22, this function is also used for level fields of CITEST_EXP_BALANCING.
function levels_text_Callback(hObject, eventdata, handles)

levelstr = get(hObject,'String');
levelval = sscanf(levelstr,'%f'); 
dbflag = regexpi(levelstr,'db');

if isempty(levelval) || ~isempty(dbflag)
	levelCode = CITest('CITest_ParseLevelCode',hObject,levelstr);
	valid = ~isempty(levelCode);
	levelval = levelCode;
else								% 0 uA will be overridden to 1 uA for some run modes
	valid = levelval>=0 && levelval<=handles.deviceProfile.currentlimit.absolute;
end;

if ~valid							% revert to last field entry if the input is not an acceptable number or code
	levelval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

if isstruct(levelval)				% update UI properties depending on whether input is a number or a code
	tipstr = 'Variable level';
	set(hObject,'String',levelval.codestr,'UserData',levelval,'TooltipString',tipstr);
else
	tipstr = sprintf('%.1f dB',20*log10(levelval));
	set(hObject,'String',sprintf('%.1f',levelval),'UserData',levelval,'TooltipString',tipstr);
end;


% --- Handle changes to the secondary channel's active electrode popup menu --- %
function probeelec_popup_Callback(hObject, eventdata, handles)

oldelec = get(hObject,'UserData');	% this could be a scalar or vector (the latter if set in Channel Selector)
newval = get(hObject,'Value');

if newval <= 16						% for most cases, the menu entry order is identical to the channel number
	newelec = newval;
else								% if user chooses the menu entry "multiple", resort to the stored electrode value
	newelec = oldelec;
end;
aelec_min = min(newelec);			 % 'aelec' can be a vector, if multiple electrodes are defined (in Channel Selector)
aelec_max = max(newelec);

configStruct = get(handles.expHandles.config_popup,'UserData');
configtype = configStruct.type;
configval = get(handles.expHandles.config1_edittext,'UserData');

switch configtype					% acceptable electrode channel depends on configuration
case 'pTP'
	if configval>0
		valid = (aelec_min-1)>=1 && (aelec_max+1)<=16;
	else
		valid = aelec_min>=1 && aelec_max<=16;
	end;
case 'sQP'
	if configval>0					% ##2015.11.17: active elec 2 now OK; interpreted as elec 3 with alpha=0
		valid = (aelec_min-1)>=1 && (aelec_max+1)<=16;
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

if ~(~isempty(eventdata) && eventdata==0)	% set probe level to minimum for safety, unless suppressed via input argument
	feval(handles.expHandles.expgui,'CITest_Exp_ResetLevel',handles,true); % (primary channel level won't be changed)
end;


% --- Handle calls to the configuration UI components --- %
% Usually, this UI component will always be inactive. However, an internal call is made at
% the time of parameter gathering in order to assure that config. type is the same as in the
% main GUI.
function config_popup_Callback(hObject, eventdata, handles)

configStr = get(hObject,'String');	% for convenience, store config mode in 'UserData'
configtype = configStr{get(hObject,'Value')};

configStruct = get(hObject,'UserData');
configStruct.type = configtype;		% configuration type is changed with no validity checks
set(hObject,'UserData',configStruct);

switch configtype					% update text label for config code
case 'pTP'
	configlabel = 'Sigma';
case 'sQP'
	configlabel = 'Sigma';
case 'BP'
	configlabel = 'Sep.';
end;
									% force call to CONFIG1_EDITTEXT to set last valid code
set(handles.expHandles.configlabel1_text,'String',configlabel); % this also checks active electrode
config1_edittext_Callback(handles.expHandles.config1_edittext,1,handles);


% The spatial selectivity parameter, either sigma for pTP and sQP or electrode separation for BP %
function config1_edittext_Callback(hObject, eventdata, handles)

configval = get(hObject,'String');	% the unprocessed string appearing in the text field

configStruct = get(handles.expHandles.config_popup,'UserData');
configtype = configStruct.type;
									% only one probe electrode, so this should be a scalar value
pelec = get(handles.expHandles.probeelec_popup,'UserData');

switch configtype					% process the 'configval' string according to the configuration mode 'configtype'
case 'pTP'
	configval = sscanf(configval,'%f');
	if isempty(configval), valid = false;
	else valid = configval>=0 && configval<=1;
	end;
	if configval > 0				% make sure flanking electrodes are available
		valid = valid && (pelec-1)>=1 && (pelec+1)<=16;
	end;
	strformat = '%.2f';
case 'sQP'
	configval = sscanf(configval,'%f');
	if isempty(configval), valid = false;
	else valid = configval>=0 && configval<=1;
	end;
	if configval > 0				% one extra apical electrode compared to 'pTP' above
		valid = valid && (pelec-2)>=1 && (pelec+1)<=16;
	end;
	strformat = '%.2f';
case 'BP'
	configval = sscanf(configval,'%d');
	if isempty(configval), valid = false;
	else valid = configval>=0 && configval<=6 && (pelec-configval-1)>=1;
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
set(handles.expHandles.config_popup,'UserData',configStruct);
									% check active electrode, and if invalid set it to a safe electrode (12)
probeelec_popup_Callback(handles.expHandles.probeelec_popup,12,handles)


% --- Handle calls to the "Probe rate" text field --- %
% Non-empty 'eventdata' suppresses level resetting.
function rate_text_Callback(hObject, eventdata, handles)

rateval = sscanf(get(hObject,'String'),'%f');

exppulseSettings = getappdata(handles.expHandles.uipanel,'exppulseSettings');
pulseSettings = handles.mainParam.pulseSettings;
tbase = pulseSettings.tbase;		% from main GUI, most recently calculated # of time frames per pulse
plsframes = pulseSettings.plsframes;

pulseperiod = (1./rateval) * 1e6;	% in units of usec
minperiod = plsframes*tbase * 2;	% maximum pulse rate corresponds to a 1:1 duty cycle
maxperiod = 2 * 1e6;				% 2 second maximum period corresponds to maximum train duration

if isempty(rateval)
	valid = false;
else
	valid = pulseperiod<=maxperiod && pulseperiod>=minperiod;
end;

if ~valid						% if new value is invalid, use instead the last valid value from CITEST
	ipframes = pulseSettings.ipframes;
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
else							% .. otherwise calculate final number of interpulse zeros
	ipframes = round( (pulseperiod - plsframes*tbase)/tbase );
end;

exppulseSettings.tbase = tbase; exppulseSettings.plsframes = plsframes; exppulseSettings.ipframes = ipframes;
setappdata(handles.expHandles.uipanel,'exppulseSettings',exppulseSettings);

if isempty(ipframes)			% if single pulse, set pulse rate and duration to 0
	set([hObject handles.expHandles.traindur_text],'String','--','UserData',0,'Enable','Off');
	return;
else							% store zeros value and update display of the equivalent rate (in pulses/sec)
	pulseperiod = (plsframes + ipframes) * tbase;
	tipstr = sprintf('# of interpulse zeros is %d',ipframes);
	set(hObject,'String',sprintf('%.1f',1/(pulseperiod/1e6)),'UserData',1/(pulseperiod/1e6),'TooltipString',tipstr);
	set(handles.expHandles.traindur_text,'Enable','On');			% update pulse train duration
	traindur_text_Callback(handles.expHandles.traindur_text,eventdata,handles);
end;


% --- Handles changes to the "Pulse train duration" text field --- %
% The train duration value will always be a multiple of the current pulse period, as determined
% by the sum of 'exppulseSettings.plsframes' (pegged to value in CITest) and 'exppulseSettings.ipframes'.
function traindur_text_Callback(hObject, eventdata, handles)

durval = sscanf(get(hObject,'String'),'%f');

exppulseSettings = getappdata(handles.expHandles.uipanel,'exppulseSettings');
tbase = exppulseSettings.tbase;
plsframes = exppulseSettings.plsframes;		% use last internally stored values, rather than grabbing from main GUI
ipframes = exppulseSettings.ipframes;

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

exppulseSettings.numpulses = numpulses;
setappdata(handles.expHandles.uipanel,'exppulseSettings',exppulseSettings);

if isempty(eventdata)				% set current level to minimum, for safety, unless flagged by evtdata
	feval('CITest_Exp_ResetLevel',handles,true); % (only probe channel will be reset)
end;


% --- Handles changes to the "Masker-probe interval" text field --- %
% The interval value will always be a multiple of the current pulse period, as determined
% by the sum of 'exppulseSettings.plsframes' and 'exppulseSettings.ipframes (pegged to value in CITest)'.
function mpintvl_text_Callback(hObject, eventdata, handles)

intvlval = sscanf(get(hObject,'String'),'%f');

exppulseSettings = getappdata(handles.expHandles.uipanel,'exppulseSettings');
tbase = exppulseSettings.tbase;
plsframes = exppulseSettings.plsframes;		% use last internally stored values, rather than grabbing from main GUI
ipframes = exppulseSettings.ipframes;		% currently, masker and probe have the same # of inter-pulse zero frames

if isempty(ipframes)
	error('The single-pulse subtype for PTC experiments is broken. Sorry!!');
	% ##SMB2014.09.15 There are no BEDCS definitions right now, so I'm unsure about how to define # of intvl pulses.
elseif isempty(intvlval)
	valid = false;
else
	valid = intvlval>=0 && intvlval<=2000;
end;

if ~valid								% if new value is invalid, use instead the last valid value
	intvlval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
end;

pulseperiod = plsframes + ipframes;		% base period = during-pulse + inter-pulse durations (= 1/pulserate)
pulseperiod = pulseperiod * tbase * 1e-3;				% convert to msec
intvlval = pulseperiod * round(intvlval/pulseperiod);	% force m-p interval to be a multiple of the pulse period
% if isempty(ipframes)					% ##2014.09.19 fix this later when coding for single pulses!!
% 	intvlval = 2*plsframes * round(intvlval/(2*plsframes));
% end;

if ~isempty(ipframes)					% update the stored duration value
	numpulses = floor(intvlval/pulseperiod);
	totaldur = ipframes * tbase*1e-3 + intvlval;	
else									% train total adds last interpulse zeros to nominal m-p interval
	numpulses = floor(intvlval/(2*plsframes));
	totaldur = plsframes * tbase*1e-3 + intvlval;
end;
tipstr = sprintf('Equivalent # of pulses is %d. End-to-start duration is %.1f ms.',numpulses,totaldur);
set(hObject,'String',sprintf('%.1f',intvlval),'UserData',intvlval,'TooltipString',tipstr);

exppulseSettings.intvlpulses = numpulses;
setappdata(handles.expHandles.uipanel,'exppulseSettings',exppulseSettings);


% --- Open the Channel Selection subGUI, for specifiying threshold and MCL values for the probe channel --- %
% This is similar to the call made in CITEST, but only one channel is set.
function chanSettings = setupprobe_pushbutton_Callback(hObject, eventdata, handles)
								% if exp subGUI is new, create Ch. Selector information, starting with one in CITEST
if ~isfield(handles.expHandles,'chanProfile') % (thus, impedance values will be ported over, if available)
	chanProfile = handles.chanProfile;
	aelec = get(handles.expHandles.probeelec_popup,'UserData');
	chanProfile.onoff = false(1,16); chanProfile.onoff(aelec(1)) = true;
	chanProfile.alphatype = 1;	% no worries if these don't match for now; they'll get updated by '_UpdateFields()' below
	chanProfile.alphaval = 0.5;
	chanProfile.alphavector = 0.5;
else							% otherwise, grab the stored 'chanProfile' (of exp subGUI, not main GUI)
	chanProfile = handles.expHandles.chanProfile;
end;
								% store necessary info from various UI fields
configStruct = get(handles.expHandles.config_popup,'UserData');
chanSettings.electrode = get(handles.expHandles.probeelec_popup,'UserData');
chanSettings.configtype = configStruct.type;
chanSettings.configval = get(handles.expHandles.config1_edittext,'UserData');

switch chanSettings.configtype	% set alpha to a restricted set of values, depending on configuration
case 'sQP'
	if chanSettings.electrode==2
		chanSettings.electrode = 3;
		chanSettings.alpha = 0;	% only allow steered alpha for this special case
	else
		chanSettings.alpha = 1;
	end;
case 'pTP'
	chanSettings.alpha = 0.5;
case 'BP'
	chanSettings.alpha = NaN;
end;

chanSettings.configcode = [chanSettings.configval ; chanSettings.alpha];
								% add phase info from main GUI and pulse train info from this subGUI
chanSettings.phdur = handles.mainParam.pulseSettings.phdur;
chanSettings.traindur = get(handles.expHandles.traindur_text,'UserData');
chanSettings.pulserate = get(handles.expHandles.rate_text,'UserData');
chanSettings.ratestr = get(handles.expHandles.rate_text,'String');

if nargout						% for special case, stop function here and don't open Ch. Selector window
	return;
end; 
								% create new Ch. Selector window, as this one is deleted after each use
hch2select = CITest_ChannelSelector([],'Channel Selector - Probe Channel',{'electrode','alpha'});

try								% seed subGUI with last saved channel profile, and wait until it returns
	chanProfile = CITest_ChannelSelector('CITest_ChannelSelector_UpdateFields',hch2select,chanProfile,chanSettings);
catch
	chanProfile = [];
end;

if isempty(chanProfile)			% if empty, Channel Selector was cancelled or (*GASP*) an error occurred
	disp('Primary channel settings were not saved.');
	if ishandle(hch2select), delete(hch2select); end;
	return;
end;
								% ##2015.11.17: removed because Ch Selector now won't allow electrode and alpha changes
% if strcmpi(chanSettings.configtype,'sQP')
% 	chanProfile.alphatype = 1;	% accept only alpha = 0 or 1
% 	if length(chanProfile.alphaval)~=1 || chanProfile.alphaval~=0
% 		chanProfile.alphaval = 1.0;
% 		chanProfile.alphavector = 1.0;
% 	end;
% else							% ignore changes to alpha for all other modes
% 	chanProfile.alphatype = 1;
% 	chanProfile.alphaval = 0.5;
% 	chanProfile.alphavector = 0.5;
% end;
% 								% update the active electrode field
% chanvec_old = get(handles.expHandles.probeelec_popup,'UserData');
% chanvec_new = find(chanProfile.onoff);
% chanvec_new = chanvec_new(1);	% only one channel allowed for fwd masking experiments
% set(handles.expHandles.probeelec_popup,'Value',17,'UserData',chanvec_new); % (value = 17 is a safe default)
% checkchan = length(chanvec_new)==length(chanvec_old) && all(chanvec_new==chanvec_old);
% if checkchan					% don't reset start/max levels if channel set didn't change
% 	probeelec_popup_Callback(handles.expHandles.probeelec_popup,0,handles);
% else
% 	probeelec_popup_Callback(handles.expHandles.probeelec_popup,[],handles);
% end;
								% overwrite the old Ch. Selector profile
handles.expHandles.chanProfile = chanProfile;
guidata(hObject,handles);
								% unlike CITEST's Ch. Selector window, this one should be deleted
if ishandle(hch2select), delete(hch2select); end;



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
set(handles.eleclabel_text,'String','Masker electrode');
										% setup UI elements for electrode configuration
configStruct = get(handles.config_popup,'UserData');
configchoice = get(handles.config_popup,'Value'); % config type forced to be same as in main GUI
configlabel = get(handles.configlabel1_text,'String');
if strcmp(configStruct.type,'BP'), configlabel = 'Sep.'; end;

set(handles.expHandles.config_popup,'Value',configchoice,'UserData',configStruct,'Enable','Off');
set(handles.expHandles.configlabel1_text,'String',configlabel);
config1_edittext_Callback(handles.expHandles.config1_edittext,1,handles);

exppulseSettings.plsframes = handles.mainParam.pulseSettings.plsframes;
exppulseSettings.ipframes = handles.mainParam.pulseSettings.ipframes;
exppulseSettings.numpulses = [];		% pulse parameters must be same as in CITEST
exppulseSettings.intvlpulses = [];
setappdata(handles.expHandles.uipanel,'exppulseSettings',exppulseSettings);
										% set pulse rate to same as CITEST; don't let it be changed!
set(handles.expHandles.rate_text,'String',get(handles.rate_text,'String'),'Enable','Off');
rate_text_Callback(handles.expHandles.rate_text,0,handles);	% suppress level change
										% set m-probe interval to a valid value (based on the pulse rate)
set(handles.expHandles.mpintvl_text,'String','');
mpintvl_text_Callback(handles.expHandles.mpintvl_text,[],handles);


% --- Force starting level to be at a low, safe value --- %
% A function with this name is common to all experiment definitions. It is called from the main
% control GUI, CITest. Set flag to non-zero if only primary channel levels get reset.
function CITest_Exp_ResetLevel(handles,resetflag)

if nargin < 2, resetflag = false; end;

if ~resetflag		% reset primary channel levels
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
end; % if ~resetflag %
					% reset secondary channel level
levelval = get(handles.expHandles.probelevel_text,'UserData');
if ~isstruct(levelval)
	set(handles.expHandles.probelevel_text,'String','RESET','UserData',1);
	levels_text_Callback(handles.expHandles.probelevel_text, [], handles);
end;


% --- Outputs the stimulus parameters associated with this utility GUI --- %
% A function with this name is common to all experiment definitions. Note that 'handles' is the structure
% of handles and variables from the MAIN control GUI; use 'handles.expHandles' for UI elements in THIS subGUI.
%	The pulse shape parameters for first-phase polarity and interphase gap should be set here, even if
% the BEDCS experiment doesn't require them.
 function [levelParam, expParam] = CITest_Exp_GetParameters(handles,chanSettings,pulseSettings)

levelParam = 'Invalid Experiment';

modeval = get(handles.expHandles.runmode_popupmenu,'Value');
modeString = get(handles.expHandles.runmode_popupmenu,'String');
runmode = modeString{modeval};
subtype = handles.mainParam.subtype;
								% get parameters for secondary channel (the PROBE)
chanSettings2 = setupprobe_pushbutton_Callback([],[],handles); % %%2015.11.18: use callback for this; doesn't need the UI handle

% configStruct = get(handles.expHandles.config_popup,'UserData');
% configtype2 = configStruct.type;
% configval2 = get(handles.expHandles.config1_edittext,'UserData');
% if ~strcmpi(configtype2,chanSettings.configtype)
if ~strcmpi(chanSettings2.configtype,chanSettings.configtype)
	set(handles.expHandles.config_popup,'Value',get(handles.config_popup,'Value'));
	set(handles.expHandles.config_popup,'UserData',get(handles.config_popup,'UserData'));
	config_popup_Callback(handles.expHandles.config_popup,[],handles);

	expParam = 'Primary configuration type changed.';
	return;						% enforce config type to be the same as primary channel
end;

exppulseSettings = getappdata(handles.expHandles.uipanel,'exppulseSettings');
if exppulseSettings.tbase~=pulseSettings.tbase || exppulseSettings.plsframes~=pulseSettings.plsframes || ...
  length(exppulseSettings.ipframes)~=length(pulseSettings.ipframes) || ...
  (~isempty(exppulseSettings.ipframes) && ~isempty(pulseSettings.ipframes) && exppulseSettings.ipframes~=pulseSettings.ipframes)

	set(handles.expHandles.rate_text,'String',get(handles.rate_text,'String'),'Enable','Off');
	rate_text_Callback(handles.expHandles.rate_text,[],handles);
	mpintvl_text_Callback(handles.expHandles.mpintvl_text,[],handles);
								% enforce phase information from CITEST to synchronize with subGUI; this will force a probe amplitude change
	expParam = 'Phase duration of the primary (masking) channel or other pulse parameter changed.';
	return;						% note that 'timebase' is untouched, as this is set by the main GUI's (masker channel) pulse rate parameter

end; % if all that mess %

% 								% create a 'chanSettings' structure for secondary channel
% chanSettings2.electrode = get(handles.expHandles.probeelec_popup,'UserData'); % should be a scalar
% chanSettings2.configtype = configtype2;
% chanSettings2.configval = configval2;
% chanSettings2.alpha = [];
% chanSettings2.configcode = [];		% set below
% 
% chanSettings2.phdur = chanSettings.phdur;
% chanSettings2.traindur = get(handles.expHandles.traindur_text,'UserData');
% chanSettings2.pulserate = get(handles.expHandles.rate_text,'UserData');
% chanSettings2.ratestr = get(handles.expHandles.rate_text,'String');
% 									
% % Interpret configuration and electrode settings to define every channel for the experiment %
% if strcmp(configtype2,'pTP')
% 	chanSettings2.alpha = 0.5;
% 	configcode2 = [configval2 ; 0.5];	% use centered alpha values for pTP
% elseif strcmp(configtype2,'sQP')
% 	chanSettings2.alpha = 1.0;
% 	configcode2 = [configval2 ; 1.0];	% and for sQP
% else % 'BP' %
% 	chanSettings2.alpha = NaN;
% 	configcode2 = [configval2 ; NaN];	% for BP, channel separation and undefined
% end;
% 
% chanSettings2.configcode = configcode2;

								% if the secondary "Ch. Select" tool hasn't been opened, use default values
if ~isfield(handles.expHandles,'chanProfile')
	chanSettings2.impedance = handles.chanProfile.impedance;
	chanSettings2.compliance = handles.chanProfile.compliance;
	chanSettings2.threshold = nan(1,16);
	chanSettings2.mcl = nan(1,16);
else
	chanSettings2.impedance = handles.expHandles.chanProfile.impedance;
	chanSettings2.compliance = handles.expHandles.chanProfile.compliance;
	chanSettings2.threshold = handles.expHandles.chanProfile.threshold;
	chanSettings2.mcl = handles.expHandles.chanProfile.mcl;
	mlmatch = CITest_ChannelSelector('CITest_ChannelSelector_Match',chanSettings2,handles.expHandles.chanProfile);
	if ~mlmatch					% if configuration, phase duration, etc don't match, reset threshold and mcl values
		chanSettings2.threshold = nan(1,16);
		chanSettings2.mcl = nan(1,16);
	end;
end;
								% process level information for primary channel/channels (the MASKER)
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
								% repeat level processing for the secondary channel
fixedentry = get(handles.expHandles.probelevel_text,'UserData');
fixedstr2 = get(handles.expHandles.probelevel_text,'String');

if isstruct(fixedentry)
	fixedlevel = CITest('CITest_InterpretLevelCode',fixedentry,chanSettings2,cLimits);
else
	fixedlevel = fixedentry;
end;

if any(isnan(startlevel)) || any(isnan(maxlevel)) || any(isnan(fixedlevel)) 
	levelParam = [];			% force a quick exit if there is an illegal level (due to undefined THR or MCL)
	expParam = 'Check THR and MCL entries of active and flanking electrodes.';
	return;
end;

switch runmode					% for some run modes, define a level for every defined channel
case {'Channel Sweep','Manual Level - Masker'}
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
								% unless using special MP BEDCS files, watch out for illegal electrodes
sigmaval_m = chanSettings.configcode(1,1); sigmaval_p = chanSettings2.configcode(1,1);
if strcmpi(chanSettings.configtype,'pTP') && ~all([sigmaval_m sigmaval_p]==0)
	if any(chanSettings.electrode<2)  || any(chanSettings.electrode>15)
		expParam = 'An active electrode is out of range.';
		return;
	end;
elseif strcmpi(chanSettings.configtype,'sQP') && ~all([sigmaval_m sigmaval_p]==0)
	if any(chanSettings.electrode<3)  || any(chanSettings.electrode>15)
		expParam = 'An active electrode is out of range.';
		return;
	end;
elseif strcmpi(chanSettings.configtype,'sQP') && all([sigmaval_m sigmaval_p]==0)
	if any(chanSettings.electrode<2)
		expParam = 'An active electrode is out of range.';
		return;
	end;
end;

switch runmode					% zero uA minimum level is only allowed for Manual mode
case 'Manual Level - Masker'
	minlimit = 0;
otherwise						% >= 1 assures dB steps are meaningful
	minlimit = 1;
end;
startlevel(startlevel<minlimit) = minlimit;

levelParam = struct();			% define level parameters for primary channel
levelParam.value = startlevel(chanidx);
levelParam.maxlimit = maxlevel(chanidx);
levelParam.minlimit = minlimit * ones(1,length(chanidx));
levelParam.chanidx = chanidx;
levelParam.valuestring = startstr;
levelParam.maxstring = maxstr;

expParam = struct();			% define experiment-specific parameters, incl. current level for secondary channel
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
											% additional parameters for secondary channel
expParam.electrode2 = chanSettings2.electrode;
expParam.configtype = chanSettings2.configtype;
expParam.configcode = chanSettings2.configcode;
expParam.level = fixedlevel;
expParam.levelstr = fixedstr2;
expParam.minlevel = 0;
expParam.maxlevel = fixedlevel;				% set max to 'fixedlevel' to pass current level check in CITEST

expParam.chanSettings = chanSettings2;

exppulseSettings = getappdata(handles.expHandles.uipanel,'exppulseSettings');
expParam.ipframes = exppulseSettings.ipframes;	
expParam.numpulses = exppulseSettings.numpulses;
expParam.intvlpulses = exppulseSettings.intvlpulses;
expParam.pulserate = get(handles.expHandles.rate_text,'UserData');
expParam.traindur = get(handles.expHandles.traindur_text,'UserData');

expParam.chgdur = pulseSettings.phdur;		% field required for _EvalLevels; OK here to use primary 'phdur'

switch subtype								% define experiment subtype-specific parameters
case {'Standard Pulse Train','Standard Single Pulse'}
	expParam.polarity = 'cathodic';			% these two pulse-shape parameters are mandatory
	expParam.phgap = 0;
otherwise									% for all PTC sub-experiments, values are fixed
	expParam.polarity = 'cathodic';			% (otherwise, this would be the place to set these pulse
	expParam.phgap = 0;						  % parameters from 'pulseSettings.dataUI')
end;


% --- Outputs the BEDCS and other parameters necessary to run the experiment associated with this m-file --- %
% A function with this name is common to all experiment definitions. Returned output 'bedcsParam' 
% contains everything required by the BEDCS experiment file, and 'ctrlParam' contains everything necessary
% to control those variables via the runtime subGUI. If either is empty, CITEST won't run the experiment.
%	Note that 'ctrlParam.minval' is 0, not 1 (to turn off masker channel); this could cause potential
% issues with the channel sweeping and 2IFC, as +/- dB changes won't change the current if it's at 0 uA.
function [bedcsParam, ctrlParam] = CITest_Exp_TransformParameters(mainParam,expParam,deviceProfile)

pulseSet = mainParam.pulseSettings;
stimdur = pulseSet.traindur;			% some upfront paperwork
configtype = mainParam.configtype;

if strcmpi(configtype,'pTP') && mainParam.configcode(1,1)==0 && expParam.configcode(1,1)==0
	configtype = 'MP';					% ##2015.02.12: simplified by putting more checks in main CITest routine
elseif strcmpi(configtype,'sQP') && mainParam.configcode(1,1)==0 && expParam.configcode(1,1)==0
	configtype = 'sMP';
end;

% Set BEDCS Parameters ######################################################### %
bedcsMain = {'IStimM'};		% by default, block parameter is the channel (electrode, sigma, alpha)
bedcsBlock = {'elecm','sigmam','alpham'}; % note: channel info MUST be in alpha order for "Channel Sweep" mode
bedcsBlockValues = {mainParam.electrode,mainParam.configcode(1,:),mainParam.configcode(2,:)};

switch mainParam.subtype	% BEDCS experiment file (and maybe some parameters) depends on experiment subtype
case 'Standard Pulse Train'
	displaystr = 'Pulse Train PTC (uA)';

	bedcsParam = struct('bedcsexp','','nPhase',pulseSet.phframes,...
		'elecm',mainParam.electrode(1),'sigmam',mainParam.configcode(1,1),'alpham',mainParam.configcode(2,1),...
		'elecp',expParam.electrode2(1),'sigmap',expParam.configcode(1,1),'alphap',expParam.configcode(2,1),...
		'nPulsesM',pulseSet.numpulses,'nZeroM',pulseSet.ipframes,'IStimM',mainParam.level(1),...
		'nPulsesP',expParam.numpulses,'nZeroP',expParam.ipframes,'IStimP',expParam.level(1),...
		'mpgap',expParam.intvlpulses,'IMax',max([mainParam.maxlevel expParam.level]));

	switch configtype
	case 'pTP'
		bedcsexp = 'CITest_fwdmasktrainPTP.bExp';
	case 'sQP'
		bedcsexp = 'CITest_fwdmasktrainSQP.bExp';
	case 'sMP'
		bedcsexp = 'CITest_fwdmasktrainSMP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigmam','sigmap'});
		bedcsBlock = {'elecm','alpham'};
		bedcsBlockValues = {mainParam.electrode,mainParam.configcode(2,:)};
	case 'MP'
		bedcsexp = 'CITest_fwdmasktrainMP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigmam','sigmap','alpham','alphap'});
		bedcsBlock = {'elecm'};
		bedcsBlockValues = {mainParam.electrode};
	case 'BP'
		bedcsexp = 'CITest_fwdmasktrainBP.bExp';
		bedcsParam = rmfield(bedcsParam,{'sigmam','sigmap','alpham','alphap'});
		bedcsParam = setfield(bedcsParam,'sepm',mainParam.configcode(1,1)+1);
		bedcsParam = setfield(bedcsParam,'sepp',expParam.configcode(1,1)+1);
		bedcsBlock = {'elecm','sepm'};
		bedcsBlockValues = {mainParam.electrode,mainParam.configcode(1,:)+1};
	otherwise
		bedcsexp = '';
	end;

case 'Standard Single Pulse'
	displaystr = '1-pulse PTC (uA)';

	switch configtype
	case 'pTP'
		bedcsexp = '';
	case 'sQP'
		bedcsexp = '';
	case 'MP'
		bedcsexp = '';
	case 'BP'
		bedcsexp = '';
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

intvl = expParam.stimintvl;
intvldelay = deviceProfile.intvldelay;
blockintvl = expParam.sweepintvl;

switch mainParam.runmode
case 'Manual Level - Masker'
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
		xlbl = 'Msk Ch:';
	else
		xval = 1:length(mainParam.electrode);
		xlbl = 'Ch Idx:';
	end;
	viewSetup.xlabel = xlbl;
	viewSetup.xvalues  = xval;

case {'2-Interval Forced Choice','3-Interval Forced Choice'}
	rungui = 'CITest_RunGUI_2IFC';

	runSetup.upstep = expParam.upstep;
	runSetup.downstep = expParam.downstep;
	runSetup.upstepend = expParam.upstepend;
	runSetup.downstepend = expParam.downstepend;
	runSetup.revswitch = min(expParam.nrevswitch,expParam.nreversals);

	runSetup.stepunit = 'db';
	runSetup.stepsign = -1;				% negative because increasing masking decreases perception of probe
	runSetup.upcorrect = 2;				% i.e. a two-up, one-down procedure
	runSetup.downwrong = 1;
	runSetup.offvalues = [0];			% probe level is 0 uA for off-interval stimuli

	runSetup.oncolor = [1 1 .4];
	runSetup.offcolor = [.90 .90 .82];

	runSetup.minstop = 6;
	runSetup.maxstop = 6;
	runSetup.stimstop = 60;

	runSetup.nreversals = expParam.nreversals;
	runSetup.naverages = expParam.naverages; 

	intvl = expParam.stimintvl; dwell = 0;

	if strcmp(mainParam.runmode,'3-Interval Forced Choice')
		querystr = 'Pick the interval with the different sound.';
	else
		querystr = 'Which interval contained the target sound?';
	end;

	bedcsBlock = {'IStimP'};			% block parameter interpreted as changing with the two intervals; if empty,
	bedcsBlockValues = {[bedcsParam.(bedcsBlock{1}) 0]}; % main variable will be used with bBValues{} = [x 0], for x varying

	viewSetup.xlabel = 'Stim #:';
	viewSetup.xvalues  = [];

	if strcmp(mainParam.runmode,'3-Interval Forced Choice')
		runSetup.offvalues = [0 0];		% special conditions for the 3-IFC mode, so it can use the 2IFC m-file
	end;

case 'Channel Sweep'
	rungui = 'CITest_RunGUI_Tracking';

	runSetup.buttondown.label = '';
	runSetup.buttondown.color = [.77 .87 .77];	% green when button is pressed, orange when not
	runSetup.buttonup.label = '';
	runSetup.buttonup.color = [1.00 .80 .60];
												% rate of variable change (in parameter units per interval)
	runSetup.buttondown.rate = +expParam.upstep;	% RAISE the masker current when stimulus is heard
	runSetup.buttonup.rate = -expParam.downstep;	% LOWER the masker current when stimulus is not heard
	runSetup.rateunit = 'db';						% (intentionally opposite of _Exp_Threshold case)

	runSetup.direction = expParam.direction;	% direction of sweeping, and extra number of '.pad' blocks at start
	runSetup.pad = 20;							% if small enough '.padrev', stop padding after that many reversals
	runSetup.padrev = 2;
												% time to pause after a stimulus presentation (in msec)
	dwell = round(intvl - intvldelay - stimdur);

	querystr = 'Press <SPACEBAR> when you hear target sound. Release when you don''t.';

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
% For some experiment types, formatting won't need to change compared to the run-time GUI output.
function [runResults,runSummary] = CITest_Exp_ProcessResults(mainParam,ctrlParam,runOutput)

runResults = runOutput;
runSummary = [];

switch mainParam.runmode

case 'Manual Level - Masker'

case {'2-Interval Forced Choice','3-Interval Forced Choice'}
	if isempty(runResults.results)
		disp('Some fields of ''runResults'' could not be set.')
		return;
	end;

	figure;
	plot(1:length(runResults.results),runResults.results,'o-');
	hold on;
	revidx = find(runResults.reversals);
	plot(revidx,runResults.results(revidx),'r*');

	navg = ctrlParam.runSetup.naverages;
	avgnum = min(length(revidx),navg); 
	revidx = revidx(end-avgnum+1:end);
	if length(revidx)>2
		avgidx = revidx;
	else
		nData = length(runResults.results);
		avgidx = nData-navg+1:nData;
	end;

	valuesdb = 20*log10(runResults.results);
	avgthrdb = mean(valuesdb(avgidx));
	stdthrdb = std(valuesdb(avgidx));
	avgthr = 10.^(avgthrdb/20);

	runResults.avgthr = avgthr;
	runResults.avgthrdb = avgthrdb;
	runResults.stdthrdb = stdthrdb;

	fprintf(1,'Avg masker level over last %d reversals is %0.1f uA (%0.1f +/- %0.2f dB uA)\n',...
	  avgnum,avgthr,avgthrdb,stdthrdb);
	if sum(runResults.reversals) < ctrlParam.runSetup.nreversals
		fprintf(1,'* Target number of reversals, %d, was not met for this run.\n',ctrlParam.runSetup.nreversals);
	end;
	if length(revidx) <= 2
		fprintf(1,'* Average was evaluated over last %d data points, instead of reversals.\n',length(avgidx));
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


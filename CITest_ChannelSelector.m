function varargout = CITest_ChannelSelector(varargin)
% CITEST_CHANNELSELECTOR MATLAB code for CITest_ChannelSelector.fig
% Last Modified by GUIDE v2.5 20-Mar-2013 12:18:29
%	This utility GUI allows multiple electrodes and current steering to be
% specified for the main GUI, CITest. It can only be launched from CITest
% and requires three input arguments. See '_OpeningFcn()' for details.
%
% REVISION HISTORY
%	Created on March 21, 2013 by SMB.
%	10/08/2013: Changed impedance values from Ohm to kOhm.
%	07/24/2014: Changed first line to allow multiple instances to run. Within
% CITEST, creation of the GUI and the obtaining of new field values are now
% separate. The primary call from CITEST is via CHANNELSELECTOR_UPDATEFIELDS().
%	07/24/2014: A full channel-by-channel update of fields, such as for
% MCL and impedance, is now only performed when either the Ch. Selector GUI window
% is first created (or re-created following an error) OR when the last set of
% field changes was cancelled via the "X" or CANCEL buttons.
%	09/10/2014: Corrected allowable electrode choices for the BP configuration by
% adding 1 to 'configval'. Convention is for a value of 0 to correspond to "BP+0",
% for which the active and return electrodes are adjacent, separated by 1 electrode.
%

% --- Begin initialization code - DO NOT EDIT --- %
gui_Singleton = 0;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_ChannelSelector_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_ChannelSelector_OutputFcn, ...
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


% --- Executes just before CITest_ChannelSelector is made visible --- %
function CITest_ChannelSelector_OpeningFcn(hObject, eventdata, handles, varargin)

guititle = varargin{2};				% (to avoid error, first var argument is [])
set(hObject,'Name',guititle);
setappdata(hObject,'newfill',true); % whenever window is created, populate fields with latest (or initial) settings

if nargin>5 && iscell(varargin{3})
	offList = varargin{3};
	hturnoff = gobjects(0);

	for i = 1:length(offList)		% turn off UI elements, according to input arguments
		switch offList{i}
		case 'electrode'
			hset = gobjects(1,16);
			for ich = 1:16
				hset(ich) = eval( sprintf('handles.elec%02d_radiobutton',ich) );
			end;
			hturnoff = cat(2,hturnoff,hset,handles.fastset_pushbutton);
		case 'alpha'
			hturnoff = cat(2,hturnoff,handles.alpha_popup,handles.alpha_edittext);
		case 'threshold'
			hset = gobjects(1,16);
			for ich = 1:16
				hset(ich) = eval( sprintf('handles.thr%02d_edittext',ich) );
			end;
		case 'mcl'
			hset = gobjects(1,16);
			for ich = 1:16
				hset(ich) = eval( sprintf('handles.mcl%02d_edittext',ich) );
			end;
		case 'impedance'
			hset = gobjects(1,16);
			for ich = 1:16
				hset(ich) = eval( sprintf('handles.imped%02d_edittext',ich) );
			end;
		end;
	end; % for i = offList %

	set(hturnoff,'Enable','Off');
end;

handles.output = hObject;
guidata(hObject,handles);


% --- Outputs from this function are returned to the calling function --- %
function varargout = CITest_ChannelSelector_OutputFcn(hObject, eventdata, handles)

varargout{1} = handles.output;



%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Turn individual channels, or all channels, ON and OFF with a common callback function --- %
% Note that, for the special "all channels" operation, adherence to configuration rules re: allowable
% channels should have already been enforced.
function electrode_radiobutton_Callback(hObject, eventdata, handles)

if islogical(eventdata) && length(eventdata)==16
	newonoff = eventdata;		% nonempty 'eventdata' argument indicates a special case ..
	for ich = 1:16
		hfield = eval( sprintf('handles.elec%02d_radiobutton',ich) );
		set(hfield,'Value',double(newonoff(ich)));
	end;

else							% .. otherwise, just process the single electrode of chosen radio button
	tagstr = get(hObject,'tag');
	elecnum = str2num(tagstr(5:6));	% radiobutton name is always 'elecXX'

	newonoff = get(handles.fastset_pushbutton,'UserData');
	newstate = get(hObject,'Value'); % 1 = ON, 0 = OFF

	if newstate					% if trying to turn electrode ON, see if it's valid
	configtype = handles.mainSettings.configtype;
	configval = handles.mainSettings.configval;
	
	switch configtype			% acceptable electrode channel depends on configuration
	case 'pTP'
		if configval>0
			valid = (elecnum-1)>=1 && (elecnum+1)<=16;
		else
			valid = elecnum>=1 && elecnum<=16;
		end;
	case 'sQP'
		if configval>0
			valid = (elecnum-2)>=1 && (elecnum+1)<=16;
		else
			valid = (elecnum-1)>=1 && elecnum<=16;
		end;
	case 'BP'					% active electrode is the more basal of the pair
		valid = elecnum-(configval+1)>=1 && elecnum<=16;
	end;

	if ~valid
		set(hObject,'Value',0);	% if not valid, turn the electrode back OFF!
		newonoff(elecnum) = false;
	else
		newonoff(elecnum) = true;
	end;

	else
	newonoff(elecnum) = false;

	if sum(newonoff) == 0		% if all electrodes would be OFF, turn this one back ON!!
		set(hObject,'Value',1);
		newonoff(elecnum) = true;
	end;

	end; % if newstate %

end; % if islogical(eventdata) %

if sum(newonoff) == 1			% indicate what the "fast set" button's function should be
	displaystr = 'M-ELEC';		% press = turn all valid electrodes ON
else
	displaystr = '1-ELEC';		% press = turn one valid electrode ON (#8, in middle)
end;

set(handles.fastset_pushbutton,'String',displaystr,'UserData',newonoff);


% --- Handle changes to the impedance text fields --- %
% This also updates compliance, based on Leo Litvak's phase duration-based forumula.
% Non-empty 'eventdata' skips invalid entry sequence.
function impedance_edittext_Callback(hObject, eventdata, handles)

inputstr = get(hObject,'String');
inputval = sscanf(inputstr,'%f');

tagstr = get(hObject,'Tag');			% figure out the matching handle for the compliance current text field
elecnum = str2num(tagstr(6:7));			  % ('hObject' impedance handle is always 'impedXX_edittext')
hcompl = eval( sprintf('handles.complimit%02d_edittext',elecnum) );

nanflag = false;						% treat NaN entries specially
if strcmpi(inputstr,'nan') || strcmp(inputstr,'--')
	valid = false; nanflag = true;
elseif isempty(inputval)
	valid = false;
else
	inputval = inputval(1);
	valid = inputval>=.5 && inputval<=80;
end;

if nanflag
	newval = nan;
elseif ~valid							% if invalid string, revert to last valid one ..
	newval = get(hObject,'UserData');
	if isempty(eventdata)
		set(hObject,'ForegroundColor','r');
		pause(0.2);
		set(hObject,'ForegroundColor','k');
	end;
else
	newval = inputval;					% .. otherwise accept it
end;

if isnan(newval)						% format the displayed string, and update the stored value
	newstr = '--';
	compl = 333;						% also calculate the compliance limit (default to a small value)
else
	newstr = sprintf('%.2f',newval);
	phdur = handles.mainSettings.phdur;	% this value was taken from the main GUI in '_OpeningFcn()'
	compl = floor( 1000*7.1 / (newval+0.01*phdur) );
end;
										% update both the impedance and compliance text fields
set(hObject,'String',newstr,'UserData',newval);
set(hcompl,'String',sprintf('%03d',compl),'UserData',compl);  


% --- Handle changes to the threshold and MCL text fields --- %
% Non-empty 'eventdata' skips invalid entry sequence.
function threshold_edittext_Callback(hObject, eventdata, handles)

inputstr = get(hObject,'String');
inputval = sscanf(inputstr,'%d');

nanflag = false;						% treat NaN entries specially
if strcmpi(inputstr,'nan') || strcmp(inputstr,'--')
	valid = false; nanflag = true;
elseif isempty(inputval)
	valid = false;
else
	inputval = inputval(1);
	valid = inputval>=0 && inputval<=2000;
end;

if nanflag
	newval = nan;
elseif ~valid							% if invalid string, revert to last valid one ..
	newval = get(hObject,'UserData');
	if isempty(eventdata)
		set(hObject,'ForegroundColor','r'); pause(0.2);
		set(hObject,'ForegroundColor','k');
	end;
else
	newval = inputval;					% .. otherwise accept it
end;

if isnan(newval)						% format the displayed string, and update the stored value
	newstr = '--';
else
	newstr = sprintf('%d',newval);
end;

set(hObject,'String',newstr,'UserData',newval);


function mcl_edittext_Callback(hObject, eventdata, handles) %#ok<*INUSD>

inputstr = get(hObject,'String');
inputval = sscanf(inputstr,'%d');

nanflag = false;						% treat NaN entries specially
if strcmpi(inputstr,'nan') || strcmp(inputstr,'--')
	valid = false; nanflag = true;
elseif isempty(inputval)
	valid = false;
else
	inputval = inputval(1);
	valid = inputval>=1 && inputval<=2000;
end;

if nanflag
	newval = nan;
elseif ~valid							% if invalid string, revert to last valid one ..
	newval = get(hObject,'UserData');
	if isempty(eventdata)
		set(hObject,'ForegroundColor','r'); pause(0.2);
		set(hObject,'ForegroundColor','k');
	end;
else
	newval = inputval;					% .. otherwise accept it
end;

if isnan(newval)						% format the displayed string, and update the stored value
	newstr = '--';
else
	newstr = sprintf('%d',newval);
end;

set(hObject,'String',newstr,'UserData',newval);


% --- Handle calls to the "alpha range" popup menu --- %
% This popup menu determines whether the entry in the associated editable textbox is treated as a single value
% ("Alpha Value") or the step size for a range of values ("Alpha Step"). If the basic type of alpha range
% setting ("single value" or "step") is changed, the value in the textbox is set to a default value (1.0 for single
% a value and 0.1 for step size).
% Note that the actual alpha setting, for use in CITest, is not updated until the Channel Selector subGUI is closed.
function alpha_popup_Callback(hObject, eventdata, handles)

alphatype = get(hObject,'Value');
alphatype_last = get(hObject,'UserData');
alphaval = get(handles.alpha_edittext,'UserData');

if alphatype == 1
	textlabel = 'Alpha Value';
	if ~strcmp(alphatype_last,textlabel);
		alphaval = 1.0;			% this is the default "single value" value
	end;
else
	textlabel = 'Alpha Step';
	if ~strcmp(alphatype_last,textlabel);
		alphaval = 0.1;			% this is the default "step size" value
	end;
end;

set(handles.alphalabel_text,'String',textlabel);
set(hObject,'UserData',textlabel);	% keep track of the alpha setting for next time popup menu is activated
								% force the text box alpha entry to change (e.g. by reset to a default or adjustment of step size)
set(handles.alpha_edittext,'String','','UserData',alphaval);
alpha_edittext_Callback(handles.alpha_edittext,[],handles);


% --- Handle calls to the alpha value / alpha step text field %
function alpha_edittext_Callback(hObject, eventdata, handles)

alphatype = get(handles.alpha_popup,'Value');
inputval = sscanf(get(hObject,'String'),'%f');

if isempty(inputval)
	valid = false;
else
	inputval = inputval(1);
	switch alphatype
	case 1				% single value
		valid = inputval>=0 && inputval<=1;
	case 2				% step size for range 0.0-1.0
		valid = inputval>=0.02 && inputval<=1;
	case {3,4}			% step size for ranges 0.5-1.0 and 0.0-0.5
		valid = inputval>=0.02 && inputval<=0.5;
	otherwise
		valid = inputval>=0 && inputval<=1;
	end;
end;

if ~valid						% if invalid string, revert to last valid one ..
	newval = get(hObject,'UserData');
	set(hObject,'ForegroundColor','r'); pause(0.2);
	set(hObject,'ForegroundColor','k');
else
	newval = inputval;			% .. otherwise accept it
end;

switch alphatype				% tweak step size values to get an integer number of steps
case 1
	nsteps = 0;					% (don't do anything if the value doesn't represent a step size)
case 2
	nsteps = round(1/newval);
	newval = 1/nsteps;
case {3,4}
	nsteps = round(0.5/newval);
	newval = 0.5/nsteps;
end;
nsteps = nsteps + 1;
								% update the displayed textbox value and its tooltip
tipstr = sprintf('# alpha values = %d',nsteps);
set(hObject,'String',sprintf('%.2f',newval),'UserData',newval,'ToolTip',tipstr);


% --- Handle calls to the 1-CHAN/ALL-CHAN push button --- %
function fastset_pushbutton_Callback(hObject, eventdata, handles)

onoffvec = get(hObject,'UserData');
if sum(onoffvec)==1				% safer than using the current string entry
	setmode = 'M-ELEC';
else
	setmode = '1-ELEC';
end;

newonoff = false(1,16);

switch setmode
case '1-ELEC'					% turn on one middle electrode (#8, which will always be valid) ..
	newonoff(8) = true;
	set(hObject,'String','M-ELEC');

otherwise						% .. or turn on all electrodes that are valid based on configuration
	configtype = handles.mainSettings.configtype;
	configval = handles.mainSettings.configval;
	
	switch configtype
	case 'pTP'
		if configval>0
			newonoff(2:15) = true;
		else
			newonoff(1:16) = true;
		end;
	case 'sQP'
		if configval>0
			newonoff(3:15) = true;
		else
			newonoff(2:16) = true;
		end;
	case 'BP'					% note that a 'configval' of 0 ("BP+0") means apical return electrode is 1 away
		newonoff((configval+1)+1:16) = true; % (so must add 1 to value)
	end;

	set(hObject,'String','1-ELEC');
end; % switch setmode %
								% evoke callback in a special manner, setting buttons for all electrodes at once
electrode_radiobutton_Callback(handles.elec01_radiobutton,newonoff,handles);


% --- Handle calls to close the subGUI with the SAVE and CANCEL buttons --- %
function save_pushbutton_Callback(hObject, eventdata, handles)

setappdata(handles.citest_selectgui,'goodtogo',true);
uiresume;						% return execution to _UPDATEFIELDS, and save profile


% --- Handle an attempt to close the GUI figure, by way of the "X" or CANCEL buttons --- %
function CITest_ChannelSelector_CloseFcn(handles)

query = questdlg('Closing this way will not save the channel settings. Close window anyway?','Close Request','No');
if strcmp(query,'Yes')
	if strcmp(get(handles.citest_selectgui,'waitstatus'),'waiting')
		uiresume;				% return execution to _UPDATEFIELDS, but don't save profile ('goodtogo' = 0)
	else						% OR  an error occurred, so just close the subGUI
		delete(handles.citest_selectgui);
	end;
end;



%%%% AUXILIARY FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Main function, called from CITEST, to refresh the Ch. Select subGUI and wait for new values --- %
% 'lastProfile' is the last set of entries for this subGUI; 'mainSettings' contains select stimulus
% parameters currently set in the main GUI.
function chanProfile = CITest_ChannelSelector_UpdateFields(hgui,lastProfile,mainSettings)

chanProfile = [];
handles = guidata(hgui);
handles.mainSettings = mainSettings;

setappdata(hgui,'goodtogo',false);
set(hgui,'Visible','Off','WindowStyle','Modal');

newfill = getappdata(hgui,'newfill');
CITest_ChannelSelector_Populate(handles,lastProfile,mainSettings,newfill);

setappdata(hgui,'newfill',false);
set(hgui,'Visible','On'); drawnow;

guidata(hgui,handles);		% some UIs use 'handles.mainSettings'
uiwait;						% now wait until SAVE or CANCEL button pressed before giving control back to CITest

if ~getappdata(hgui,'goodtogo')		% if subGUI stopped without saving, return an empty matrix ..
	set(hgui,'Visible','Off','WindowStyle','Normal'); drawnow;
	setappdata(hgui,'newfill',true);
	return;
end;
									% .. otherwise, create a structure containing the channel settings
onoffvec = false(1,16); thrvec = nan(1,16); mclvec = nan(1,16);
impedvec = nan(1,16); complvec = nan(1,16);
for ich = 1:16						% read values directly from the UI elements, one at a time
	hfield = eval( sprintf('handles.elec%02d_radiobutton',ich) );
	if get(hfield,'Value'), onoffvec(ich) = true; end;

	hfield = eval( sprintf('handles.thr%02d_edittext',ich) );
	thrvec(ich) = get(hfield,'UserData');

	hfield = eval( sprintf('handles.mcl%02d_edittext',ich) );
	mclvec(ich) = get(hfield,'UserData');

	hfield = eval( sprintf('handles.imped%02d_edittext',ich) );  
	impedvec(ich) = get(hfield,'UserData');

	hfield = eval( sprintf('handles.complimit%02d_edittext',ich) );
	complvec(ich) = get(hfield,'UserData');
end;

chanProfile.onoff = onoffvec;
chanProfile.stimspec = [];
chanProfile.threshold = thrvec;
chanProfile.mcl = mclvec;
chanProfile.impedance = impedvec;
chanProfile.compliance = complvec;

chanProfile.alphatype = get(handles.alpha_popup,'Value');
chanProfile.alphaval = get(handles.alpha_edittext,'UserData');
chanProfile.alphavector = CITest_ChannelSelector_EvaluateAlpha(chanProfile);

chanProfile.stimspec.configtype = mainSettings.configtype;
chanProfile.stimspec.configval = mainSettings.configval;
chanProfile.stimspec.phdur = mainSettings.phdur;
chanProfile.stimspec.traindur = mainSettings.traindur;
chanProfile.stimspec.pulserate = mainSettings.pulserate;
									% if Ch. Selector window should be deleted, do this from calling function
set(hgui,'Visible','Off','WindowStyle','Normal'); drawnow;


% --- Fill in Channel Selector fields from the last saved profile ('chanProfile' in CITest) --- %
% Now, the full population will only occur if the primary stimulus parameters don't match OR
% if instructed via the 'newfill' argument.
function CITest_ChannelSelector_Populate(handles,initProfile,mainSettings,newfill)
										% first, see if current stim params match those of the old profile ("main/last match")
mlmatch = CITest_ChannelSelector_Match(mainSettings,initProfile);
										% next, update the stimulus information text boxes (w/ main GUI values)
infostr = sprintf('STIM PARAMETERS\nConfig:   %s\nSigma:  %01.2f',mainSettings.configtype,mainSettings.configval);
set(handles.configinfo_text,'String',infostr);
infostr = sprintf('Phase dur:  %0.1f\nTrain dur:   %0.1f\nTrain rate:  %s',mainSettings.phdur, ...
  mainSettings.traindur,mainSettings.ratestr);
set(handles.traininfo_text,'String',infostr);

if newfill || ~mlmatch
  nChan = length(initProfile.onoff);	% finally, fill in all of the UI fields in the subGUI
  for ich = 1:nChan
	impval = initProfile.impedance(ich);
	hfield = eval( sprintf('handles.imped%02d_edittext',ich) );
	set(hfield,'String','','UserData',impval);
	impedance_edittext_Callback(hfield,0,handles);

	if mlmatch							% thr and MCL entries only valid for specific pulse train parameters
		thrval = initProfile.threshold(ich);
		mclval = initProfile.mcl(ich);
	else								% default to undefined (NaN)
		thrval = NaN;
		mclval = NaN;
	end;
	
	hfield = eval( sprintf('handles.thr%02d_edittext',ich) );
	set(hfield,'String','','UserData',thrval);
	threshold_edittext_Callback(hfield,0,handles);

	hfield = eval( sprintf('handles.mcl%02d_edittext',ich) );
	set(hfield,'String','','UserData',mclval);
	mcl_edittext_Callback(hfield,0,handles);
  end; % for ich %
end; % if newfill %

melec = mainSettings.electrode;			% this can be a scalar (for one channel) or a vector (for multiple)
onoffvec = false(1,16);
onoffvec(melec) = true;
										% evoke callback in a special manner, setting buttons for all electrodes at once
electrode_radiobutton_Callback(handles.elec01_radiobutton,onoffvec,handles); % (this also initializes the FASTSET pushbutton)

if length(mainSettings.alpha)==1		% set alpha range menu setting depending on if its a single value or not
	alphatype = 1; alphatype_str = 'Alpha Value';
	alphaval = mainSettings.alpha;
else									% if 'range', use the previous settings
	alphatype = initProfile.alphatype; alphatype_str = 'Alpha Step';
	alphaval = initProfile.alphaval;
end;
										% make sure quick-set button is labeled correctly
% set(handles.fastset_pushbutton,'UserData',onoffvec);
% fastset_pushbutton_Callback(handles.fastset_pushbutton, [], handles)

set(handles.alpha_edittext,'String','','UserData',alphaval);
set(handles.alpha_popup,'Value',alphatype,'UserData',alphatype_str);
alpha_popup_Callback(handles.alpha_popup,[],handles);
alpha_edittext_Callback(handles.alpha_edittext,[],handles);


% --- See if the current CITest settings match the current Channel Selector settings --- %
function mlmatch = CITest_ChannelSelector_Match(mainSettings,initProfile)

mlmatch = strcmp(mainSettings.configtype,initProfile.stimspec.configtype);
mlmatch = mlmatch && mainSettings.configval==initProfile.stimspec.configval;
mlmatch = mlmatch && mainSettings.phdur==initProfile.stimspec.phdur;
mlmatch = mlmatch && mainSettings.traindur>=0.95*initProfile.stimspec.traindur && ...
  mainSettings.traindur<=1.05*initProfile.stimspec.traindur;
mlmatch = mlmatch && mainSettings.pulserate>=0.95*initProfile.stimspec.pulserate && ...
  mainSettings.pulserate<=1.05*initProfile.stimspec.pulserate;


% --- Interpret the alpha settings, so the UI fields in CITest can be properly filled --- %
function alphavector = CITest_ChannelSelector_EvaluateAlpha(chanProfile)

switch chanProfile.alphatype
case 1	% 'alphaval' is the actual value of alpha %
	alphavector = chanProfile.alphaval;
case 2	% 'alphaval' represents the step size for a range of alphas %
	alphavector = 0:chanProfile.alphaval:1;
case 3
	alphavector = 0:chanProfile.alphaval:0.5;
case 4
	alphavector = 0.5:chanProfile.alphaval:1;
otherwise % this should not occur %
	alphavector = NaN;
end;

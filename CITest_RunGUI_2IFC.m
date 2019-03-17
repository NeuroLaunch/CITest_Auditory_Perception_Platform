function varargout = CITest_RunGUI_2IFC(varargin)
% CITEST_RUNGUI_2IFC MATLAB code for CITest_RunGUI_2IFC.fig
% Not Created or Modified by GUIDE.
%
%	Run-time GUI that conducts a "2-interval forced choice" stimulation experiment for the
% main CITest "control" GUI application (see CITEST.M). This application can be used for
% a variety of experiment modes, including thresholds and psychophysical tuning curves.
% It is currently designed to handle two or three intervals, with each number requiring
% a different GUI figure and base m-file (e.g. CITest_RunGUI_3IFC.fig and ".m) even though
% the bulk of callback and other routines are handled here in the CITest_RunGUI_2IFC.m.
%
% REVISION HISTORY
%	CITest_RunGUI_2IFC, created September 2013 by SMB.
%	2014.09.10. Worked around the ridiculous graphical bug (in old and new versions of MATLAB)
% that would place a border around the last pressed UI toggle button, despite all attempts to
% deselect the buttons via conventional MATLAB commands. The solution was to gain access to the
% button's JAVA properties via the 3rd party FINDJOBJ function (available from the Uncocumented
% Matlab website). Eesh.
%	2014.10.03. The stimulus parameter that varies with interval can now be specified using the
% 'ctrlParam.bedcsBlock and '.bedcsBlockValues' settings from the experiment subgui. This is
% useful for cases, like with a masker and probe, where the main variable does not change
% between intervals.
%	There is now a polarity control parameter, '.stepsign', to determine whether the variable
% stimulus parameter steps up or down in amplitude. This is also useful for masker/probe runs.
%	2014.11.14. Adjusted code to handle 3-interval run mode. This is accomplished by switching
% out the usual CITest_RunGUI_2IFC.fig MATLAB figure for CITest_RunGUI_3IFC.fig. All of the
% callbacks and other routines are handled by this m-file, whether 2 or 3 intervals.
%	03/10/2014. Added 'bedcsParam' to input arguments and rearranged others.
%

% --- Begin initialization code - DO NOT EDIT --- %
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_RunGUI_2IFC_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_RunGUI_2IFC_OutputFcn, ...
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


% --- Executes just before CITest_RunGUI_2IFC (or _3IFC) is made visible --- %
% The four variable input arguments are a structure of control parameters ('ctrlParam'),
% the handle to the main CITest GUI, a demo mode toggle, and instructions for where
% to place the run-time GUI window.
function CITest_RunGUI_2IFC_OpeningFcn(hObject, eventdata, handles, varargin)

ctrlParam = varargin{1};			% first, determine if the figure must be switched
if length(ctrlParam.runSetup.offvalues)>1 % to the 3-IFC version
	hNew = openfig('CITest_RunGUI_3IFC.fig','reuse','invisible');
	hOrig = hObject;
	handles = guihandles(hNew);
	hObject = hNew;
else
	hOrig = [];
end;

% Initialize the GUI display and status, and check for proper loading conditions %
setappdata(hObject,'ready',false);		% the "tracking" pushbutton will change this to TRUE

if nargin < 6
	warning('An input argument was not specified.');
	set(handles.text_feedback,'String','Loading Error','ForeGroundColor','r');
	handles.output = 0; guidata(hObject,handles);
	return;
end;

if nargin < 7
	handles.demomode = false;
else handles.demomode = varargin{4};
end;

handles.ctrlParam = varargin{1};		% 'ctrlParam', specifies the run-time parameters %
handles.bedcsParam = varargin{2};

hmain = varargin{3};					% the handle to the main gui gives access to other variables and handles
hactx = getappdata(hmain,'hactx');
hresults = getappdata(hmain,'hresults');
hview = findobj(hresults,'tag','axes_results');
hlbl = findobj(hresults,'tag','text_blockstr');

setappdata(hObject,'hmain',hmain);
setappdata(hObject,'hactx',hactx);
setappdata(hObject,'hresults',hresults);
setappdata(hObject,'hview',hview);
setappdata(hObject,'hlbl',hlbl);

% Other setup %
if ~isempty(hOrig)						% if a figure switch was made, make sure _OutputFcn() executes smoothly
	ohandles = guidata(hOrig);
	ohandles.output = hObject;			% in this case, the original figure MUST have certain fields defined
% 	ohandles.guipos = guipos;
	ohandles.citest_rungui = hObject;
	guidata(hOrig,ohandles);
										% also, makes sure to account for the extra UI element for the new figure
	hbuttonset = [handles.togglebutton_intvl1 handles.togglebutton_intvl2 handles.togglebutton_intvl3];
else
	hbuttonset = [handles.togglebutton_intvl1 handles.togglebutton_intvl2];
end;
										% set up the response buttons
set(hbuttonset,'BackGroundColor',handles.ctrlParam.runSetup.offcolor,'Enable','Inactive');
%   'Parent',handles.buttongroup_intervals);
set(handles.buttongroup_intervals,'SelectionChangeFcn',@CITest_RunGUI_HandleButtons);
set(handles.buttongroup_intervals,'SelectedObject',[]);

handles.output = hObject;
guidata(hObject, handles);

CITest_RunGUI_SetupView(hObject,handles); % a utility function common to all run-time GUIs

set(handles.pushbutton_start,'Enable','On');


% --- Outputs from this function are returned to the command line --- %
function varargout = CITest_RunGUI_2IFC_OutputFcn(hObject, eventdata, handles) 

varargout{1} = handles.output;
varargout{2} = 'runsubject';

if hObject ~= handles.output			% if a figure switch was made, delete the original figure
	delete(hObject);
end;



%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Signal to the main CITest GUI that the runtime subGUI is ready %
% The button will be deactivated for the rest of the run. Only the <spacebar> will be used
% for ongoing subject interaction.
function pushbutton_start_Callback(hObject, eventdata, handles)

grcol = [.2 1 .2];				% display the instructions for the task on the button
set(hObject,'String','Get Ready','BackGroundColor',grcol,'Enable','Inactive');

try								% bring interaction GUI figure into "focus" (MatlabCentral #33224)
	jPeer = get(handle(handles.citest_rungui), 'JavaFrame');
 	jPeer.getAxisComponent.requestFocus; % (this will make button presses work better)
catch
	figure(handles.citest_rungui);
end;

pause(1.5);
set(hObject,'Visible','Off');	% hide the start button for the rest of the run
set(handles.text_feedback,'String','','Visible','On'); % turn on the message/feedback text

setappdata(handles.citest_rungui,'ready',true);
uiresume;


% -- Handle attempts to close the GUI figure -- %
function CITest_RunGUI_CloseFcn()

status = getappdata(gcbf,'ready');

if isempty(status)				% if the figure was not launched via CITEST..
	query = questdlg('Do you wish to close the subject response panel?', 'Close Request', 'No');
	if strcmp(query,'Yes')
		closereq;				% .. ask before closing it ..
	end;
else							% .. otherwise force a STOP as if evoked with the CITEST pause button
	CITest_RunGUI_Stop(gcf)
end;



%%%% AUXILIARY FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Utility function called by the main GUI to start the stimulus presentations --- %
function runOutput = CITest_RunGUI_Start(hgui)

runOutput.results = [];
runOutput.complete = false;
runOutput.message = 'Run terminated unexpectedly.';

if ~ishandle(hgui)				% in case the run-time GUI was unexpectedly closed  
	return;
elseif ~getappdata(hgui,'ready')
	runOutput.message = 'Run terminated externally.';
	return;
end;

handles = guidata(hgui);		% get necessary info for BEDCS stimulation and parameter changes
hactx = getappdata(handles.citest_rungui,'hactx');
								% java object handles for the toggle buttons
jintvl1 = findjobj(handles.togglebutton_intvl1);
jintvl2 = findjobj(handles.togglebutton_intvl2);

interstimsec = handles.ctrlParam.intvl / 1000;
stimdursec = handles.ctrlParam.stimdur / 1000;
stimdursec = max(stimdursec,0.10);	% for short trains or single pulses, intvls must flash for at least a little time

upstep = handles.ctrlParam.runSetup.upstep;
downstep = handles.ctrlParam.runSetup.downstep;
stepunit = handles.ctrlParam.runSetup.stepunit;
stepsign = handles.ctrlParam.runSetup.stepsign;
upcorrect = handles.ctrlParam.runSetup.upcorrect;
downwrong = handles.ctrlParam.runSetup.downwrong;

revswitch = handles.ctrlParam.runSetup.revswitch;
revlimit = handles.ctrlParam.runSetup.nreversals;
minlimit = handles.ctrlParam.runSetup.minstop;
maxlimit = handles.ctrlParam.runSetup.maxstop;
stimlimit = handles.ctrlParam.runSetup.stimstop;
								% define handles for the Results View window
hresults = getappdata(handles.citest_rungui,'hresults');
hview = getappdata(handles.citest_rungui,'hview');
								% define button and text colors
oncolor = handles.ctrlParam.runSetup.oncolor;
offcolor = handles.ctrlParam.runSetup.offcolor;
yescolor = [0 .6 0]; nocolor = [1 .1 .1];
								% define some stimulus parameter attributes
minval = handles.ctrlParam.minval(1); % (these should each have only one value anyway)
maxval = handles.ctrlParam.maxval(1);
startval = handles.ctrlParam.startval(1);
bedcsvar = handles.ctrlParam.mainVars{1};
bedcsval = startval;			% set range of values and starting value

offvalues = handles.ctrlParam.runSetup.offvalues;
nintvl = length(offvalues) + 1;	% this can be 2 or 3
if nintvl==2
	hbuttonset = [handles.togglebutton_intvl1 handles.togglebutton_intvl2];
else
	if ~isfield(handles,'togglebutton_intvl3')
		runOutput.message = 'Runtime GUI does not contain a 3rd interval button.';
		return;
	end;
	hbuttonset = [handles.togglebutton_intvl1 handles.togglebutton_intvl2 handles.togglebutton_intvl3];
end;

if ~isempty(handles.ctrlParam.blockVars{1})
	intvlvar = handles.ctrlParam.blockVars{1};
	intvlval = handles.ctrlParam.blockValues{1};
	intvlmode = true;			% "block" parameter changes with interval (e.g. probe level with masking exp.s)
else							% ##SMB: could generalize to more parameters later
	intvlvar = '';
	intvlval = [];
	intvlmode = false;
end;

stimcnt = 0; revcnt = 0; 		% initialize some tracking variables
ncorrect = 0; nwrong = 0;
lastdir = 0;					% no movement = 0; going down = -1; going up = 1
mincnt = 0; maxcnt = 0;

intvlvec = nan(1,2000); respvec = nan(1,2000);
valuevec = nan(1,2000); revvec = nan(1,2000);
gostatus = true;

tstart = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');

while gostatus && getappdata(hgui,'ready')
	stimcnt = stimcnt + 1;		% progress through stimulus trials

	intvlrand = randperm(nintvl); % keep track of which interval will contain the sound
	intvlvec(stimcnt) = find(intvlrand==1);

	if intvlmode				% set either a dedicated second parameter value for the FIRST INTERVAL ..
		stimorder = [intvlval offvalues];  % (in which case the main variable is same for both intervals)
		stimorder = stimorder(intvlrand);
		hactx.Let_ControlVarVal(intvlvar, stimorder(1));
		hactx.Let_ControlVarVal(bedcsvar, bedcsval);
	else						% .. or the primary variable value
		stimorder = [bedcsval offvalues];
		stimorder = stimorder(intvlrand);
		hactx.Let_ControlVarVal(bedcsvar, stimorder(1));
	end;

    set(handles.togglebutton_intvl1,'BackGroundColor',oncolor); drawnow;
	if ~handles.demomode
		hactx.MeasureNoSave;	% play the FIRST INTERVAL
	else
		pause(stimdursec);		% faking it
	end;
	set(handles.togglebutton_intvl1,'BackGroundColor',offcolor); drawnow;

	pause(interstimsec);		% enforce the chosen inter-stimulus duration

	if intvlmode				% repeat for the SECOND INTERVAL
		hactx.Let_ControlVarVal(intvlvar, stimorder(2));
	else
		hactx.Let_ControlVarVal(bedcsvar, stimorder(2));
	end;

    set(handles.togglebutton_intvl2,'BackGroundColor',oncolor); drawnow;
	if ~handles.demomode
		hactx.MeasureNoSave;
	else
		pause(stimdursec);
	end;
	set(handles.togglebutton_intvl2,'BackGroundColor',offcolor); drawnow;

	if nintvl > 2				% repeat for the THIRD INTERVAL for 3IFC runs
	pause(interstimsec);

	if intvlmode
		hactx.Let_ControlVarVal(intvlvar, stimorder(3));
	else
		hactx.Let_ControlVarVal(bedcsvar, stimorder(3));
	end;

    set(handles.togglebutton_intvl3,'BackGroundColor',oncolor); drawnow;
	if ~handles.demomode
		hactx.MeasureNoSave;
	else 
		pause(stimdursec);
	end;
	set(handles.togglebutton_intvl3,'BackGroundColor',offcolor); drawnow;
	end; % if nintvl % 

	pause(0.2);								% display text prompt and wait for a button response							
	set(handles.text_feedback,'String',handles.ctrlParam.querytext,'ForeGroundColor','k');
    set(hbuttonset,'Enable','On');

	if nintvl < 3
		fprintf(1, '\nInterval [1 2] = %0.2f %0.2f', stimorder(1),stimorder(2));
	else
		fprintf(1, '\nInterval [1 2 3] = %0.2f %0.2f %0.2f', stimorder(1),stimorder(2),stimorder(3));
	end;

	uiwait(hgui);
	pause(0.1);

	hchoice = get(handles.buttongroup_intervals,'SelectedObject');
	respbutton = get(hchoice,'UserData');	% this is either a 1 or a 2 (or a 3 with 3IFC)

	set(hbuttonset,'Value',0,'Enable','Inactive');
	set(handles.buttongroup_intervals,'SelectedObject',[]); drawnow;
	set([jintvl1 jintvl2],'FocusPainted',0); % "undocumented" Java trick to remove border of last-pressed button

	if respbutton == intvlvec(stimcnt)		% determine if the response was correct or not
		fbstring = 'Correct!'; fbcolor = yescolor;
		correct = true;
		ncorrect = ncorrect + 1; nwrong = 0;
	else
		fbstring = 'Wrong!'; fbcolor = nocolor;
		correct = false;
		ncorrect = 0; nwrong = nwrong + 1;
	end;
	set(handles.text_feedback,'String',fbstring,'ForeGroundColor',fbcolor);
	pause(0.5);							% show the feedback text for a brief moment
	set(handles.text_feedback,'String','','ForeGroundColor','k');
	pause(0.2);							% a polite pause before going to the next stimulus

	fprintf(1, '    %s\n',fbstring);

	valuevec(stimcnt) = bedcsval;		% store the response information
	respvec(stimcnt) = respbutton;

	if stimcnt > 1						% determine if there was a reversal
	  if lastdir==-1 && nwrong==downwrong
		revvec(stimcnt) = true;
		revcnt = revcnt + 1;
		lastdir = +1;					% update the parameter change direction for next presentation
	  elseif lastdir==+1 && ncorrect==upcorrect
		revvec(stimcnt) = true;
		revcnt = revcnt + 1;
		lastdir = -1;
	  else
		revvec(stimcnt) = false;
	  end;
	elseif correct
		revvec(stimcnt) = false;
		lastdir = -1;
	else
		revvec(stimcnt) = false;
		lastdir = +1;
	end;

	if getappdata(hresults,'display')	% be sure to draw in 'hview' (but don't nec. make it visible)
		set(0,'CurrentFigure',hresults);
		if revvec(stimcnt)
			plot(stimcnt,valuevec(stimcnt),'ro');
		else
			plot(stimcnt,valuevec(stimcnt),'bo');
		end;

		yrng = max(valuevec) - min(valuevec); yrng = max(1,yrng);
		ylimits = [min(valuevec)-.05*yrng max(valuevec)+.05*yrng];
		set(hview,'XLim',[0 stimcnt+.2],'YLim',ylimits);
	end;

	if revcnt >= revswitch				% possibly make step size smaller
		upstep = handles.ctrlParam.runSetup.upstepend;
		downstep = handles.ctrlParam.runSetup.downstepend;
	end;

	if strcmpi(stepunit,'db')
		oldval = 20*log10(bedcsval);
	end;							% if using dB steps, first transform the current variable value

	if stepsign>0					% next stimulus depends on response AND step type and direction
		if ncorrect == upcorrect
			newval = oldval - downstep;
			ncorrect = 0;
		elseif nwrong == downwrong
			newval = oldval + upstep;
			nwrong = 0;
		else
			newval = oldval;
		end;
	else							% 'stepsign' = -1 for cases like forward masking
		if ncorrect == upcorrect
			newval = oldval + upstep;
			ncorrect = 0;
		elseif nwrong == downwrong
			newval = oldval - downstep;
			nwrong = 0;
		else
			newval = oldval;
		end;
	end;

	if strcmpi(stepunit,'db')		% convert back to uA
		newval = 10.^(newval/20);
	end;

	if newval >= .998*maxval			% check if parameter limits are reached (allowing for numerical inaccur.
		newval = maxval;				  % from dB transformation) and count the number of times this has happened
		maxcnt = maxcnt + 1; mincnt = 0;
	elseif newval <= 1.002*minval
		newval = minval;
		mincnt = mincnt + 1; maxcnt = 0;
	else								% reset counts if limit not hit this trial
		mincnt = 0; maxcnt = 0;
	end;
	bedcsval = newval;					% update main parameter value for next time

	if revcnt >= revlimit				% evaluate termination conditions
		gostatus = false;
	end;

	if maxcnt>=maxlimit || mincnt>=minlimit || stimcnt>stimlimit
		gostatus = false;
	end;

end; % while gostatus %

tstop = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');

if ~ishandle(hgui)					% flag early closures (but execution will continue otherwise)
	disp('Run terminated unexpectedly.');
elseif ~getappdata(hgui,'ready')
	disp('Run terminated externally.');
end;

valuevec = valuevec(1:stimcnt);
intvlvec = intvlvec(1:stimcnt);
respvec = respvec(1:stimcnt);
revvec = revvec(1:stimcnt);

clear runOutput;

runOutput.results = valuevec;		% output results, one value for each stimulus
runOutput.stimintvls = intvlvec;
runOutput.responses = respvec;
runOutput.reversals = revvec;
runOutput.nreversal = revcnt;		% scalar

runOutput.complete = length(valuevec) >= revlimit;

runOutput.timing.timestart = tstart;
runOutput.timing.timestop = tstop;

runOutput.message = sprintf('%d of %d reversals completed for N-IFC - %s.',...
  revcnt,revlimit,handles.ctrlParam.displaytext);


% --- Handle response button presses --- %
function CITest_RunGUI_HandleButtons(src, eventdata)

uiresume;


% --- Setup plotting axes in the Results View external window --- %
% For this run-time mode, 
function CITest_RunGUI_SetupView(hgui,handles)

hresults = getappdata(hgui,'hresults');
hview = getappdata(hgui,'hview');
hlbl = getappdata(hgui,'hlbl');

axes(hview); cla;						% put Results View figure into scope and update some text labels
set(hview,'NextPlot','Add');
bedcsvar = handles.ctrlParam.mainVars{1};
ylabel(bedcsvar);
set(hlbl,'String',handles.ctrlParam.viewSetup.xlabel);
										% the min and max fields should already be scalar
minval = handles.ctrlParam.minval(1); maxval = handles.ctrlParam.maxval(1);
plot([0:50],repmat(minval,1,51),'k:');	% draw min/max out to 50 data points (generally sufficient)
plot([0:50]',repmat(maxval,1,51),'k:');

yrng = max(maxval) - min(minval);
ylimits = [min(minval)-.20*yrng max(maxval)+.05*yrng];

set(hview,'XLim',[0.8 5.2],'YLim',ylimits);
if getappdata(hresults,'display');
	set(hresults,'Visible','On');
else
	set(hresults,'Visible','Off');
end;


% --- Handle button presses of the main button in the main control GUI --- %
function CITest_RunGUI_Pause(hgui)

handles = guidata(hgui);		% pause evoked by a modal dialog box.. so there is an inherent wait
UD.data = get(handles.pushbutton_start,'UserData');
UD.bgcolor = get(handles.pushbutton_start,'BackgroundColor');
UD.string = get(handles.pushbutton_start,'String');

set(handles.pushbutton_start,'String','PAUSED','Visible','On','Enable','Inactive',...
  'BackgroundColor',[.90 .90 .08],'UserData',UD);
set(handles.text_feedback,'Visible','Off');


function CITest_RunGUI_Unpause(hgui)

handles = guidata(hgui);
UD = get(handles.pushbutton_start,'UserData');

set(handles.pushbutton_start,'BackgroundColor',UD.bgcolor,'UserData',UD.data);

if ~getappdata(hgui,'ready');	% in case the pause occured prior to RunGUI_Start()
	set(handles.pushbutton_start,'String',UD.string,'Enable','On');
% 	pushbutton_start_Callback(handles.pushbutton_start, [], handles);  %##2015.03.31  to avoid auto-start!!
else
	set(handles.pushbutton_start,'String','','Visible','Off');
	set(handles.text_feedback,'Visible','On');
end;


% --- Handle termination command from the main control GUI --- %
function CITest_RunGUI_Stop(hgui)

handles = guidata(hgui);

if ~getappdata(hgui,'ready') && strcmpi(get(hgui,'waitstatus'),'waiting')
	pushbutton_start_Callback(handles.pushbutton_start, [], handles);
	drawnow;
	setappdata(hgui,'ready',false);	% in case the pause occured prior to RunGUI_Start() ..
elseif ~getappdata(hgui,'ready')	  % (but outright close the figure if something is wrong)
	closereq;
else								% .. otherwise force an exit AFTER the current RunGUI_Start() loop
	set(handles.pushbutton_start,'String','','Visible','Off');
	set(handles.text_feedback,'Visible','On');
	setappdata(hgui,'ready',false);
end;



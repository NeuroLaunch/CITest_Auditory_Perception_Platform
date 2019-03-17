function varargout = CITest_RunGUI_Manual(varargin)
% CITEST_RUNGUI_MANUAL MATLAB code for CITest_RunGUI_Manual.fig
% Last Modified by GUIDE v2.5 14-Jan-2013 16:38:41
%
%	Run-time GUI that conducts manually controlled stimulation presentations for the main
% CITest GUI application (see CITEST.M). Typically this application will be used for
% MCL or threshold experiments, in which case current level is the stimulus parameter
% to be manually adjusted. But it could also be used to present other arbitrary stimuli
% (e.g. pulse trains with gaps) for which a single parameter varies (e.g. level in uA
% or gap duration in usec). Indeed, this subGUI represents an experimental "submode"
% that should be available for all of the primary experiment types.
%	Besided the main variable, this subGUI also recognizes one or more "block" variables,
% such as electrode number or configuration. The NEXT button steps from one set of block
% variable values to the next. The starting and maximum value for the main variable can
% change with each block step (e.g. ctrlParam.startvalue is a vector), but doesn't have to.
%	CITEST_EXP_THRESHOLD is an example of an experiment definition (i.e. a primary
% experiment type, or mode, in the main CITest application) that calls this run-time GUI.
%
%	The code below makes a good starting point for creating new
% runtime / subject-interaction GUIs for CITest. Here is a partial list of the
% required elements that can be found here:
%	- a SETAPPDATA element called 'ready', with an initial state of 'false'; the status
% becomes 'true' automatically (as in this subGUI) or after the user presses a BEGIN button
%	- a callback called CITest_RunGUI_CloseFcn() to handle manual/premature closures of the subGUI;
% the callback must be set in the GUI figure's CLOSEREQUESTFCN property, typically using GUIDE
%	- acceptance of an input argument, 'ctrlParam', which is used to setup the subGUI's display
% and control its behavior over the course of the experimental run
%	- utility functions CITest_RunGUI_Pause(), CITest_RunGUI_Unpause(), and CITest_RunGUI_Stop()
% that are called by the main control GUI
%	- another utility function, CITest_RunGUI_Start(hgui), that initiates the GUI's ability to
% present stimuli (in this case, via the PLAY button); this function invokes a UIWAIT, which stays in
% effect until a UIRESUME is called externally (by the main GUI) or internally (via the DONE button)
%	- a lab-specific setting for where the GUI is displayed on the computer monitor or set of monitors
%	- the name of the subGUI figure is 'citest_rungui'
%
% REVISION HISTORY
%	CITest_RunGUI_Manual, created in January 2013 by SMB.
%	03/10/2014. Added 'bedcsParam' to input arguments and rearranged others.
%

% --- Begin initialization code - DO NOT EDIT --- %  
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_RunGUI_Manual_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_RunGUI_Manual_OutputFcn, ...
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


% --- Executes just before CITest_RunGUI_Manual is made visible --- %
% The four variable input arguments are a structure of control parameters ('ctrlParam'),
% the handle to the main CITest GUI, a demo mode toggle, and instructions for where
% to place the run-time GUI window.
function CITest_RunGUI_Manual_OpeningFcn(hObject, eventdata, handles, varargin)

% Initialize the gui display and status, and check for proper loading conditions %
setappdata(hObject,'ready',false);		% this will become TRUE at the end of the opening function

if nargin < 6
	warning('An input argument was not specified.');
	set(handles.text_parameter,'String','Loading Error','ForeGroundColor','r');
	handles.output = 0; guidata(hObject,handles);
	return;
end;

if nargin < 7
	handles.demomode = false;
else handles.demomode = varargin{4};
end;

handles.ctrlParam = varargin{1};		% 'ctrlParam', specifies the run-time parameters %
handles.bedcsParam = varargin{2};		% 'bedcsParam' won't be used for this GUI

hmain = varargin{3};					% the handle to the main gui gives access to other variables and handles
hactx = getappdata(hmain,'hactx');
hresults = getappdata(hmain,'hresults');
hview = findobj(hresults,'tag','axes_results');
hlbl = findobj(hresults,'tag','text_blockstr');
% if isempty(hview)						% to correct a weird quirk, where an axes 'reset' can make its tag disappear
% 	hview = findall(hresults,'type','axes');
% 	hview = hview(1);
% 	set(hview,'tag','axes_results');
% end;

setappdata(hObject,'hmain',hmain);
setappdata(hObject,'hactx',hactx);
setappdata(hObject,'hresults',hresults);
setappdata(hObject,'hview',hview);
setappdata(hObject,'hlbl',hlbl);

% Setup the main variables and block variables %
mainstr = handles.ctrlParam.displaytext;
set(handles.text_parameter,'String',mainstr);

nBlock = size(handles.ctrlParam.blockValues{1},2);
handles.blocknum = 0;
pushbutton_nextprev_Callback(handles.pushbutton_next,'+',handles);
handles.blocknum = 1;					% initialize index for block variables

if nBlock>1 && length(handles.ctrlParam.startval)==1
	handles.ctrlParam.startval = handles.ctrlParam.startval * ones(1,nBlock);
end;									% vectorize main + limit values, if necessary,
if nBlock>1 && length(handles.ctrlParam.minval)==1  % to match block variables
	handles.ctrlParam.minval = handles.ctrlParam.minval * ones(1,nBlock);
end;
if nBlock>1 && length(handles.ctrlParam.maxval)==1
	handles.ctrlParam.maxval = handles.ctrlParam.maxval * ones(1,nBlock);
end;

% Set the starting value for the first or only step % 
set(handles.text_value,'String','','UserData',handles.ctrlParam.startval(1));
text_value_Callback(handles.text_value,[],handles);

set(handles.pushbutton_play,'UserData',1);

% Perform other setup %
bgcol = get(handles.text_statusbar,'BackGroundColor');
set(handles.text_statusbar,'UserData',bgcol);

if ~isempty(handles.ctrlParam.runSetup)
	stepstart = handles.ctrlParam.runSetup.stepstart;
	set(handles.popupmenu_units,'String',handles.ctrlParam.runSetup.steplabels,'Value',stepstart,...
	  'UserData',handles.ctrlParam.runSetup.stepsizes);
	popupmenu_units_Callback(handles.popupmenu_units,[],handles);
end;

handles.finalvalues = nan(1,nBlock);	% for storing all of the final values
handles.output = hObject;
guidata(hObject, handles);

CITest_RunGUI_SetupView(hObject,handles);

setappdata(hObject,'ready',true);		% declare to external MATLAB environment that the subGUI is ready
										  % (other subGUIs might require a BEGIN button to be pressed first)


% --- Outputs from this function are returned to the command line --- %
function varargout = CITest_RunGUI_Manual_OutputFcn(hObject, eventdata, handles)

varargout{1} = handles.output;
varargout{2} = 'runcontroller';



%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Callback for the "PLAY" pushbutton --- %
% This is the only function in which BEDCS is accessed. %
function pushbutton_play_Callback(hObject, eventdata, handles)

hactx = getappdata(handles.citest_rungui,'hactx');
hresults = getappdata(handles.citest_rungui,'hresults');

blocknum = handles.blocknum;
blocknum_last = get(hObject,'UserData');

mainvar = handles.ctrlParam.mainVars{1};	% update the main variable in BEDCS
mainval = get(handles.text_value,'UserData');
hactx.Let_ControlVarVal(mainvar, mainval);
pause(.05);

if blocknum ~= blocknum_last				% update the step variables if recently changed
  for i = 1:length(handles.ctrlParam.blockVars)
	blkvar = handles.ctrlParam.blockVars{i};
	blkval = handles.ctrlParam.blockValues{i}(:,blocknum);
	hactx.Let_ControlVarVal(blkvar, blkval);
	pause(.05);
  end;
  set(hObject,'UserData',blocknum);
end;

set(handles.text_statusbar,'BackGroundColor',[0 .5 0]); drawnow;
set(handles.pushbutton_play,'Enable','Inactive');
if ~handles.demomode
	hactx.MeasureNoSave;					% send BEDCS command to present the stimulus
end;
set(handles.pushbutton_play,'Enable','On');
set(handles.text_statusbar,'BackGroundColor',get(handles.text_statusbar,'UserData')); drawnow;

handles.finalvalues(blocknum) = mainval;	% update the stored "main" value for reporting in 'runOutput'
guidata(hObject,handles);

if getappdata(hresults,'display') && blocknum>0	% update the data displayed in Results View
	hplotvec = get(hresults,'UserData');		  % (with the current block parameter value)
	val = get(handles.text_value,'UserData');
	set(hplotvec(blocknum),'YData',val);
end;


% --- Callback for the PREVIOUS ("<<") and NEXT (">>") pushbuttons --- %
function pushbutton_nextprev_Callback(hObject, eventdata, handles)

nBlock = size(handles.ctrlParam.blockValues{1},2);
if strcmp(eventdata,'-')				% determine step direction (+/up or -/down)
	stepdir = -1;						% PREVIOUS button
else
	stepdir = +1;						% NEXT button
end;

blocknum = handles.blocknum + stepdir;	% increment to the NEXT/PREVIOUS block parameter value

if (blocknum>nBlock && stepdir>0) || (blocknum<1 && stepdir<0)
	set(hObject,'Enable','Off');		% this shouldn't happen
	return;
end;
										% update "Block Infomation" text field; values must be numeric
BlockMat = cat(1,handles.ctrlParam.blockValues{:});
valstr = sprintf('|%2.1f| ',BlockMat(:,blocknum)');
infostr = sprintf('Block %d of %d\n%s ',blocknum,nBlock,valstr);
set(handles.text_blockinfo,'String',infostr);
										% reset the parameter value display
set(handles.text_value,'String','','UserData',handles.ctrlParam.startval(blocknum));
text_value_Callback(handles.text_value,[],handles);

handles.blocknum = blocknum;			% store the current step number
guidata(hObject,handles);

if blocknum >= nBlock					% turn off the NEXT button if the last step has been reached
	set(handles.pushbutton_next,'Enable','Off');
else
	set(handles.pushbutton_next,'Enable','On');
end;
if blocknum <= 1						% turn off the PREVIOUS button if the first step has been reached
	set(handles.pushbutton_previous,'Enable','Off');
else
	set(handles.pushbutton_previous,'Enable','On');
end;

drawnow;


% --- Changes to the displayed value should be made via the 'UserData' property --- %
% This is called at start-up, as well as by the up and down push buttons.
function text_value_Callback(hObject, eventdata, handles)

paramval = get(hObject,'UserData');
tipunit = handles.ctrlParam.runSetup.tipunit;
formatstr = handles.ctrlParam.runSetup.format;

switch lower(tipunit)
case 'db'
  if paramval > 0
	tipstr = sprintf([formatstr '  dB'],20*log10(paramval));
  else
	tipstr = '-- dB';
  end;
otherwise
  tipstr = '';
end;

set(hObject,'String',sprintf(formatstr,paramval),'UserData',paramval,'TooltipString',tipstr);


% --- Shared callback for the "UP" and "DOWN" pushbuttons --- %
% Which button was pushed is indicated by the 'eventdata' argument (rather than polling 'hObject').
function pushbutton_updown_Callback(hObject, eventdata, handles)

unitmode = get(handles.popupmenu_units,'Value');
oldval = get(handles.text_value,'UserData');

hstepchoice = get(handles.uipanel_stepsize,'SelectedObject');
stepunit = get(hstepchoice,'UserData');

if strcmp(eventdata,'-')			% account for step direction (+/up or -/down)
	stepunit = -1 * stepunit;
end;

if unitmode==1	% linear step %
	newval = oldval + stepunit;
else			% log step %
	newval = 20*log10(oldval) + stepunit;
	newval = 10 ^ (newval/20);
end;

blocknum = handles.blocknum;		% don't exceed limits

if newval > handles.ctrlParam.maxval(blocknum)
	newval = handles.ctrlParam.maxval(blocknum);
elseif newval < handles.ctrlParam.minval(blocknum)
	newval = handles.ctrlParam.minval(blocknum);
end;
									% update the stored and displayed controlled value
set(handles.text_value,'UserData',newval);
text_value_Callback(handles.text_value,[],handles);


% --- Populate radio buttons with correct step sizes, given menu choise --- %
% Menu choice #1 is linear; menu choice #2 is log base-ten re: 1 linear unit. This holds no matter
% what type of variable (current level, duration) is actually being controlled.
function popupmenu_units_Callback(hObject, eventdata, handles)

istep = get(hObject,'Value');		
stepLists = get(hObject,'UserData');
steplist = stepLists{istep};
									% for now, all four buttons are assumed to be operational
set(handles.radiobutton_step1,'UserData',steplist(1),'String',num2str(steplist(1),'%.1f'));
set(handles.radiobutton_step2,'UserData',steplist(2),'String',num2str(steplist(2),'%.1f'));
set(handles.radiobutton_step3,'UserData',steplist(3),'String',num2str(steplist(3),'%.1f'));
set(handles.radiobutton_step4,'UserData',steplist(4),'String',num2str(steplist(4),'%.1f'));


% --- Handle calls to the DONE push button --- %
function pushbutton_done_Callback(hObject, eventdata, handles)

uiresume; 							% typically, control will go back to CITest_RunExperiment()


% -- Handle attempts to close the GUI figure -- %
function CITest_RunGUI_CloseFcn()

query = questdlg('Do you wish to close the manual stimulation panel?', 'Close Request', 'No');
if strcmp(query,'Yes')
	closereq;						% ask before closing the main figure
end;



%%%% AUXILIARY FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Called by the main GUI to start the stimulus presentations and return results --- %
% For the Manual experiment submode, this function simply enables the PLAY button.
function runOutput = CITest_RunGUI_Start(hgui)

handles = guidata(hgui);
									% initially, '.results' is all NaN
runOutput.results = handles.finalvalues;
runOutput.complete = false;
runOutput.message = 'Run terminated unexpectedly.';

if ~ishandle(hgui)					% in case the GUI was unexpectedly closed  
	return;
end;

set(handles.pushbutton_play,'Enable','On');

tstart = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
uiwait(hgui);						% wait for the <DONE> button or the main GUI pause/stop button
tstop = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');

if ~ishandle(hgui)					% another chance to catch an unexpected closure
	return;
end;

handles = guidata(hgui);			% output results (GUIDATA is required after the UIWAIT)
displaystr = handles.ctrlParam.displaytext;

runOutput.results = handles.finalvalues;
runOutput.complete = ~any(isnan(handles.finalvalues));
runOutput.message = sprintf('Run complete for Manual Stimulation - %s.\n%d of %d values were set.',displaystr,...
  sum(~isnan(handles.finalvalues)),length(handles.finalvalues));

runOutput.timing.timestart = tstart;
runOutput.timing.timestop = tstop;


% --- Setup plotting axes in the Results View external window --- %
function CITest_RunGUI_SetupView(hgui,handles)

hresults = getappdata(hgui,'hresults');	% figure and axes of Results View window
hview = getappdata(hgui,'hview');
hlbl = getappdata(hgui,'hlbl');

axes(hview); cla;						% put Results View axes into scope and update some text labels
set(hview,'NextPlot','Add');
bedcsvar = handles.ctrlParam.mainVars{1};
ylabel(bedcsvar);
set(hlbl,'String',handles.ctrlParam.viewSetup.xlabel);

nBlock = length(handles.ctrlParam.blockValues{1});
xplot = handles.ctrlParam.viewSetup.xvalues;
% if length(unique(xplot)) ~= nBlock
if length(xplot) ~= nBlock
	disp('Incompatible x-axis values for ResultsView. Changing to default.');
	xplot = 1:nBlock;
	set(hlbl,'String','Block #:');
end;

minval = handles.ctrlParam.minval; maxval = handles.ctrlParam.maxval;
plot(xplot,minval,'k:');
plot(xplot,maxval,'k:');

hplotvec = nan(1,nBlock);				% keep track of plotting handles
yplot = nan(1,nBlock);
for i = 1:nBlock
	hplotvec(i) = plot(xplot(i),yplot(i),'b*');
end;
 
yrng = max(maxval) - min(minval);
ylimits = [min(minval)-.20*yrng max(maxval)+.05*yrng];
if length(xplot) > 1
	xrng = max(xplot) - min(xplot);		% formerly range(xplot);
	xlimits = [min(xplot)-.02*xrng max(xplot)+.02*xrng];
	set(hview,'XTickMode','Auto')
else
	xlimits = [xplot-.02 xplot+.02];
	set(hview,'XTick',xplot);
end;

set(hview,'XLim',xlimits,'YLim',ylimits);
set(hresults,'UserData',hplotvec);
if getappdata(hresults,'display');
	set(hresults,'Visible','On');
else
	set(hresults,'Visible','Off');
end;


% --- Handle button presses of the PAUSE button in the main control GUI --- %
function CITest_RunGUI_Pause(hgui)

handles = guidata(hgui);
set(handles.pushbutton_play,'String','WAIT','Enable','Off');


function CITest_RunGUI_Unpause(hgui)

handles = guidata(hgui);
set(handles.pushbutton_play,'String','PLAY','Enable','On');


% --- Handle termination command from the main control GUI --- %
% For the Manual experiment mode, this function has the same effect as the DONE button.
function CITest_RunGUI_Stop(hgui)

setappdata(hgui,'ready',false);
uiresume(hgui);						% typically, control will go back to CITest_RunExperiment()


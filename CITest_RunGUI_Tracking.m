function varargout = CITest_RunGUI_Tracking(varargin)
% CITEST_RUNGUI_TRACKING MATLAB code for CITest_RunGUI_Tracking.fig
% Last Modified by GUIDE v2.5 25-Feb-2013 10:49:11
%
%	A subGUI that conducts a Bekesy-style tracking procedure, set up by the main CITest
% "control" GUI application (see CITEST.M). This application was initially designed for use
% with threshold and forward masking experiments, for which current level is the stimulus
% paraemter being adjusted.
%	The one button in this runtime GUI, 'pushbutton_tracking', could potentially be used
% by the subject to track the stimulus, much like the spacebar. Currently, however, the
% button is set to INACTIVE once the run is started. Only the spacebar is used for tracking.
%
% REVISION HISTORY
%	CITest_RunGUI_Tracking, created February 2013 by SMB.
%	10/09/2013. Keyboard press OR button click can now start the run.
%	09/08/2014. Channel sweep now takes a control parameter, '.padrev', that specifies the number
% of reversals before stopping the extra repeitions of the first stimulus block ("padding")
% and continuing on to the main block sequence. The total number of maximum repetitions is still
% given by the '.pad' parameter. This change better assures adaptation toward a perceptual contour
% (like threshold) when a run first starts.
%	03/10/2014. Added 'bedcsParam' to input arguments and rearranged others.
%	10/02/2015. Fixed problem with maintaining figure focus after the user clicks the READY button.
%   04/25/2015. Fixed problem with closing figure via 'X' mechanic. It now
%   recognizes the calling main CITest routine and closes appropriately.
%   Closure also works if a tracking window is simply opened by itself
%   (outside of CITest).
%

% --- Begin initialization code - DO NOT EDIT --- %
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_RunGUI_Tracking_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_RunGUI_Tracking_OutputFcn, ...
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


% --- Executes just before CITest_RunGUI_Tracking is made visible --- %
% The two required variable input arguments are the structure of control parameters ('ctrlParam'),
% and the handles to the main CITest GUI.
function CITest_RunGUI_Tracking_OpeningFcn(hObject, eventdata, handles, varargin)

% Initialize the GUI display and status, and check for proper loading conditions %
setappdata(hObject,'ready',false);		% the "tracking" pushbutton will change this to TRUE

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
handles.bedcsParam = varargin{2};

hmain = varargin{3};					% the handle to the main gui gives access to other variables and handles
hactx = getappdata(hmain,'hactx');
hresults = getappdata(hmain,'hresults');
hview = findobj(hresults,'tag','axes_results');
hlbl = findobj(hresults,'tag','text_blockstr');
if isempty(hview)						% to correct a weird quirk, where an axes 'reset' can make its tag disappear
	hview = findall(hresults,'type','axes');
	hview = hview(1);
	set(hview,'tag','axes_results');
end;

setappdata(hObject,'hmain',hmain);
setappdata(hObject,'hactx',hactx);
setappdata(hObject,'hresults',hresults);
setappdata(hObject,'hview',hview);
setappdata(hObject,'hlbl',hlbl);

% Set up the main variables and block variables %
handles.blocknum = 0;					% this is # blocks for one direction only
nBlock = size(handles.ctrlParam.blockValues{1},2);

if nBlock>1 && length(handles.ctrlParam.startval)==1
	handles.ctrlParam.startval = handles.ctrlParam.startval * ones(1,nBlock);
end;									% vectorize main + limit values, if necessary,
if nBlock>1 && length(handles.ctrlParam.minval)==1  % to match block variables
	handles.ctrlParam.minval = handles.ctrlParam.minval * ones(1,nBlock);
end;
if nBlock>1 && length(handles.ctrlParam.maxval)==1
	handles.ctrlParam.maxval = handles.ctrlParam.maxval * ones(1,nBlock);
end;

% Perform other setup %
runSetup = handles.ctrlParam.runSetup;
buttonLabels = struct('down',runSetup.buttondown.label,'up',runSetup.buttonup.label,...
  'pause','PAUSED - Click or <ENTER> when ready');
buttonColors = struct('down',runSetup.buttondown.color,'up',runSetup.buttonup.color,...
  'pause',get(handles.pushbutton_tracking,'BackGroundColor'));
setappdata(hObject,'buttonLabels',buttonLabels);
setappdata(hObject,'buttonColors',buttonColors);

handles.direction = runSetup.direction;	% 'Forward', 'Backward', or 'Both'
handles.blockpad = runSetup.pad;		% number of (maximum) blocks to add at beginning of sweep run
handles.blockpadrev = runSetup.padrev;	% number of reversals that will skip remaining pre-allocated pad blocks

handles.output = hObject;
guidata(hObject, handles);

CITest_RunGUI_SetupView(hObject,handles); % a utiliy function common to all run-time GUIs

setappdata(hObject,'spacebar',0);		% 0 = button is not pressed, 1 = pressed
set(handles.pushbutton_tracking,'Enable','On');
										% set up any keyboard key to start the run
set(hObject,'KeyPressFcn',@CITest_RunGUI_KeyStart);


% --- Outputs from this function are returned to the command line --- %
function varargout = CITest_RunGUI_Tracking_OutputFcn(hObject, eventdata, handles)

varargout{1} = handles.output;
varargout{2} = 'runsubject';


%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Signal to the main CITest GUI that the runtime subGUI is ready %
% The button will be deactivated for the rest of the run. Only the <spacebar> will be used
% for ongoing subject interaction.
function pushbutton_tracking_Callback(hObject, eventdata, handles)

label = getappdata(handles.citest_rungui,'buttonLabels'); label = label.up;
color = getappdata(handles.citest_rungui,'buttonColors'); color = color.up;
set(hObject,'String',label,'BackGroundColor',color','Enable','Off'); % ##2015.Oct: 'Inactive' doesn't give proper object focus

set(handles.text_query,'String',handles.ctrlParam.querytext);

setappdata(handles.citest_rungui,'ready',true);
uiresume;							% signal to the main CITEST GUI that this subGUI is ready


% -- Handle key presses and releases for the GUI -- %
% These are the callbacks for the "(Window)KeyPressFcn" and '(Window)KeyReleaseFcn" properties
% of the subGUI figure. A global variable, 'spacebar', is set using the SETAPPDATA function,
% to keep track of the latest status of the spacebar.
function CITest_RunGUI_KeyPress(src,eventdata)

handles = guidata(src); k = eventdata.Key;

switch k							% 'k' indicates which key was pressed
case 'space'
	label = getappdata(handles.citest_rungui,'buttonLabels'); label = label.down;
	color = getappdata(handles.citest_rungui,'buttonColors'); color = color.down;
	set(handles.pushbutton_tracking,'String',label,'BackGroundColor',color','Enable','Inactive');
	setappdata(handles.citest_rungui,'spacebar',1);
case 'p'							% force the experiment to pause
	qbutton = questdlg('Continue or stop run?','EXPERIMENT PAUSED','CONTINUE','STOP','CONTINUE');
	switch qbutton
	case 'STOP'
		CITest_RunGUI_Stop(handles.citest_rungui);
	otherwise
		CITest_RunGUI_Unpause(handles.citest_rungui);
	end;
case 'r'
	hresults = getappdata(handles.citest_rungui,'hresults');
	rwstatus = getappdata(hresults,'display');

	if ~rwstatus					% if Results Window currently off, turn on (and vice-versa)
		setappdata(hresults,'display',true);
		set(hresults,'Visible','On');
		figure(handles.citest_rungui); % makes sure runtime GUI will continue to capture key presses
	else
		setappdata(hresults,'display',false);
		set(hresults,'Visible','Off');
	end;
end;


function CITest_RunGUI_KeyRelease(src,eventdata)

handles = guidata(src); k = eventdata.Key;

switch k
case 'space'
	label = getappdata(handles.citest_rungui,'buttonLabels'); label = label.up;
	color = getappdata(handles.citest_rungui,'buttonColors'); color = color.up;
	set(handles.pushbutton_tracking,'String',label,'BackGroundColor',color','Enable','Inactive');
	setappdata(handles.citest_rungui,'spacebar',0);
end;


% -- Handle key press to start the run -- %
function CITest_RunGUI_KeyStart(src,eventdata)

handles = guidata(src); k = eventdata.Key;

switch k
case 'return'
	pushbutton_tracking_Callback(handles.pushbutton_tracking,[],handles);
	set(src,'KeyPressFcn','');		% disable this feature as soon as key is pressed
end;


% -- Handle attempts to close the GUI figure -- %
function CITest_RunGUI_CloseFcn(hgui)

query = questdlg('Do you wish to close the stimulus tracking panel?', 'Close Request', 'No');
if strcmp(query,'Yes')
% 	closereq;						% ask before closing the main figure
    CITest_RunGUI_Stop(hgui);
end;



%%%% AUXILIARY FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Utility function called by the main GUI to start the stimulus presentations --- %
% Note: it's up to the experiment GUI, which sets up this run-time GUI via 'ctrlParam', to make
% sure that the block parameters are in an order appropriate for sweeping.
function runOutput = CITest_RunGUI_Start(hgui)

runOutput.results = [];
runOutput.complete = false;
runOutput.message = 'Run terminated unexpectedly.';

if ~ishandle(hgui)				% in case the run-time GUI was unexpectedly closed  
	return;
elseif ~getappdata(hgui,'ready')
	runOutput.message = 'Run terminated externally by CITest.';
	return;
end;

handles = guidata(hgui);		% get necessary info for BEDCS stimulation and parameter changes
hactx = getappdata(handles.citest_rungui,'hactx');

blkValues = handles.ctrlParam.blockValues;
nBlock = length(blkValues{1}); nBlkvar = length(blkValues);

switch handles.direction		% create a working set of indexes into the block parameters
case 'Backward'
	orderidx = nBlock:-1:1;
	orderdir = -1*ones(1,nBlock); % +1 = sweep forward, -1 = backward, 0 = repeated blocks, no dir. (see below)
case 'Both'
	orderidx = [1:nBlock nBlock:-1:1];
	orderdir = [ones(1,nBlock) -1*ones(1,nBlock)];
otherwise % 'Forward' %
	orderidx = 1:nBlock;
	orderdir = ones(1,nBlock);
end;

if handles.blockpad				% optionally pad the beginning of the block sweeps, to allow subject response to settle
	orderidx = [repmat(orderidx(1),1,handles.blockpad) orderidx];
	orderdir = [zeros(1,handles.blockpad) orderdir];
	nSeqPad = handles.blockpad;
	nRevPad = handles.blockpadrev;
else
	nSeqPad = 0;
	nRevPad = inf;
end;
nSeq = length(orderidx);
								% set min, max, and start values for ordered list of block parameters
minvalues = handles.ctrlParam.minval(orderidx);
maxvalues = handles.ctrlParam.maxval(orderidx);
startvalues = handles.ctrlParam.startval(orderidx);

bedcsvar = handles.ctrlParam.mainVars{1};
bedcsval = startvalues(1);		% initialize the main parameter
hactx.Let_ControlVarVal(bedcsvar, bedcsval);
pause(0.05);

for i = 1:nBlkvar				% initialize the block parameters
	blkvar = handles.ctrlParam.blockVars{i};
	blkval = blkValues{i}(orderidx(1));
	hactx.Let_ControlVarVal(blkvar, blkval);
end;
pause(.05);

try								% set up handling of keyboard presses
	set(hgui,'WindowKeyPressFcn',@CITest_RunGUI_KeyPress);
	set(hgui,'WindowKeyReleaseFcn',@CITest_RunGUI_KeyRelease);
catch							% earlier MATLAB versions don't recognize "Window" key functions
	set([hgui handles.pushbutton_tracking],'KeyPressFcn',@CITest_RunGUI_KeyPress);
	set(hgui,'KeyReleaseFcn',@CITest_RunGUI_KeyRelease);
end;
								% ##2015.10: JavaFrame call won't be supported in future MATLAB releases
set(handles.citest_rungui, 'CurrentObject',handles.citest_rungui);
drawnow;
								% define handles for the Results View window
hresults = getappdata(handles.citest_rungui,'hresults');
hplotvec = get(hresults,'UserData');
								% determine integer number of stim intervals to play for each block
blocknext = ceil(handles.ctrlParam.blockintvl/handles.ctrlParam.intvl);

dwellsec = (handles.ctrlParam.dwell)/1000  - .05; %- (nBlkvar+1)*.02;
stimdursec = handles.ctrlParam.stimdur / 1000;	% (only used in demo mode)
onstep = handles.ctrlParam.runSetup.buttondown.rate;
offstep = handles.ctrlParam.runSetup.buttonup.rate;
stepunit = handles.ctrlParam.runSetup.rateunit;

stimcnt = 0; seqcnt = 1; 		% initialize some tracking variables
revcnt = 0;
gostatus = true;
valuevec = nan(1,nSeq*blocknext);
revvec = nan(1,nSeq*blocknext);
seqvec = zeros(1,nSeq*blocknext);
sblast = getappdata(handles.citest_rungui,'spacebar');

minval = minvalues(1);
maxval = maxvalues(1);			% min/max values will change with block parameter

markstr = 'o';					% at beginning, assume SPACEBAR is not being pressed
tstart = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');

while gostatus && getappdata(hgui,'ready')
	if ~handles.demomode
		hactx.MeasureNoSave;	% start stimulating, polling the SPACEBAR all the while
	else
		pause(stimdursec);
	end;
	pause(dwellsec);			% enforce the chosen inter-stimulus duration
								% capture the SPACEBAR status (won't affect stimulus for THIS loop, though)
	sbnow = getappdata(handles.citest_rungui,'spacebar');

	if getappdata(hresults,'display')
		set(hplotvec(orderidx(seqcnt)),'YData',bedcsval,'Marker',markstr);
		drawnow;				% update the data displayed in Results View
	end;

	stimcnt = stimcnt + 1;				% keep track of the number of stimuli played ..
	valuevec(stimcnt) = bedcsval;		% .. and the primary parameter value ..
	seqvec(stimcnt) = seqcnt;			% .. and the index into the block sequence (simple 1:nSeq) ..
	revvec(stimcnt) = sbnow~=sblast;	% .. and whether a local minimum or maximum has occurred

	if sbnow						% SPACEBAR key is bring pressed
		markstr = '+';
		if strcmpi(stepunit,'db')
			delta = 10.^ ((20*log10(bedcsval) + onstep)/20) - bedcsval;
		else
			delta = onstep;
		end;
	else							% SPACEBAR key is not being pressed
		markstr = 'o';
		if strcmpi(stepunit,'db')
			delta = 10.^ ((20*log10(bedcsval) + offstep)/20) - bedcsval;
		else
			delta = offstep;		% 'offstep' is a signed value (e.g. negative current change)
		end;
	end;

	if sbnow ~= sblast				% count up a reversal when key is pressed OR released
		revcnt = revcnt + 1;
	end;
	sblast = sbnow;					% keep track of last key press status

	if seqcnt<=nSeqPad && revcnt>=nRevPad
		seqcnt = nSeqPad;			% if #reversals criteria met, advance stimulus count past padding stimuli
		stimcnt = nSeqPad*blocknext;  % (this should only be triggered a maximum of one time)
	end;

	if ~mod(stimcnt,blocknext)		% at certain number of stimuli, go to the next block in sequence
		seqcnt = seqcnt + 1;		  % (this will be for the NEXT stimulus played, as tracked by 'stimcnt')
		if seqcnt > nSeq
			gostatus = false;		% if last block was just completed, break from while loop ..
		else
		  for i = 1:nBlkvar			% .. otherwise, update the block parameters and min/max range
			blkvar = handles.ctrlParam.blockVars{i};
			blkval = blkValues{i}(orderidx(seqcnt));
			hactx.Let_ControlVarVal(blkvar, blkval);
% 			pause(.02);
		  end;
		  minval = minvalues(seqcnt);
		  maxval = maxvalues(seqcnt);
		end;
% 	else
%  		pause(.02*nBlkvar);			% for temporal equality
	end;

	newval = bedcsval + delta;		% every time, update the primary variable value (e.g. current) for NEXT stim
	if newval >= maxval
		newval = maxval;			% check for parameter limits
		markstr = 'x';
	elseif newval <= minval
		newval = minval;
		markstr = 'x';
	end;

	bedcsval = newval;
	hactx.Let_ControlVarVal(bedcsvar, bedcsval);
	pause(.05);

end; % while gostatus %

tstop = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');

if ~ishandle(hgui)					% another chance to catch an unexpected closure
	return;
end;

keepind = ~isnan(valuevec);			% remove any padding stimuli that were skipped
valuevec = valuevec(keepind);
revvec = revvec(keepind);
seqvec = seqvec(keepind);

clear runOutput;					% about to reorder fields, so easiest to start over

runOutput.results = valuevec;		% output results, one value for each stimulus
runOutput.blockidx = orderidx(seqvec);
runOutput.blockdir = orderdir(seqvec);
runOutput.reversals = revvec;
runOutput.nreversal = revcnt;		% scalar (includes reversals that occured during extra "pad" stimuli)
runOutput.blockParams = blkValues;	% one value for each block, not re-ordered

runOutput.complete = length(valuevec) >= (nSeq-nSeqPad)*blocknext;

runOutput.timing.timestart = tstart;
runOutput.timing.timestop = tstop;

runOutput.message = sprintf('%d of %d block sequences completed for Tracking - %s.',...
  max(0,max(seqvec)-nSeqPad),nSeq-nSeqPad,handles.ctrlParam.displaytext);


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
% hlbl = findobj(hresults,'tag','text_blockstr');
set(hlbl,'String',handles.ctrlParam.viewSetup.xlabel);

nBlock = length(handles.ctrlParam.blockValues{1});
xplot = handles.ctrlParam.viewSetup.xvalues;
if length(xplot) ~= nBlock
	disp('Incorrect x-axis values for ResultsView. Changing to default.');
	xplot = 1:nBlock;
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
ylimits = [min(minval)-.05*yrng max(maxval)+.05*yrng];
if length(xplot) > 1
	xrng = max(xplot) - min(xplot);		% formerly range(xplot);
	xlimits = [min(xplot)-.02*xrng max(xplot)+.02*xrng];
	set(hview,'XTickMode','Auto');
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


% --- Handle button presses of the main button in the main control GUI --- %
function CITest_RunGUI_Pause(hgui)

handles = guidata(hgui);

label = getappdata(handles.citest_rungui,'buttonLabels'); label = label.pause;
color = getappdata(handles.citest_rungui,'buttonColors'); color = color.pause;
set(handles.pushbutton_tracking,'String',label,'BackGroundColor',color','Enable','On');


function CITest_RunGUI_Unpause(hgui)

handles = guidata(hgui);

label = getappdata(handles.citest_rungui,'buttonLabels'); label = label.up;
color = getappdata(handles.citest_rungui,'buttonColors'); color = color.up;
set(handles.pushbutton_tracking,'String',label,'BackGroundColor',color','Enable','Inactive');

figure(hgui);			% make sure this GUI becomes the active window again


% --- Handle termination command from the main control GUI --- %
function CITest_RunGUI_Stop(hgui)

setappdata(hgui,'ready',false);
if ~isempty(getappdata(hgui,'hmain'))
    uiresume(hgui);						% typically, control will go back to CITest_RunExperiment()
else
    closereq;
end;


function varargout = CITest_RunGUI_TwoStepAdjust(varargin)
% CITEST_RUNGUI_TwoAdjust MATLAB code for CITest_RunGUI_TwoStepAdjust.fig
%
%	Run-time GUI for playing a reference stimulus followed by a test stimulus,
% such as for loudness balancing. The user presses one of two buttons in each
% direction (up or down), with the buttons changing the next parameter in a small
% or large step. The test stimulus can be a series of related stimuli that vary
% in one parameter.
%
% REVISION HISTORY
%	CITest_RunGUI_TwoAdjust.m, created February 12, 2015 by SMB. Based on code for
% the 2-IFC GUI.
%

% --- Begin initialization code - DO NOT EDIT --- %
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_RunGUI_TwoStepAdjust_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_RunGUI_TwoStepAdjust_OutputFcn, ...
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


% --- Executes just before run-time GUI is made visible --- %
% The four variable input arguments are a structure of control parameters ('ctrlParam'),
% the handle to the main CITest GUI, a demo mode toggle, and instructions for where
% to place the run-time GUI window.
function CITest_RunGUI_TwoStepAdjust_OpeningFcn(hObject, eventdata, handles, varargin)

% Initialize the GUI display and status, and check for proper loading conditions %
setappdata(hObject,'ready',false);		% the start pushbutton will change this to TRUE

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

handles.ctrlParam = varargin{1};		% 'ctrlParam' specifies the run-time parameters
if length(handles.ctrlParam.mainVars) > 1
	warning('This run-time GUI allows only one "main" stimulus variable.');
	handles.output = 0; guidata(hObject,handles);
	return;
end;

handles.bedcsParam = varargin{2};		% 'bedcsParam' also needed for this GUI

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
nBlock = size(handles.ctrlParam.blockValues{1},2);

if nBlock>1 && length(handles.ctrlParam.startval)==1
	handles.ctrlParam.startval = handles.ctrlParam.startval * ones(1,nBlock);
end;										% vectorize main + limit values, if necessary
if nBlock>1 && length(handles.ctrlParam.minval)==1
	handles.ctrlParam.minval = handles.ctrlParam.minval * ones(1,nBlock);
end;
if nBlock>1 && length(handles.ctrlParam.maxval)==1
	handles.ctrlParam.maxval = handles.ctrlParam.maxval * ones(1,nBlock);
end;

hbuttonset = [handles.pushbutton_downlarge handles.pushbutton_downsmall handles.pushbutton_replay ...
handles.pushbutton_upsmall handles.pushbutton_uplarge];
handles.buttonset = hbuttonset;				% initially turn off the response buttons
set(hbuttonset,'Enable','Off');

setappdata(hObject,'lastbutton',[]);

handles.output = hObject;
guidata(hObject, handles);

CITest_RunGUI_SetupView(hObject,handles);	% a utility function common to all run-time GUIs

set(handles.pushbutton_start,'Enable','On');


% --- Outputs from this function are returned to the command line --- %
function varargout = CITest_RunGUI_TwoStepAdjust_OutputFcn(hObject, eventdata, handles) 

varargout{1} = handles.output;
varargout{2} = 'runsubject';				% GUI should be positioned for the subject



%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Signal to the main CITest GUI that the runtime subGUI is ready %
% The button is labelled with "NEXT" once stimulation starts.
function pushbutton_start_Callback(hObject, eventdata, handles)

origcol = get(hObject,'BackGroundColor'); %origdata = get(hObject,'UserData');
grcol = [.2 1 .2];				% display the instructions for the task on the button
set(hObject,'String','Get Ready','BackGroundColor',grcol,'Enable','Inactive');

% try								% bring interaction GUI figure into "focus" (MatlabCentral #33224)
% 	jPeer = get(handle(handles.citest_rungui), 'JavaFrame');
%  	jPeer.getAxisComponent.requestFocus; % (this will make button presses work better)
% catch
% 	figure(handles.citest_rungui);
% end;
								% ##2015.10: JavaFrame call won't be supported in future MATLAB releases
set(handles.citest_rungui, 'CurrentObject',handles.citest_rungui);
drawnow;

pause(0.2);						% display run-time prompt
set(handles.text_feedback,'String',handles.ctrlParam.querytext);

pause(0.8);						% change button function to "NEXT" and give it same callback as stim control buttons
set(hObject,'String','NEXT','BackGroundColor',origcol); %,'UserData',origdata);
set(hObject,'Callback',@(hObject,eventdata)CITest_RunGUI_HandleButtons(hObject,eventdata,guidata(hObject)));
set([hObject handles.buttonset],'Enable','On');

pause(0.5);
setappdata(handles.citest_rungui,'ready',true);
uiresume;


% --- Handle response button presses --- %
function CITest_RunGUI_HandleButtons(hObject, eventdata, handles)

% fprintf(1,'The button pressed was: %s.\n',get(hObject,'tag'));
jobj = findjobj(hObject);		% Java trick to remove lingering border after button-press
set(jobj,'FocusPainted',0);

setappdata(handles.citest_rungui,'lastbutton',hObject);
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
% The button codes are: <<=-2, <=-1, replay=0, >=+1, >>=+2, NEXT=99.
function runOutput = CITest_RunGUI_Start(hgui)

runOutput.values = [];
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

hresults = getappdata(handles.citest_rungui,'hresults');
hplotvec = get(hresults,'UserData');
hview = getappdata(handles.citest_rungui,'hview');
								% get info about TEST stimulus, both main and block variables
mainvar = handles.ctrlParam.mainVars{1};	% previously forced to be just one variable
minval = handles.ctrlParam.minval;
maxval = handles.ctrlParam.maxval;			% e.g. of main variable = current level (for loudness balancing)
startval = handles.ctrlParam.startval;

blockVars = handles.ctrlParam.blockVars;	% e.g. of block variable = channel (for balancing across electrodes)
blockVal_test = handles.ctrlParam.blockValues;
nBlock = length(blockVal_test{1});
								% get fixed values for the REFERENCE stimulus
mainval_ref = handles.bedcsParam.(mainvar);
blockVal_ref = cell(1,length(blockVars));
for i = 1:length(blockVars)		% these are contained in the 'bedcsParam' structure that BEDCS was initialized with
	blockVal_ref{i} = handles.bedcsParam.(blockVars{i});
end;

runSetup = handles.ctrlParam.runSetup;

interstimsec = handles.ctrlParam.intvl / 1000;
stimdursec = handles.ctrlParam.stimdur / 1000;
stimdursec = max(stimdursec,0.10);	% for short trains or single pulses, intvls must flash for at least a little time

nRep = handles.ctrlParam.nreps;

stimcnt = 0;					% initialize some tracking variables; one entry for every stimulus played
blockvec = nan(2,2000); stimvec = nan(1,2000); respvec = nan(1,2000);
FinalValues = nan(nRep,nBlock);

tstart = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');

for irep = 1:nRep				% #### start stimulation series ####################################################

  if runSetup.rdmblock, blockorder = randperm(nBlock);
  else blockorder = 1:nBlock;
  end;							% use a different block randomization for each repetition

  if runSetup.rdmmain
	valadj = rand(1,nBlock)*2*runSetup.rdmmain_limit - runSetup.rdmmain_limit;
  else valadj = 0;
  end;							% initialize starting values for main variable, one value per block
  if strcmpi(runSetup.stepunit,'db')
	maininit = 20*log10(startval) + valadj;
	maininit = 10 .^ (maininit/20);
  else maininit = startval + valadj;
  end;
								% reset level for first stimulus of first block entry
  mainval_test = maininit(blockorder(1));
  blocknum = 1;

  fprintf(1,'Rep %d | Block %d ',irep,blockorder(blocknum));
								% delete past data points before each rep
  for i = 1:nBlock, set(hplotvec(i),'YData',NaN); end;

  gostatus = true;				% each "while" iteration is a different stimulus
  while gostatus && getappdata(hgui,'ready')

 	iblk = blockorder(blocknum); % index into the current block for the test stimulus

	hactx.Let_ControlVarVal(mainvar, mainval_ref);
	for i = 1:length(blockVars)	% load up the reference stimulus as the FIRST INTERVAL
		hactx.Let_ControlVarVal(blockVars{i}, blockVal_ref{i});
		pause(.05);
	end;

    set(handles.togglebutton_intvl1,'BackGroundColor',runSetup.oncolor); drawnow;
	if ~handles.demomode
		hactx.MeasureNoSave;	% play the reference stimulus ..
	else
		pause(stimdursec);		% .. or pretend to
	end;
	set(handles.togglebutton_intvl1,'BackGroundColor',runSetup.offcolor); drawnow;

	pause(interstimsec);		% enforce the inter-stimulus duration

	hactx.Let_ControlVarVal(mainvar, mainval_test);
	for i = 1:length(blockVars)	% load up the test stimulus as the SECOND INTERVAL
		hactx.Let_ControlVarVal(blockVars{i}, blockVal_test{i}(iblk));
		pause(.05);
	end;

    set(handles.togglebutton_intvl2,'BackGroundColor',runSetup.oncolor); drawnow;
	if ~handles.demomode
		hactx.MeasureNoSave;	% play the test stimulus
	else
		pause(stimdursec);
	end;
	set(handles.togglebutton_intvl2,'BackGroundColor',runSetup.offcolor); drawnow;

	if getappdata(hresults,'display')
		set(hplotvec(iblk),'YData',mainval_test);
	end;						% plot the data in Results View

	uiwait(hgui);				% wait for the user's button response
	pause(0.2);
	bchoice = getappdata(hgui,'lastbutton');

	stimcnt = stimcnt + 1;		% store the test stimulus attributes and the response
	blockvec(:,stimcnt) = [irep ; iblk];
	stimvec(stimcnt) = mainval_test;
	respvec(stimcnt) = get(bchoice,'UserData'); % store the button code (native to GUI fig)

	switch bchoice
	case handles.pushbutton_start	% this is the NEXT button
		FinalValues(irep,iblk) = mainval_test;
		if blocknum < nBlock
			blocknum = blocknum + 1; % on "NEXT", go to the next block parameter(s) ..
			mainval_test = maininit(blockorder(blocknum));
			fprintf(1,'%d ',blockorder(blocknum));
		else
			fprintf(1,'\n');
			gostatus = false;		% .. or break from while loop and go to next rep if all blocks completed ..
		end;
		valstep = 0;				% .. or change the value of the main parameter and continue current block
	case handles.pushbutton_downlarge
		valstep = -runSetup.downsteplg;
	case handles.pushbutton_downsmall
		valstep = -runSetup.downstepsm;
	case handles.pushbutton_replay
		valstep = 0;
	case handles.pushbutton_upsmall
		valstep = +runSetup.upstepsm;
	case handles.pushbutton_uplarge
		valstep = +runSetup.upsteplg;
	end;
	valstep = valstep * runSetup.stepsign;

	if strcmpi(runSetup.stepunit,'db')
		mainval_test = 20*log10(mainval_test) + valstep;
		mainval_test = 10 ^ (mainval_test/20);
	else mainval_test = mainval_test + valstep;
	end;
									% don't exceed min or max limits
	if mainval_test > maxval(blockorder(blocknum))
		mainval_test = maxval(blockorder(blocknum));
	elseif mainval_test < minval(blockorder(blocknum))
		mainval_test = minval(blockorder(blocknum));
	end;

  end; % #### while gostatus %

  if ~getappdata(hgui,'ready')		% don't go to next repetition if run was manually stopped
	break;
  end;

  if getappdata(hresults,'display')	% plot a frozen view of this rep's data before moving on
    xvec = get(hplotvec,'XData'); if iscell(xvec), xvec = cat(2,xvec{:}); end;
    yvec = get(hplotvec,'YData'); if iscell(yvec), yvec = cat(2,yvec{:}); end;
    set(0,'currentfigure',hresults); set(hresults,'CurrentAxes',hview);
    plot(xvec,yvec,'k','LineStyle','None','Marker','x');
  end;

end; % for irep %  #################################################################################

tstop = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');

if ~ishandle(hgui)					% flag early closures (but execution will continue otherwise)
	fprintf(1,'\nRun terminated unexpectedly.');
elseif ~getappdata(hgui,'ready')
	fprintf(1,'\nRun terminated externally.');
else
	fprintf(1,'\n\n');
end;

blockvec = blockvec(:,1:stimcnt);
stimvec = stimvec(1:stimcnt);
respvec = respvec(1:stimcnt);

clear runOutput;

runOutput.results = FinalValues;	% one element for each rep (row) and block (column)
runOutput.refvalues = mainval_ref;	% scalar
runOutput.testvalues = stimvec;		% one element for each stimulus, matching the [rep,block] list in 'repblock'
runOutput.repblock = blockvec;
runOutput.responses = respvec;
runOutput.blockParams = blockVal_test;

runOutput.timing.timestart = tstart;
runOutput.timing.timestop = tstop;

repblock = unique(blockvec','rows')';
stimdone = size(repblock,2);
if ~isempty(repblock), repdone = stimdone/nBlock; %repdone = max(repblock(1,:));
else repdone = 0;
end;

if repdone < 1
	runOutput.message = sprintf('%d of %d block parameters, in 1 rep, completed for Two-step Adjustment - %s.',...
	  stimdone,nBlock,handles.ctrlParam.displaytext);
else
	runOutput.message = sprintf('%0.2f reps of %d block parameters completed for Two-step Adjustment - %s.',...
	  repdone,nBlock,handles.ctrlParam.displaytext);
end;


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

nBlock = length(handles.ctrlParam.blockValues{1});
xplot = handles.ctrlParam.viewSetup.xvalues;
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
if yrng>0
	ylimits = [min(minval)-.20*yrng max(maxval)+.05*yrng];
else
	ylimits = [min(minval)-1 min(minval)+1];
end;
if length(xplot) > 1
	xrng = max(xplot) - min(xplot);	% formerly range(xplot);
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


% --- Handle button presses of the main button in the main control GUI --- %
function CITest_RunGUI_Pause(hgui)

handles = guidata(hgui);		% pause evoked by a modal dialog box.. so there is an inherent wait
UD.data = get(handles.pushbutton_start,'UserData');
UD.bgcolor = get(handles.pushbutton_start,'BackgroundColor');
UD.string = get(handles.pushbutton_start,'String');

set(handles.pushbutton_start,'String','PAUSED - Please Wait','Enable','Inactive',...
  'BackgroundColor',[.90 .90 .08],'UserData',UD);


function CITest_RunGUI_Unpause(hgui)

handles = guidata(hgui);		% reset some of the start button properties prior to pause
UD = get(handles.pushbutton_start,'UserData');

set(handles.pushbutton_start,'BackgroundColor',UD.bgcolor,'UserData',UD.data);

if ~getappdata(hgui,'ready');	% in case the pause occurred prior to RunGUI_Start()
	set(handles.pushbutton_start,'String',UD.string,'Enable','On');
else
	set(handles.pushbutton_start,'String','NEXT');
end;


% --- Handle termination command from the main control GUI --- %
function CITest_RunGUI_Stop(hgui)

handles = guidata(hgui);
UD = get(handles.pushbutton_start,'UserData');

if ~getappdata(hgui,'ready') && strcmpi(get(hgui,'waitstatus'),'waiting')
	pushbutton_start_Callback(handles.pushbutton_start, [], handles);
	drawnow;
	setappdata(hgui,'ready',false);	% in case the pause occured prior to RunGUI_Start() ..
elseif ~getappdata(hgui,'ready')	  % (but outright close the figure if something is wrong)
	closereq;
else								% .. otherwise force an exit AFTER the current RunGUI_Start() loop
	UD = get(handles.pushbutton_start,'UserData');
	set(handles.pushbutton_start,'String','FINISHED','BackgroundColor',UD.bgcolor,'UserData',UD.data,'Enable','On');
	setappdata(hgui,'ready',false);
end;



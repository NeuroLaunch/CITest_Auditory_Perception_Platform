% CITEST_PULSEOPTIONS.M
% function [plsframes,ipframes] = CITest_PulseOptions(hButton,pulseIn,phframes)
%	or
% function [pulseUI,tbase] = CITest_PulseOptions(hButton,pulseIn,phframes)
%
%	This utility GUI allows the setting of pulse-shape parameters beyond those
% available from the "Stimulus Parameters" panel of the main CITest window.
% It can be launched from the CITEST "Pulse Mod" UI button (handle = 'hbutton);
% alternatively, it can be evoked without opening the subGUI window by commands
% within the CITEST program (with the 'hbutton' argument set to 0) or by supplying
% a third argument ('phframes').
%	The function has two primary modes of operation. Mode 1 is a non-graphical
% operation in which the number of total time frames constituting one pulse is returned
% given the number of frames for the primary pulse phase (this is, the value determined
% by CITEST's "Phase Duration" UI text field). This pulse duration, called 'plsframes'
% in the code, together with the interpulse zero-amplitude interval, 'ipframes' (also
% an output), defines the period between consecutive pulses. Each of these quantities
% is an integer specifying the number of base time frames, 'tbase', expressed in the code
% in microseconds. Mode 1 is called by 'phdur_text_Callback()' in CITEST. Note that the
% the total period between pulses can be no larger than 256 'tbase' frames.
%	The second type of operation, Mode 2, is to open a GUI window containing a preconfigured
% number of UI elements allowing the setting of certain pulse stimulus parameters (beyond
% the ones usually set in the CITEST "Stimulus Parameters" panel). Examples of additional
% parameters include leading-phase polarity (cathodic or anodic), interphase gap, and so on.
% The GUI window is titled 'Additional Pulse Parameters'. This mode is launched strictly from
% the callback routine serving the "Pulse Mod" button in CITEST.
%	There is also a special case of Mode 2, in which the pulse parameters are initialized
% but the GUI window is not opened.
%	Following are the formats for the input and output arguments for the different modes:
% {Mode 1}:	hbutton = empty; pulseIn = pulseSettings (from CITEST); phframes = integer;
%			plsframes and ipframes = integers
% {Mode 2,w/ GUI}:	hbutton = actual handle for the CITest UI button, 'setuppulse_pushbutton';
%					pulseIn = 'pulseSettings' structure with a valid '.dataUI' field containing
%					  instructions for setting the Pulse Mod. subGUI (usually this would have
%					  been created from a previous execution of Mode 2); phframes = no entry;
%					pulseUI = structure (see code), tbase = floating point number
% {Mode 2,no GUI}:	hbutton = empty; pulseIn = 'pulseSettings' structure as above OR a string
%					  containing the name of a standard pulse type (to initialize relevant
%					  'pulseSettings' fields);
%					phframes = no entry; pulseUI and tbase = same as above
%
%	Standard pulse types currently include only 'Simple Biphasic' (symmetric pulses, no gap,
% parameter = 'polarity'). Note that the calculation of 'plsframes' does not depend on 
% any of the additional Pulse Mod. parameters, for the standard pulse types.
%	Any calls to this function should be followed by 1) an update of the relevant fields of the
% the CITEST variable 'pulseSettings' and 2) an update of the CITEST phase duration setting via
% a call to phdur_text_Callback(), which will store 'pulseSettings' via GUIDATA.
% Also, the 'tbase' returned here should be checked against the 'tbase' variable used by each
% BEDCS experiment (which won't be changed, so it's essentially constant).
%
%	Created on August 1, 2014 by SMB.
%

function varargout = CITest_PulseOptions(hButton,pulseIn,phframes)

% -- MODE 1 -- Convert an input phase duration to pulse duration (as a number of 'tbase' frames) %
if nargin >= 3
	varargout{1} = [];
	varargout{2} = [];

	if ~isstruct(pulseIn) || ~isfield(pulseIn,'type')
		warning('Pulse information was not recognized.');
		return;				% if 'pulseIn' is invalid, return an empty matrix; CITEST will deal with it
	end;
							% base default # of interpulse zeros on last defined duty cycle
	zeropct = pulseIn.ipframes/(pulseIn.plsframes + pulseIn.ipframes);
	if isempty(zeropct)		% in case single pulse used last time, go with a low duty cycle
		zeropct = .98;
	elseif zeropct < 0.5
		zeropct = 0.5;
	end;

	switch pulseIn.type
	case 'Simple Biphasic'	% standard pulse types will have predictable outputs ..
		plsframes = phframes * 2;	% interphase gap = 0 for "simple" pulse types, and biphasic pulses have TWO phases
		ipframes = round(plsframes * zeropct/(1-zeropct));
	case 'Simple 2-Chan Biphasic'
		plsframes = phframes * 4;
		ipframes = round(plsframes * zeropct/(1-zeropct));
	case 'Simple Biphasic 1-Pulse'
		plsframes = phframes * 2;
		ipframes = [];		% empty 'ipframes' means that only a single pulse is being defined
	case 'Simple 2-Chan Biphasic 1-Pulse'
		plsframes = phframes * 4;
		ipframes = [];		% empty 'ipframes' means that only a single pulse is being defined
	otherwise
		try					% .. while custom types need experiment-specific instructions
		  [plsframes,ipframes] = feval(pulseIn.expgui,'CITest_Exp_GetPulseInfo',pulseIn,phframes);
		catch
		  warning('Custom pulse type did not execute properly.');
		  return;
		end;
	end;

	varargout{1} = plsframes;
	varargout{2} = ipframes;
	return;					% form output for Mode 1; skip everything below

end; % if nargin %


% -- MODE 2 -- For regular function, begin by initializing or reloading subGUI UI elements %
if isempty(hButton)	% for initializing settings without opening the subGUI
% if ~hButton

if ischar(pulseIn)		% interpret input arguments
	execmode = pulseIn;
elseif isstruct(pulseIn) && isfield(pulseIn,'type') && isfield(pulseIn,'dataUI')
	execmode = pulseIn.type;
else
	warning('Custom pulse type did not execute properly.');
	varargout{1} = [];	% if 'pulseIn' is invalid, return an empty matrix; CITEST will deal with it
	varargout{2} = [];
	return;
end;

switch execmode			% intialize subGUI with standard settings ..
case {'Simple Biphasic','Simple 2-Chan Biphasic'}
	pulseUI(1) = struct('code','polarity','name','Initial Polarity','uitype','popupmenu',...
	  'uistring',{{'cathodic'}},'uivalue',1,'uienable','off');
	pulseUI(2) = struct('code','phgap','name','Interphase Gap','uitype','edit',...
	  'uistring','0','uivalue',0,'uienable','off');
	tbase = 12 * 44/49;
case {'Simple Biphasic 1-Pulse','Simple 2-Chan Biphasic 1-Pulse'}
	pulseUI(1) = struct('code','polarity','name','Initial Polarity','uitype','popupmenu',...
	  'uistring',{{'cathodic'}},'uivalue',1,'uienable','off');
	pulseUI(2) = struct('code','phgap','name','Interphase Gap','uitype','edit',...
	  'uistring','0','uivalue',0,'uienable','off');
	tbase = 2 * 44/49;
otherwise				% .. OR  use pre-saved settings, whether to initialize with customized pulse settings
	pulseUI = pulseIn.dataUI; % or simply to continue editing the presently valid settings
	tbase = pulseIn.tbase;
end;

end; % if isempty(hbutton) %


% Create a new figure and populate UI elements based on info in 'pulseUI' %
if ishandle(hButton)					% reload with '.dataUI' settings if button was pressed in main GUI ('hButton' is not empty)
% if hButton

POSWINDOW = [800 150 330 400];
POSTEXT = [.03 .80 .40 .08]; POSUI = [.45 .80 .52 .08];
YPOSVEC = [.70 .60 .50 .40 .30];

execmode = pulseIn.type;
pulseUI = pulseIn.dataUI;
tbase = pulseIn.tbase;

nUI = length(pulseUI);
if length(nUI) > length(YPOSVEC)
	warning('Too many UI elements for the Pulse Modification tool. Some won''t be visible.')
end;

hpulse = figure('Position',POSWINDOW,'Visible','off','Menubar','None','HandleVisibility','Callback',...
  'WindowStyle','Modal','CloseRequestFcn',@CITest_PulseOptions_CloseFcn,'Name','Pulse Options');
figcolor = get(hpulse,'Color');
set(hpulse,'defaultuicontrolFontSize',12,'defaultuicontrolUnits','Normalized',...
  'defaultuicontrolBackgroundColor',figcolor,'defaultuicontrolForegroundColor','k',...
  'defaultuicontrolHorizontalAlignment','Center');

uicontrol('Style','Text','String','Additional Pulse Parameters','Position',[.05 .90 .90 .07],...
  'FontWeight','Bold','FontSize',14);
uicontrol('Style','Text','String',sprintf('Type: %s',execmode),'Position',[.05 .85 .90 .06],...
  'FontSize',12);

huiset = zeros(1,nUI); posvec1 = POSTEXT; posvec2 = POSUI;
for i = 1:nUI
	ipos = min(i,length(YPOSVEC));
	posvec1(2) = YPOSVEC(ipos); posvec2(2) = YPOSVEC(ipos);
										% display the label
	uicontrol('Style','Text','String',pulseUI(i).name,'Position',posvec1,'HorizontalAlignment','Left');

	try									% display the UI element
 		huiset(i) = uicontrol('Style',pulseUI(i).uitype,'String',pulseUI(i).uistring,'Value',pulseUI(i).uivalue,...
		  'Enable',pulseUI(i).uienable,'Position',posvec2,'BackgroundColor','w');
		goodui = true;
	catch
		huiset(i) = uicontrol('Style','Text','String','Invalid UI','Position',posvec2,...
		  'ForegroundColor','r','BackgroundColor','w');
		goodui = false;
	end;

	if i > length(YPOSVEC)				% only display the UI elements that fit in the window
		set(huiset(i),'Visible','Off','Enable','Off');
	end;
	if ~goodui
		huiset(i) = NaN;
	end;
end;

uicontrol('Style','pushbutton','String','Done','Units','Normalized','Callback','uiresume',...
  'Position',[.72 .03 .25 .10],'BackgroundColor',[59 113 86]/256,'FontSize',16);

set(hpulse,'Visible','On');		% reveal figure and wait for user to change settings and press <DONE>
uiwait(hpulse);

for i = 1:nUI					% pull the pertinent information from the UI elements (only the valid ones)
	if ~isnan(huiset(i))
		pulseUI(i).uistring = get(huiset(i),'String');
		pulseUI(i).uivalue = get(huiset(i),'Value');
	end;
end;
								% delete figure assuming all went well
if ishandle(hpulse), delete(hpulse); end;

end; % if hButton %

varargout{1} = pulseUI;
varargout{2} = tbase;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function CITest_PulseOptions_CloseFcn(src,event)

if strcmp(get(gcbf,'waitstatus'),'waiting')
	uiresume;				% like DONE button, resuming will lead figure to close from within function
else
	delete(gcbf);			% otherwise the function terminated, so just close the figure
	disp('Pulse Options window was closed manually.');
end;


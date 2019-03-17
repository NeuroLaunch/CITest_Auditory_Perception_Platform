function varargout = CITest_UIBlank(varargin)
% CITEST_UIBLANK MATLAB code for CITest_UIBlank.fig
%      CITEST_UIBLANK, by itself, creates a new CITEST_UIBLANK or raises the existing
%      singleton*.
%
%      H = CITEST_UIBLANK returns the handle to a new CITEST_UIBLANK or the handle to
%      the existing singleton*.
%
%      CITEST_UIBLANK('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CITEST_UIBLANK.M with the given input arguments.
%
%      CITEST_UIBLANK('Property','Value',...) creates a new CITEST_UIBLANK or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before CITest_UIBlank_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to CITest_UIBlank_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help CITest_UIBlank

% Last Modified by GUIDE v2.5 11-Jan-2013 12:06:19

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CITest_UIBlank_OpeningFcn, ...
                   'gui_OutputFcn',  @CITest_UIBlank_OutputFcn, ...
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
% End initialization code - DO NOT EDIT


% --- Executes just before CITest_UIBlank is made visible.
function CITest_UIBlank_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to CITest_UIBlank (see VARARGIN)

% Choose default command line output for CITest_UIBlank
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes CITest_UIBlank wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = CITest_UIBlank_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

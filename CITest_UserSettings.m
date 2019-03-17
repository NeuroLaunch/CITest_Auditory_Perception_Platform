% CITEST_USERSETTINGS.M
%	Utility script that sets lab-specific runtime parameters for the CITest
% graphical user interface. Settings are based on the value for 'COMPUTERID',
% which is declared in 'CITest_OpeningFcn()' in the CITEST m-file.
%	Custom analysis functions are automatically executed at the end of a run,
% though they can also be used to set up a menu entry for running an analysis
% script after the "Analysis" button is pressed. The menu script must either be
% on the MATLAB path, or the entire path must be specified within the custom
% function. (See CUSTOM_THRESHOLD in the "custom analysis" folder, for an example.)
%

% First, lab-specific settings %
switch COMPUTERID

case 'BiererLab'	
	handles.xydefault.main = [39 39];		% GUI x-y default positions for main and run-time GUIs
	handles.xydefault.runsubject = [465 42];% (in characters)
	handles.xydefault.runcontroller = [100 30];
											% default saving directories and subdirectories
	handles.fileinfo.directories.top = 'C:\BiererLabFiles\PsychophysicsData\CITest';
	handles.fileinfo.directories.threshold = '';
	handles.fileinfo.directories.mcl = '';	% keep empty if not using separate subdirectories
	handles.fileinfo.directories.gap = '';
	handles.fileinfo.directories.ptc = '';
											% "BEDCS2." for version 1.18, "BEDCS." for earlier
	handles.bedcsinfo.dir = '\BEDCS files\';% incomplete location is interpreted as subdirectory of main
	handles.bedcsinfo.actx = 'BEDCS2.CBEDCSApp';
											% incomplete location is interpreted as subdirectory of main OR its root
% 	handles.customanalysis.threshold = 'C:\steve-work\matlab\Bierer Lab\CI Test\custom analysis\custom_threshold.m';
	handles.customanalysis.threshold = '\custom analysis\custom_threshold.m';
	handles.customanalysis.ptc = '\custom analysis\custom_threshold.m';

	BEDCSDELAY = 80;						% hardware-specific absolute processing delay (in msec)
	DEMOMODE = false;
	IDSTR = 'the Bierer lab';

case 'BiererLaptop'
	handles.xydefault.main = [12 10];
	handles.xydefault.runsubject = [100 15];
	handles.xydefault.runcontroller = [100 15];

	handles.fileinfo.directories.top = 'C:\steve-work\bierer lab\data\citest\';
	handles.fileinfo.directories.threshold = '';
	handles.fileinfo.directories.mcl = '';
	handles.fileinfo.directories.gap = '';
	handles.fileinfo.directories.ptc = '';

	handles.bedcsinfo.dir = '\BEDCS files\';
	handles.bedcsinfo.actx = 'BEDCS2.CBEDCSApp';

	handles.customanalysis.threshold = '\custom analysis\custom_threshold.m';
	handles.customanalysis.ptc = '\custom analysis\custom_threshold.m';

	BEDCSDELAY = 80;
	DEMOMODE = true;
	IDSTR = 'Steve''s laptop computer';

case 'CarlyonLab'
	handles.xydefault.main = [30 30];
	handles.xydefault.runsubject = [150 100];
	handles.xydefault.runcontroller = [100 30];

	handles.fileinfo.directories.top = 'C:\data\CI Test\';
	handles.fileinfo.directories.threshold = '';
	handles.fileinfo.directories.mcl = '';
	handles.fileinfo.directories.gap = '';
	handles.fileinfo.directories.ptc = '';

	handles.bedcsinfo.dir = '\BEDCS files\';
	handles.bedcsinfo.actx = 'BEDCS2.CBEDCSApp';

	handles.customanalysis = [];
	
	BEDCSDELAY = 80;
	DEMOMODE = false;
	IDSTR = 'the Carlyon lab';

case 'OxenhamLab'
	handles.xydefault.main = [30 30];
	handles.xydefault.runsubject = [150 100];
	handles.xydefault.runcontroller = [100 30];

	handles.fileinfo.directories.top = 'C:\data\CI Test\';
	handles.fileinfo.directories.threshold = '';
	handles.fileinfo.directories.mcl = '';
	handles.fileinfo.directories.gap = '';
	handles.fileinfo.directories.ptc = '';

	handles.bedcsinfo.dir = '\BEDCS files\';
	handles.bedcsinfo.actx = 'BEDCS2.CBEDCSApp';

	handles.customanalysis = [];
	
	BEDCSDELAY = 80;
	DEMOMODE = false;
	IDSTR = 'the Oxenham lab';

case 'LaptopDemo'
	handles.xydefault.main = [30 30];
	handles.xydefault.runsubject = [150 100];
	handles.xydefault.runcontroller = [102.2 62.08];

	handles.fileinfo.directories.top = '';
	handles.fileinfo.directories.threshold = '';
	handles.fileinfo.directories.mcl = '';
	handles.fileinfo.directories.gap = '';
	handles.fileinfo.directories.ptc = '';

	handles.bedcsinfo.dir = '\BEDCS files\';
	handles.bedcsinfo.actx = 'BEDCS2.CBEDCSApp';

	handles.customanalysis = [];
	
	BEDCSDELAY = 80;
	DEMOMODE = true;
	IDSTR = 'laptop demonstration';

otherwise
	handles.xydefault.main = [30 30];
	handles.xydefault.runsubject = [150 100];
	handles.xydefault.runcontroller = [100 30];

	handles.fileinfo.directories.top = '';
	handles.fileinfo.directories.threshold = '';
	handles.fileinfo.directories.mcl = '';
	handles.fileinfo.directories.gap = '';
	handles.fileinfo.directories.ptc = '';

	handles.bedcsinfo.dir = '\BEDCS files\';
	handles.bedcsinfo.actx = 'BEDCS2.CBEDCSApp';

	handles.customanalysis = [];
	
	BEDCSDELAY = 80;
	DEMOMODE = false;
	IDSTR = 'generic functionality';

end; % switch COMPUTERID %

% Second, common settings %					% only AB and BEDCS are currently supported
handles.deviceProfile = struct('manufacturer','AB','model','','software','BEDCS v1.18',...
  'electrodes',1:16,'currentlimit',[],'phaselimit',[],'intvldelay',[]);
handles.deviceProfile.currentlimit.MPdefault = 1000;
handles.deviceProfile.currentlimit.TPdefault = 2000;
handles.deviceProfile.currentlimit.BPdefault = 1500;
handles.deviceProfile.currentlimit.absolute = 2000;
handles.deviceProfile.currentlimit.charge =	0.118;	% assumes 100 uC/cm^2 charge limit and .0012 cm^2 sites + conservative buffer
handles.deviceProfile.phaselimit = 500;				  % (must be divided by phase duration in sec to get uA)
handles.deviceProfile.intvldelay = BEDCSDELAY;

handles.userid = COMPUTERID;

fprintf(1,'CITest version %.4f intialized for %s.\n\n',VERSION,IDSTR);

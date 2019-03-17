% CUSTOM_THRSWEEPS.M
%	Bierer lab custom analysis for threshold sweeps (other modes aren't
% analyzed at present. Requires the script ANALYZE_THRSWEEPS.M to be on
% the MATLAB path.
%

function [runExtra,menuExtra] = custom_threshold(runResults,runInfo,stimInfo)

runExtra = []; menuExtra = {};

switch runInfo.mode
case 'Channel Sweep'
	runExtra = 'MENU: analyze_thrsweeps';
	menuExtra = {'analyze_thrsweeps'};
end;							% don't include the ".m" extension

% if ~strcmp(runInfo.mode,'Channel Sweep')
% 	return;						% currently, only channel sweep analysis is supported
% end;



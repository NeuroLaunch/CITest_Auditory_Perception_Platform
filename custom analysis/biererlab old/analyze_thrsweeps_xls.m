
% analyze_thrsweeps_xls.m %
% made by jab jan. 13, 2014 %
% modified from smb sept. 2013 %

SUBJECTS = {'S22','S23','S28','S29','S30L','S36','S38','S40','S41','S42','S45','D24','D26','D28','D33','D38'};
isubj = 15;%:length(SUBJECTS)
TPONLY = 0;
figure;%(isubj);
% User options and useful stuff %
xlsfile = 'C:\Julie\Manuscripts\sweep\sweepdata\R01_DataAug7_2014.xlsx';
basedir = 'c:\julie\manuscripts\sweep\sweepdata';
PLOTSYMBOL = '.';
LINESTYLE = 'none';
CONFIG = 'sqp';
TWO_IFC = 1;
%SUBJECT = 22;
% figure(1);
MP_2IFC = []; TP_2IFC = []; % row 1 is electrodes, 2 is alphas, 3 is threshold in dB re 1 uA, 4 and 5 are + and - std dev
MP_SWPsm = cell(1,2);
MP_SWPlg = cell(1,2);
MP_SWPdown = []; MP_SWPup = [];
TP_SWPsm  = cell(1,2);
TP_SWPlg = cell(1,2);
TP_SWPdown = []; TP_SWPup = [];
SAVE = 0;

IFCalphas = [0 1 1 1 1 1 1 1 1 1 1 1 1 1];

SUBJECT = SUBJECTS(isubj);
if TWO_IFC
    sheet = SUBJECTS{isubj};
    if strcmp(SUBJECTS{isubj},'D26')
        TP_2IFC(1,:) = xlsread(xlsfile,sheet,'B14:B25');
        TP_2IFC(2,:) = IFCalphas(2:end-1);
        TP_2IFC(3,:) = xlsread(xlsfile,sheet,'P14:P25');%[37.0 34.5 41.6 47.3 57.4 51.6];
        TP_2IFC(4,:) = xlsread(xlsfile,sheet,'Q14:Q25');
        TP_2IFC(5,:) = xlsread(xlsfile,sheet,'R14:R25');
        MP_2IFC(1,:) = xlsread(xlsfile,sheet,'B57:B68');
        MP_2IFC(2,:) = IFCalphas(2:end-1);
        MP_2IFC(3,:) = xlsread(xlsfile,sheet,'P57:P68');%[37.0 34.5 41.6 47.3 57.4 51.6];
        MP_2IFC(4,:) = xlsread(xlsfile,sheet,'Q57:Q68');
        MP_2IFC(5,:) = xlsread(xlsfile,sheet,'R57:R68');
    else
        TP_2IFC(1,:) = xlsread(xlsfile,sheet,'B13:B26');
        TP_2IFC(2,:) = IFCalphas;
        TP_2IFC(3,:) = xlsread(xlsfile,sheet,'P13:P26');%[37.0 34.5 41.6 47.3 57.4 51.6];
        TP_2IFC(4,:) = xlsread(xlsfile,sheet,'Q13:Q26');
        TP_2IFC(5,:) = xlsread(xlsfile,sheet,'R13:R26');
        
        MP_2IFC(1,:) = xlsread(xlsfile,sheet,'B56:B69');
        MP_2IFC(2,:) = IFCalphas;
        MP_2IFC(3,:) = xlsread(xlsfile,sheet,'P56:P69');%[37.0 34.5 41.6 47.3 57.4 51.6];
        MP_2IFC(4,:) = xlsread(xlsfile,sheet,'Q56:Q69');
        MP_2IFC(5,:) = xlsread(xlsfile,sheet,'R56:R69');
    end
    % ------------------------------------------------------- %
    save(['C:\Julie\Manuscripts\sweep\sweepdata\' SUBJECTS{isubj} 'IFC_Data'],'TP_2IFC','MP_2IFC');
else
    load(['C:\Julie\Manuscripts\sweep\sweepdata\' SUBJECTS{isubj} 'IFC_Data'],'TP_2IFC','MP_2IFC');
end
%     subplot(4,2,isubj);
errorbar(TP_2IFC(1,:),TP_2IFC(3,:),...
    TP_2IFC(4,:),TP_2IFC(5,:),'k^-',...
    'MarkerFaceColor','k','LineWidth',2);

set(gca,'XLim',[1 16],'YLim',[28 60]);
hold on;
%     if ~isempty(subject2IFC(isubj).threshold_mp)
errorbar(MP_2IFC(1,:),MP_2IFC(3,:),...
    MP_2IFC(4,:),MP_2IFC(5,:),'ko-',...
    'MarkerFaceColor','k','LineWidth',2);
%     end
legend 'sQP' 'MP';
title(SUBJECTS{isubj});

if TPONLY
    configlist = 1;
else
    configlist = 1:2;
end

% -------------------------------------------------------- %
for i= configlist;
    % now load quadrupolar sweep data
    if i==1
        [run1file,pathname] = uigetfile([basedir num2str(SUBJECTS{isubj})],'Select 1st sQP sweep run');
    else
        [run1file,pathname] = uigetfile([basedir num2str(SUBJECTS{isubj})],'Select 1st MP sweep run');
    end
    load([pathname,run1file]);
    % get run information and indices for run 1
    run1_dBval =  20*log10(runResults.values);
    run1_nStim = length(runResults.blockidx);
    run1_stimintvl = stimInfo.expParam.stimintvl; run1_sweepintvl = stimInfo.expParam.sweepintvl;
    run1_nreps = round(run1_sweepintvl/run1_stimintvl);
    run1_upstep = stimInfo.expParam.upstep; run1_downstep = stimInfo.expParam.downstep;
    run1_alphastep = mean(diff(unique(stimInfo.mainParam.configcode(2,:))));
    run1_sigma = unique(stimInfo.mainParam.configcode(1,:));
    
    % Main plot %
    if strcmp(stimInfo.mainParam.configtype,'sQP')
        xval = (stimInfo.mainParam.electrode-1) +  stimInfo.mainParam.configcode(2,:);
    else
        error('No');
    end;
    
    run1_fwdind = runResults.blockdir==+1;
    run1_padind = runResults.blockdir==0;
    run1_fwdblock = runResults.blockidx(run1_fwdind);
    run1_padblock = runResults.blockidx(run1_padind);
    
    run1_revind = runResults.blockdir==-1;
    run1_revblock = runResults.blockidx(run1_revind);
    
    tstr = sprintf('sigma: %0.2f,  alpha step: %0.2f,  repeat: %d,  up/down: %0.2f/%0.2f dB',run1_sigma,run1_alphastep,...
        run1_nreps,run1_upstep,run1_downstep);
    [junk,filestr,ext] = fileparts(runInfo.savedfile); filestr = cat(2,filestr,'.mat');
    tstr1 = sprintf('%s\n%s',filestr,tstr);
    
    run1rev_dBval = []; xvalrev = [];
    REV = 0;
    if isempty(run1_revblock) % if forward and reverse sweeps were run separately then load the reverse here %
        REV = 1;
        if i==1
            [run1file,pathname] = uigetfile([basedir num2str(SUBJECTS{isubj})],'Select 1st sQP sweep run REVERSE');
        else
            [run1file,pathname] = uigetfile([basedir num2str(SUBJECTS{isubj})],'Select 1st MP sweep run REVERSE');
        end
        load([pathname,run1file]);
        
        run1rev_dBval =  20*log10(runResults.values);
        xvalrev = (stimInfo.mainParam.electrode-1) +  stimInfo.mainParam.configcode(2,:);
        run1rev_padind = runResults.blockdir==0;
        run1rev_padblock = runResults.blockidx(run1rev_padind);
        run1_revind = runResults.blockdir==-1;
        run1_revblock = runResults.blockidx(run1_revind);
        tstr = sprintf('sigma: %0.2f,  alpha step: %0.2f,  repeat: %d,  up/down: %0.2f/%0.2f dB',run1_sigma,run1_alphastep,...
            run1_nreps,run1_upstep,run1_downstep);
        [junk,filestr,ext] = fileparts(runInfo.savedfile); filestr = cat(2,filestr,'.mat');
        tstrR = sprintf('%s\n%s',filestr,tstr);
    end
    %         figure;
    plot(xval(run1_fwdblock),run1_dBval(run1_fwdind),'ro','Marker',PLOTSYMBOL,'LineStyle',LINESTYLE);
    hold on;
    
    if i==1
        if run1_alphastep == 0.1
            TP_SWPlg{1}(1,:) = xval(run1_fwdblock);
            TP_SWPlg{1}(2,:) = run1_dBval(run1_fwdind);
            TP_SWPlg{3}(1,:) = tstr1;
            if REV
                TP_SWPlg{1}(3,:) = xvalrev(run1_revblock);
                TP_SWPlg{1}(4,:) = run1rev_dBval(run1_revind);
                TP_SWPlg{3}(2,:) = tstrR;
            else
                TP_SWPlg{1}(3,:) = xval(run1_revblock);
                TP_SWPlg{1}(4,:) = run1_dBval(run1_revind);
            end
        else
            TP_SWPsm{1}(1,:) = xval(run1_fwdblock);
            TP_SWPsm{1}(2,:) = run1_dBval(run1_fwdind);
            TP_SWPsm{3}(1,:) = tstr1;
            if REV
                TP_SWPsm{1}(3,:) = xvalrev(run1_revblock);
                TP_SWPsm{1}(4,:) = run1rev_dBval(run1_revind);
                TP_SWPsm{3}(2,:) = tstrR;
            else
                TP_SWPsm{1}(3,:) = xval(run1_revblock);
                TP_SWPsm{1}(4,:) = run1_dBval(run1_revind);
            end
        end
    else
        if run1_alphastep == 0.1
            MP_SWPlg{1}(1,:) = xval(run1_fwdblock);
            MP_SWPlg{1}(2,:) = run1_dBval(run1_fwdind);
            MP_SWPlg{3}(1,:) = tstr1;
            if REV
                MP_SWPlg{1}(3,:) = xvalrev(run1_revblock);
                MP_SWPlg{1}(4,:) = run1rev_dBval(run1_revind);
                MP_SWPlg{3}(2,:) = tstrR;
            else
                MP_SWPlg{1}(3,:) = xval(run1_revblock);
                MP_SWPlg{1}(4,:) = run1_dBval(run1_revind);
            end
        else
            MP_SWPsm{1}(1,:) = xval(run1_fwdblock);
            MP_SWPsm{1}(2,:) = run1_dBval(run1_fwdind);
            MP_SWPsm{3}(1,:) = tstr1;
            if REV
                MP_SWPsm{1}(3,:) = xvalrev(run1_revblock);
                MP_SWPsm{1}(4,:) = run1rev_dBval(run1_revind);
                MP_SWPsm{3}(2,:) = tstrR;
            else
                MP_SWPsm{1}(3,:) = xval(run1_revblock);
                MP_SWPsm{1}(4,:) = run1_dBval(run1_revind);
            end
        end
    end
    
    % plot the reverse sweep data here
    if ~isempty(run1rev_dBval)
        plot(xvalrev(run1_revblock),run1rev_dBval(run1_revind),'bo','Marker',PLOTSYMBOL,'LineStyle',LINESTYLE);
        plot(xvalrev(run1rev_padblock),run1rev_dBval(run1rev_padind),'ko','Marker','o','LineStyle','None');
    else
        plot(xval(run1_revblock),run1_dBval(run1_revind),'bo','Marker',PLOTSYMBOL,'LineStyle',LINESTYLE);
        plot(xval(run1_padblock),run1_dBval(run1_padind),'ko','Marker','o','LineStyle','None');
    end
    xlabel('Steered Channel #'); ylabel('Current Level (dB uA)');
    
    set(gca,'XLim',[.8 16.2]);
    set(gcf,'Position',[70 325 1000 355]);
    
    % %     title(tstr,'Interpreter','None');
    
    % now load and plot the second run of data
    if isubj ~=0
        if i == 1
            [run2file,pathname] = uigetfile(['c:\julie\manuscripts\sweep\subject' num2str(SUBJECTS{isubj})],'Select 2nd sQP sweep run');
        else
            [run2file,pathname] = uigetfile(['c:\julie\manuscripts\sweep\subject' num2str(SUBJECTS{isubj})],'Select 2nd MP sweep run');
        end
        load([pathname,run2file]);
        
        run2_dBval =  20*log10(runResults.values);
        run2_nStim = length(runResults.blockidx);
        run2_stimintvl = stimInfo.expParam.stimintvl; run2_sweepintvl = stimInfo.expParam.sweepintvl;
        run2_nreps = round(run2_sweepintvl/run2_stimintvl);
        run2_upstep = stimInfo.expParam.upstep; run2_downstep = stimInfo.expParam.downstep;
        run2_alphastep = mean(diff(unique(stimInfo.mainParam.configcode(2,:))));
        run2_sigma = unique(stimInfo.mainParam.configcode(1,:));
        
        % Main plot %
        if strcmp(stimInfo.mainParam.configtype,'sQP')
            xval = (stimInfo.mainParam.electrode-1) +  stimInfo.mainParam.configcode(2,:);
        else
            error('No');
        end;
        
        run2_fwdind = runResults.blockdir==+1; run2_padind = runResults.blockdir==0;
        run2_fwdblock = runResults.blockidx(run2_fwdind);
        run2_padblock = runResults.blockidx(run2_padind);
        run2_revind = runResults.blockdir==-1;
        run2_revblock = runResults.blockidx(run2_revind);
        
        tstr = sprintf('sigma: %0.2f,  alpha step: %0.2f,  repeat: %d,  up/down: %0.2f/%0.2f dB',run1_sigma,run1_alphastep,...
            run1_nreps,run1_upstep,run1_downstep);
        [junk,filestr,ext] = fileparts(runInfo.savedfile); filestr = cat(2,filestr,'.mat');
        tstr2 = sprintf('%s\n%s',filestr,tstr);
        
        run2rev_dBval = []; xvalrev = [];
        REV = 0;
        if isempty(run2_revblock) % if forward and reverse sweeps were run separately then load the reverse here %
            REV = 1;
            if i==1
                [run2file,pathname] = uigetfile([basedir num2str(SUBJECTS{isubj})],'Select 2nd sQP sweep run REVERSE');
            else
                [run2file,pathname] = uigetfile([basedir num2str(SUBJECTS{isubj})],'Select 2nd MP sweep run REVERSE');
            end
            load([pathname,run2file]);
            
            run2rev_dBval =  20*log10(runResults.values);
            xvalrev = (stimInfo.mainParam.electrode-1) +  stimInfo.mainParam.configcode(2,:);
            run2rev_padind = runResults.blockdir==0;
            run2rev_padblock = runResults.blockidx(run2rev_padind);
            run2_revind = runResults.blockdir==-1;
            run2_revblock = runResults.blockidx(run2_revind);
            tstr = sprintf('sigma: %0.2f,  alpha step: %0.2f,  repeat: %d,  up/down: %0.2f/%0.2f dB',run2_sigma,run2_alphastep,...
                run2_nreps,run2_upstep,run2_downstep);
            [junk,filestr,ext] = fileparts(runInfo.savedfile); filestr = cat(2,filestr,'.mat');
            tstrR = sprintf('%s\n%s',filestr,tstr);
        end
        
        %         figure;
        plot(xval(run2_fwdblock),run2_dBval(run2_fwdind),'go','Marker',PLOTSYMBOL,'LineStyle',LINESTYLE);
        hold on;
        
        
        if ~isempty(run2rev_dBval)
            plot(xvalrev(run2_revblock),run2rev_dBval(run2_revind),'ko','Marker',PLOTSYMBOL,'LineStyle',LINESTYLE);
            
            plot(xvalrev(run2_padblock),run2rev_dBval(run2_padind),'ko','Marker','o','LineStyle','None');
        else
            plot(xval(run2_revblock),run2_dBval(run2_revind),'ko','Marker',PLOTSYMBOL,'LineStyle',LINESTYLE);
            
            plot(xval(run2_padblock),run2_dBval(run2_padind),'ko','Marker','o','LineStyle','None');
            
        end
        xlabel('Steered Channel #'); ylabel('Current Level (dB uA)');
        
        % if ~isempty(run2_fwdblock) && ~isempty(run2_revblock)
        %     legend 'Fwd' 'Rev';
        % elseif ~isempty(run2_fwdblock)
        %     legend 'Fwd';
        % elseif ~isempty(run2_revblock)
        %     legend 'Rev';
        % end;
        
        set(gca,'XLim',[.8 16.2]);
        set(gcf,'Position',[70 325 1000 355]);
        
        if i==1
            if run2_alphastep == 0.1
                TP_SWPlg{2}(1,:) = xval(run2_fwdblock);
                TP_SWPlg{2}(2,:) = run2_dBval(run2_fwdind);
                TP_SWPlg{3}(3,:) = tstr2;
                if REV
                    TP_SWPlg{2}(3,:) = xvalrev(run2_revblock);
                    TP_SWPlg{2}(4,:) = run2rev_dBval(run2_revind);
                    TP_SWPlg{3}(4,:) = tstrR;
                else
                    TP_SWPlg{2}(3,:) = xval(run2_revblock);
                    TP_SWPlg{2}(4,:) = run2_dBval(run2_revind);
                end
            else
                TP_SWPsm{2}(1,:) = xval(run2_fwdblock);
                TP_SWPsm{2}(2,:) = run2_dBval(run2_fwdind);
                TP_SWPsm{3}(3,:) = tstr2;
                if REV
                    TP_SWPsm{2}(3,:) = xvalrev(run2_revblock);
                    TP_SWPsm{2}(4,:) = run2rev_dBval(run2_revind);
                    TP_SWPsm{3}(4,:) = tstrR;
                else
                    TP_SWPsm{2}(3,:) = xval(run2_revblock);
                    TP_SWPsm{2}(4,:) = run2_dBval(run2_revind);
                end
            end
        else
            if run2_alphastep == 0.1
                MP_SWPlg{2}(1,:) = xval(run2_fwdblock);
                MP_SWPlg{2}(2,:) = run2_dBval(run2_fwdind);
                MP_SWPlg{3}(3,:) = tstr2;
                if REV
                    MP_SWPlg{2}(3,:) = xvalrev(run2_revblock);
                    MP_SWPlg{2}(4,:) = run2rev_dBval(run2_revind);
                    MP_SWPlg{3}(4,:) = tstrR;
                else
                    MP_SWPlg{2}(3,:) = xval(run2_revblock);
                    MP_SWPlg{2}(4,:) = run2_dBval(run2_revind);
                end
            else
                MP_SWPsm{2}(1,:) = xval(run2_fwdblock);
                MP_SWPsm{2}(2,:) = run2_dBval(run2_fwdind);
                MP_SWPsm{3}(3,:) = tstr2;
                if REV
                    MP_SWPsm{2}(3,:) = xvalrev(run2_revblock);
                    MP_SWPsm{2}(4,:) = run2rev_dBval(run2_revind);
                    MP_SWPsm{3}(4,:) = tstrR;
                else
                    MP_SWPsm{2}(3,:) = xval(run2_revblock);
                    MP_SWPsm{2}(4,:) = run2_dBval(run2_revind);
                end
            end
        end
        %     title(tstr,'Interpreter','None');
    end
    
    
end % for i=1:2 for sQP and MP

if run1_alphastep == 0.1
    if SAVE
        if exist(['C:\Julie\manuscripts\sweep\SweepData\' num2str(SUBJECTS{isubj}) 'SWP_Data.mat'],'file');
            save(['C:\Julie\manuscripts\sweep\SweepData\' num2str(SUBJECTS{isubj}) 'SWP_Data'],'TP_SWPlg','MP_SWPlg','-append');
        else
            save(['C:\Julie\manuscripts\sweep\SweepData\' num2str(SUBJECTS{isubj}) 'SWP_Data'],'TP_SWPlg','MP_SWPlg');
        end
    end
else
    if SAVE
        if exist(['C:\Julie\manuscripts\sweep\SweepData\' num2str(SUBJECTS{isubj}) 'SWP_Data.mat'],'file');
            save(['C:\Julie\manuscripts\sweep\SweepData\' num2str(SUBJECTS{isubj}) 'SWP_Data'],'TP_SWPsm','MP_SWPsm','-append');
        else
            save(['C:\Julie\manuscripts\sweep\SweepData\' num2str(SUBJECTS{isubj}) 'SWP_Data'],'TP_SWPsm','MP_SWPsm');
        end
    end
end



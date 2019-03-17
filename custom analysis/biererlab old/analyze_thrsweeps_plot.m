% analyze_thrsweeps_plot.m%

% User options and useful stuff %
PLOTSYMBOL = '.';
LINESTYLE = 'none';
SUBJECT = 'S29';
LG = 1; % 1 for large alpha steps of 0.1, 0 for small steps of 0.05
iconfig = 2; % 1 for MP and 2 for sQP (TP)
RUN = 1;
SAVE = 0;

figure;
set(gca,'XLim',[.8 16.2]);
set(gcf,'Position',[70 325 1000 355]);

if LG
    load(['C:\Julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data.mat'],'TP_SWPlg','MP_SWPlg');
else
    load(['C:\Julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data.mat'],'TP_SWPsm','MP_SWPsm');
end


% New X-point hanning windowing method %
if strcmp(SUBJECT,'D26');
    xctr = 3:1.0:14
else
    xctr = 2:1.0:15;
end
WINSIZE = 0.20;								% one-sided, in units of electrode number / alpha

if iconfig == 1
    if LG
        Data = MP_SWPlg;
    else
        Data = MP_SWPsm;
    end
else
    if LG
        Data = TP_SWPlg;
    else
        Data = TP_SWPsm;
    end
end

xdiff = diff(Data{RUN}(1,:));%  xval);							% first figure out the spacing (assuming regular!)
xdiff = xdiff(xdiff>0 & xdiff<1);
alphstep = mean(xdiff);

winlength = round(WINSIZE/alphstep)*2 + 1;
if 1 % if on office computer without signal processing toolbox %
    half = (winlength+1)/2;
    w = 0.5*(1-cos(2*pi*(1:half)'/(winlength+1)));
    winvec = [w; w(end-1:-1:1)];
else
    winvec = hanning(winlength);				% winvec will always be odd-numbered in length
end

winvec = winvec/sum(winvec);
winalph = (-(winlength-1)/2:1:(winlength-1)/2)*alphstep;

for irun = 2;%:2
    RUN = irun;
    filtvalues_fwd = nan(length(winvec),length(xctr)); filtvalues_rev = nan(length(winvec),length(xctr));
    winvalues_fwd = repmat(winvec,[1 length(xctr)]); winvalues_rev = repmat(winvec,[1 length(xctr)]);
    for i = 1:length(xctr)
        for j = 1:length(winvec)					% accumulate and average data for windowing
            %             subind = ismember(Data{RUN}(1,:),find(Data{RUN}(1,:)==xctr(i)+winalph(j)));
            subind = find(Data{RUN}(1,:)==xctr(i)+winalph(j));
            if ~isempty(subind)
                filtvalues_fwd(j,i) = mean(Data{RUN}(2,subind));% dbvalues(subind));
                % 	try, filtvalues_fwd(j,i) = min(dbvalues(subind)); catch, filtvalues_fwd(j,i) = NaN; end;
                %             subind = ismember(runResults.blockidx,find(xval==xctr(i)+winalph(j))) & revind;
                subind = find(Data{RUN}(3,:)==xctr(i)+winalph(j));
                filtvalues_rev(j,i) = mean(Data{RUN}(4,subind));%dbvalues(subind));
            end;
            % 	try, filtvalues_rev(j,i) = min(dbvalues(subind)); catch, filtvalues_fwd(j,i) = NaN; end;
        end;										% for end electrodes, re-weight windowing vector
        nanind = isnan(filtvalues_fwd(:,i)); winvalues_fwd(nanind,i) = NaN;
        winvalues_fwd(~nanind,i) = winvalues_fwd(~nanind,i)./sum(winvalues_fwd(~nanind,i));
        nanind = isnan(filtvalues_rev(:,i)); winvalues_rev(nanind,i) = NaN;
        winvalues_rev(~nanind,i) = winvalues_rev(~nanind,i)./sum(winvalues_rev(~nanind,i));
    end;
    % apply window weights to data, then sum (avoiding NaNs)
    filtvalues_fwd = filtvalues_fwd .* winvalues_fwd;
    filtvalues_fwd = nansum(filtvalues_fwd);
    filtvalues_rev = filtvalues_rev .* winvalues_rev;
    filtvalues_rev = nansum(filtvalues_rev);
    
    plot(Data{RUN}(1,:),Data{RUN}(2,:),'b.');
    hold on;
    plot(Data{RUN}(3,:),Data{RUN}(4,:),'r.');
    
    if 0
    plot(xctr,filtvalues_fwd,'b-','linewidth',2);
    hold on;
    plot(xctr,filtvalues_rev,'r-','linewidth',2);
    end
    % subjidx = find(cat(2,subject2IFC.subject)==SUBJECT);
    % plot(subject2IFC(subjidx).electrode,subject2IFC(subjidx).threshold,'k^','MarkerSize',10,'MarkerFacecolor','k');
    % plot(subject2IFC(subjidx).electrode_mp,subject2IFC(subjidx).threshold_mp,'ko','MarkerSize',10,'MarkerFacecolor','k');
    
    outvec = [xctr ; filtvalues_fwd; filtvalues_rev];
    
    
    plot(outvec(1,:),mean(outvec(2:3,:)),'k^-','MarkerFaceColor','k');
    configstr = {'MP','TP'};
    eval(sprintf('%s = outvec;',[configstr{iconfig} 'OutVec' num2str(RUN)]));
    
    if SAVE
        
        if LG
            if exist(['c:\julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data_lg'],'file');
                save(['C:\Julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data_lg'],[configstr{iconfig} 'OutVec' num2str(RUN)],'-append');
            else
                save(['C:\Julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data_lg'],[configstr{iconfig} 'OutVec' num2str(RUN)]);%,'-append');
            end
        else
            if exist(['c:\julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data_sm'],'file');
                save(['C:\Julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data_sm'],[configstr{iconfig} 'OutVec' num2str(RUN)],'-append');
            else
                save(['C:\Julie\manuscripts\sweep\SweepData\' SUBJECT 'SWP_Data_sm'],[configstr{iconfig} 'OutVec' num2str(RUN)]);%,'-append');
            end
        end
    end
end
% 
% load(['C:\Julie\manuscripts\sweep\SweepData\' SUBJECT 'IFC_Data']);
% if iconfig == 1
%     errorbar(MP_2IFC(1,:),MP_2IFC(3,:),MP_2IFC(4,:),MP_2IFC(5,:),'ko');
% else
%     errorbar(TP_2IFC(1,:),TP_2IFC(3,:),TP_2IFC(4,:),TP_2IFC(5,:),'ko');
% end

set(gca,'XLim',[1 16]);
xlabel('Sweep electrode (apical to basal)');
ylabel('Stimulus level (dB re 1 uA)');
legend('Forward Sweep','Reverse Sweep','Avg Sweep');%,'Avg 2IFC');

% % Old rectangular windowing method %
% WINSIZE = 0.20;
%
% xctr = 2:1.0:15;
% winvalues_fwd = nan(1,length(xctr)); winvalues_rev = nan(1,length(xctr));
% for i = 1:length(xctr)
% 	subind = ismember(runResults.blockidx,find(xval>=xctr(i)-WINSIZE & xval<=xctr(i)+WINSIZE)) & fwdind;
% 	winvalues_fwd(i) = mean(dbvalues(subind));
% 	subind = ismember(runResults.blockidx,find(xval>=xctr(i)-WINSIZE & xval<=xctr(i)+WINSIZE)) & revind;
% 	winvalues_rev(i) = mean(dbvalues(subind));
% end;

% [cc,cclags] = xcorr(dbvalues(fwdind),dbvalues(revind),30,'coeff');
% figure;
% plot(cclags,cc);

% Channel-centered averages %
% if strcmp(stimInfo.mainParam.configtype,'sQP')
% 	xalph = stimInfo.mainParam.configcode(2,:);
% 	xelec = stimInfo.mainParam.electrode;
% else
% 	error('No');
% end;


% % Old straight filtering %
% winsize = 1.0 * nreps / alphastep;
% taps = ones(1,ntaps)/ntaps;
% fdata_fwd = filtfilt(taps,1,runResults.values(fwdind));
% fdata_rev = filtfilt(taps,1,fliplr(runResults.values(revind)));
% fdata_rev = fliplr(fdata_rev);
%
% figure;
% stim_pad = 1:length(find(padind)); stim_pad = stim_pad - length(stim_pad);
% stim_fwd = 1:length(find(fwdind));
% stim_rev = 1:length(find(revind));
% stim_rev = stim_rev(end:-1:1) + length(stim_fwd) - length(stim_rev);
% plot(stim_pad,runResults.values(padind),'k.');
% hold on;
% plot(stim_fwd,runResults.values(fwdind),'b.');
% plot(stim_fwd,fdata_fwd,'b-');
% plot(stim_rev,runResults.values(revind),'r.');
% plot(stim_rev,fdata_rev,'r-');


% %--------------------
% if strcmp(stimInfo.mainParam.configtype,'sQP')
% 	xalph = stimInfo.mainParam.configcode(2,:);
% 	xelec = stimInfo.mainParam.electrode;
% else
% 	error('No');
% end;
%
% normvalues = nan(1,nStim);
% for i = unique(xelec)
% 	subind = [runResults.blockidx == find(xelec==i & xalph==1)] & fwdind;
% 	normref_f = mean(runResults.values(subind));
% 	subind = ismember(runResults.blockidx,find(xelec==i)) & fwdind;
% 	normvalues(subind) = runResults.values(subind) / normref_f;
%
% 	subind = [runResults.blockidx == find(xelec==i & xalph==1)] & revind;
% 	normref_r = mean(runResults.values(subind));
% 	subind = ismember(runResults.blockidx,find(xelec==i)) & revind;
% 	normvalues(subind) = runResults.values(subind) / normref_f;	% using forward normalization
% end;
%
% figure;
% subplot(2,1,1);
% plot(xalph(fwdblock),normvalues(fwdind),'bo','Marker',PLOTSYMBOL); ylim([0 3]);
% subplot(2,1,2);
% plot(xalph(revblock),normvalues(revind),'ro','Marker',PLOTSYMBOL); ylim([0 3]);
% % plot(xalph(padblock),normvalues(padind),'ko','Marker','o','LineStyle','None');
% xlabel('Alpha'); ylabel('Current Level (uA)');
%

function [stn, decpt, sd, sd2, sd3, nonfilt, hannfilterorder] = calciumdxdettrial(x,region,detectionType,varargin)
% cnum=353; %testing
% x=trSign*nt(cnum,:); %testing without calling function
% sign=-1; %testing
%based on calciumdxdettrial.m calcium event detection from INMED.  Refined by James Ackman 2009-2011.

%disp('--------------------------------------------')
%disp(varargin)


% Check some basic requirements of the data
if nargin == 0 || nargin == 1,
  error ('You must supply the dF/F trace and region data structure as input arguments.');
end

if nargin < 3 || isempty(detectionType), detectionType = 'normal'; end   %defaults to 'normal'. Can be set to 'waves' for different default detection params.

if strcmp(detectionType, 'waves')
	hannfilterorder = 10;
	sd=2;  %number of std dev to make threshold for detection
	sd2=1;   %keep at 1 sd if there are large artifacts present in the same direction as the signal that are bigger than the signals of interest.
	sd3=1;  %no. of stddev above average whole trace change.  2 is fine unless large baseline shifts in traces or big pos artifacts.
	nonfilt = 0; %true(1) or false(0). Determines whether or not to use the orignal, non-low pass filtered data for signal onset refinement around line 215. Can be set to nonfilt = 1 (true) for already filtered data, or data with low acquisition rates (low noise during signal rise times).
	hipass = 'false';
	slidingWinStartFrame = 3;
	%----setup defaults for block size and F0 baseline window size-------------
	%old def for inmed data (~10Hz in vitro fura2-AM imaging)
	block_size = 3; %delta spacing for spikes and length of window in which to look for local minima in points.
	% start_baseline = 50; %baseline in pts 
	% end_baseline = 5; %baseline in pts	
	%block_size = round(3/region.timeres); %%delta spacing for spikes and length of window in which to look for local minima in points.
	start_baseline = round(22/region.timeres); %22sec baseline. Converted to no. of frames here.
	end_baseline = round(4.5/region.timeres); %4.5 sec end baseline.
	blockSizeMultiplier = 2;
	windowAverage = 'mean'; %string: 'mean' | 'median'    	 
	baselineAverage = 'all'; %string: 'window' | 'all' 
	maxOffsetTime = 0; %in sec.  15fr at 10Hz or 1.5sec is the one originally used with this code
	makePlots = 'false';
else
	hannfilterorder = 2;
	sd=2;  %number of std dev to make threshold for detection
	sd2=1;   %keep at 1 sd if there are large artifacts present in the same direction as the signal that are bigger than the signals of interest.
	sd3=1;  %no. of stddev above average whole trace change.  2 is fine unless large baseline shifts in traces or big pos artifacts.
	nonfilt = 1; %true(1) or false(0). Determines whether or not to use the orignal, non-low pass filtered data for signal onset refinement around line 215. Can be set to nonfilt = 1 (true) for already filtered data, or data with low acquisition rates (low noise during signal rise times).
	hipass = 'true';
	slidingWinStartFrame = 3;
	%----setup defaults for block size and F0 baseline window size-------------
	%old def for inmed data (~10Hz in vitro fura2-AM imaging)
	block_size = 3; %delta spacing for spikes and length of window in which to look for local minima in points.
	% start_baseline = 50; %baseline in pts 
	% end_baseline = 5; %baseline in pts	
	%block_size = round(3/region.timeres); %%delta spacing for spikes and length of window in which to look for local minima in points.
	start_baseline = round(22/region.timeres); %22sec baseline. Converted to no. of frames here.
	end_baseline = round(4.5/region.timeres); %4.5 sec end baseline.
	blockSizeMultiplier = 2;
	windowAverage = 'mean'; %string: 'mean' | 'median'    	 
	baselineAverage = 'all'; %string: 'window' | 'all' 
	maxOffsetTime = round(5/region.timeres); %in sec.  15fr at 10Hz or 1.5sec is the one originally used with this code
	makePlots = 'false';
end
%----END setup defaults ---------------------------------------------------


% Read the optional parameters
if (rem(length(varargin),2)==1)
  error('Optional parameters should always go by pairs');
else
	for i=1:2:(length(varargin)-1)
		if ~ischar (varargin{i}),
		  error (['Unknown type of optional parameter name (parameter' ...
			  ' names must be strings).']);
		end
		switch varargin{i}
		 case 'parameterArray'
		  parameterArray = varargin{i+1};
		end
	end
	varargin = parameterArray;
end

% Read the optional parameters
if (rem(length(varargin),2)==1)
  error('Optional parameters should always go by pairs');
else
  for i=1:2:(length(varargin)-1)
    if ~ischar (varargin{i}),
      error (['Unknown type of optional parameter name (parameter' ...
	      ' names must be strings).']);
    end
    % change the value of parameter
    switch lower (varargin{i})
     case 'hannfilterorder'
      hannfilterorder = varargin{i+1};
     case 'sd'
      sd = varargin{i+1};      
     case 'sd2'
      sd2 = varargin{i+1};
     case 'sd3'
      sd3 = varargin{i+1};     	 
     case 'nonfilt'
      nonfilt = varargin{i+1}; %numeric: 0 | 1     	 
     case 'hipass'
      hipass = lower (varargin{i+1}); % string: 'true' | 'false'    	 
     case 'slidingwinstartframe'
      slidingWinStartFrame = varargin{i+1}; 
     case 'block_size'
      block_size = varargin{i+1};      
     case 'start_baseline'
      start_baseline = varargin{i+1};
     case 'end_baseline'
      end_baseline = varargin{i+1}; 
     case 'blocksizemultiplier'
      blockSizeMultiplier = varargin{i+1}; 
     case 'maxoffsettime'
      maxOffsetTime = varargin{i+1};
	 case 'windowaverage'
	  windowAverage = lower (varargin{i+1}); % string: 'mean' | 'median'    	 
	 case 'baselineaverage'
      baselineAverage = lower (varargin{i+1}); % string: 'window' | 'all'    	 
     case 'makeplots'
      makePlots = lower (varargin{i+1}); % string: 'true' | 'false'    	 
     otherwise
      % Hmmm, something wrong with the parameter string
      error(['Unrecognized parameter: ''' varargin{i} '''']);
    end;
  end;
end

avgchangeAll = mean(abs(diff(x)));
stdchangeAll = std(abs(diff(x)));

%Make linear interpolation over artifact periods so that baseavg is not too disturbed for peak detections.
% x = nt(num,:);
% randV = stdchangeAll*randn(1,dx);
if isfield(region,'artifactFrames')
    if ~isempty(region.artifactFrames)
        for i = 1:size(region.artifactFrames,1)
            dx = (region.artifactFrames(i,2))-(region.artifactFrames(i,1));
            m = (x(1,region.artifactFrames(i,2)) - x(1,region.artifactFrames(i,1)))/dx;
%             m = (nt(num,region.artifactFrames(i,2)) - nt(num,region.artifactFrames(i,1)))/dx;
            randV = stdchangeAll*randn(1,dx);
            b = x(1,region.artifactFrames(i,1));
            newY = (m.*(1:dx) + b) + randV;
            x(1,region.artifactFrames(i,1)+1:region.artifactFrames(i,2)) = newY;
        end
%         figure; plot(x); zoom xon
    end
end

%======Apply hipass/detrending filter=====================================================
if strcmp(hipass,'true')
	%----hipass filtering for baseline correction of region.traces-------------
	%Wn = Df/(0.5 * Sf);  %Df = desired cutoff freq; Sf = sampling frequency (1/region.timeres)
	%Df= (0.005) * (0.5 * (1/region.timeres)) %for the hipass Desired cutoff freq
	% Nyq=0.5*(1/region.timeres);
	hipasscutoff = 0.005;
	% xf=zeros(size(y));

	if 900 >= size(region.traces,2)
		highfilterorder=round((size(region.traces,2)/3)) - 2;  %data must of length of greater than 3x filter order.
	else
		highfilterorder = 300;
	end
	xf=filtfilt(fir1(highfilterorder,hipasscutoff,'high'),1,x);
	y = myfilter(xf, hannfilterorder); %perform low pass hann filtering of data with default order 2.  This can be changed to improve detect of signals you're interested in.
else
	y = myfilter(x,hannfilterorder); %if you don't want to use high pass baseline correction.
end


%==========Begin finding peaks, iteratively looping through the  baseblocks===============
tr=y;
isused = zeros(1,length(tr));
pk = 1;
st = 1;
baseavgs=[];

%--try to get initial st (spike time) and pk (peak time) estimates-----------------------
for c = slidingWinStartFrame:block_size:length(tr)-block_size  %loop through block sizes
    [dummy min_location] = min(tr(c:c+block_size-1)); %fetch local minima (our possible signals)
    min_location = min_location+c-1;
    
    %setup baseblock and blocksize
    if min_location - pk(end) < blockSizeMultiplier*block_size  %if next min_location is inside twice the block size from last pk
        baseblock = tr(pk(end):min_location); %baseblock will be from last peak to current min_location
        baseavg = max(baseblock);
    else %if next min_location is far enough from last pk
        baseblock = tr(max([1 min_location-start_baseline]):max([1 min_location-end_baseline]));  %Here the baseline block is set for calculating the average and standard deviation within the rolling window
		switch windowAverage
		 case 'mean'
			baseavg = mean(baseblock(baseblock>=median(baseblock))); %problem is here in baseavgg. Weighted mean for base avg. Take the mean of those values above the median. Baseavg get shifted if there are any large positive peak in the baseblock.
		 case 'median'
			baseavg = median(baseblock); %much better. Now not susceptible to positive dF influences. This should be okay, especially for already weighted/smoothed data (like detection of zartifact transients on averaged tr data)
		end
    end
    switch baselineAverage
	 case 'window'
		avgchange = mean(abs(diff(baseblock))); %use avgchange value of baseblock instead of whole trace if there are large ampl artifacts in the trace in the same direction as the signals (like rebound fluoresence change from movement)
		stdchange = std(abs(diff(baseblock))); %use stdchange value of baseblock instead of whole trace if there are large ampl artifacts in the trace in the same direction as the signals (like rebound fluoresence change from movement)
	 case 'all'
		avgchange = avgchangeAll;
		stdchange = stdchangeAll;
	end
    %no. of sd for detection set here
    if tr(min_location)-baseavg < -(avgchange+sd*stdchange) %if local change within the rolling window from peak to baseblock average is greater than the baseline fluctuations
        ps = find(tr>baseavg); %use baseavg
        ps = ps(ps < min_location); %look here for adjustment
        if ~isempty(ps)
            ps = ps(end); %single point set as spike onset first happens here
            if ps < pk(end)  %this is used to make an adjustment if the current spike onset was found to overlap with the signal for the last spike. Pretty necessary for this algorithm.
                [dummy psn] = max(tr(pk(end)+1:min_location)); %set psn as a new possible spike onset location.
                psn = psn+pk(end); %set the new possible spike onset to the appropriate index number.
                if tr(min_location) < tr(psn)
                    ps = psn;  %keep this spike onset
                else
                    ps = psn;
                    isused(ps) = 1;
                end
            end
            if isused(ps) == 0  %if this onset hasn't been used yet, add it the spike time and correponding peak times to the st and pk vectors.
%                 plot([min_location ps],[tr(min_location) tr(ps)],'-r'); %testing
                pk = [pk min_location]; %local minima accepted as signal peak at this baseblock location
                st = [st ps]; %corresponding spike time from ps calculation set here.
                baseavgs=[baseavgs baseavg];
            end
        end
    end
end
%}

% if pk is more than one data point keep pk and st, otherwise set to empty because first pk point was set to '1' as a placeholder.
if length(pk>1)
    pk = pk(2:end);
    st = st(2:end);
else
    pk = [];
    st = [];
end


%setup stn(c) and pkn(c) based on st(c) and pk(c) if st(c)-pkn(end) is less than block_size threshold. Or if pk is empty, set pkn and stn to empty.
if~isempty(pk)
    pkn = pk(1);
    stn = st(1);
    baseavgs2=baseavgs(1);
    for c = 2:length(pk)
        if st(c)-pkn(end) <= block_size %if time between a peak and subsequent spike is too little (less than block size) then merge them.
            pkn(end) = pk(c);
%             baseavgs=[baseavgs(1:c-1) baseavgs(c+1:end)];
        else 
            stn(end+1) = st(c);
            pkn(end+1) = pk(c);
            baseavgs2=[baseavgs2 baseavgs(c)];
        end
    end
else
    pkn = [];
    stn = [];
end


%Old stn(c) refinement-----------------------------------------------------
% for c = 1:length(pkn)
%     th = tr(stn(c))-(tr(stn(c))-tr(pkn(c)))/50;
%     f = find(tr>th);
%     f = f(find(f<pkn(c)));
%     if ~isempty(f)
%         stn(c) = f(end);
%     end
% end



%New stn(c) refinement------------------------------------------------------

%{
tr = x; %use the original non-filtered data
for c = 1:length(pkn)
    %{
    startpt = max([1 stn(c)-end_baseline]);  %just in case the current spike time is near beginning of recording. Otherwise end_baseline variable is the lookback index location
    endpt = find(tr>tr(stn(c))-(tr(stn(c))-tr(pkn(c)))/5);  %find all trace data greater than a 20% fractional change from the overall signal dF for the current minima peak.
%     endpt = find(tr>tr(stn(c))-(tr(stn(c))-tr(pkn(c)))/10);  %find all trace data greater than a 20% fractional change from the overall signal dF for the current minima peak.
    endpt = endpt(endpt<pkn(c)); %set endpts indices to those that occur before the current peak index
    endpt = endpt(end)+1; %set endpt to this last endpt
    dfblock = tr(startpt:endpt); %this is now a block of time surrounding the current stn(c) spike onset
    %the following lines iteratively refine down to where the spike onset should be located.
    f = find(dfblock(2:end-1)>dfblock(3:end) & dfblock(2:end-1)>dfblock(1:end-2))+startpt;
    if ~isempty(f)
        if length(tr)-f(end)-3>0  % paolo added
            f = f(end);
            for fx = 1:2
                if tr(f+fx+1)-tr(f+fx) < 4*(tr(f+fx)-tr(f))
                    f = f+fx;
                end
            end
            stn(c) = f;
        end % paolo added
        stn(c) = f;
    end
    %}
%     addded by JBA 2010-10-23
%     if tr(stn(c)) > avgchange+2*stdchange
        indRange=stn(c):pkn(c);
        ind=find(tr(indRange)>baseavgs2(c));
%         ind=find(tr(indRange)>median(baseavgs));
        %         ind=find(indRange<mean(baseavgs));
        ind=ind+stn(c)-1;
        
        stn(c)=ind(end);
%     end
end
%}
%}

%refine which spike times (stn) we keep--
%keeping only those peaks that meet an amplitude threshold criteria. For deleting small ampl transients (like from a second A.P. or SPA cell fluctuations) that are riding on top of another, much larger transient
tr=y;
% f = find(tr(stn)-tr(pkn) > 0.2*max(tr(stn)-tr(pkn))); %20% ampl change
% f = find(tr(stn)-tr(pkn) > 0.05*max(tr(stn)-tr(pkn))); %5% ampl change
f = find(tr(stn)-tr(pkn) > sd2*std(tr(stn)-tr(pkn))); %Threshold set by stddev for change in the recording.
stn = stn(f);
pkn = pkn(f);
% baseavgs2=baseavgs2(f);
%}

%refine which spike times (stn) we keep-- round2 based on whole trace avgchange
% tr(min_location)-baseavg < -(avgchange+sd*stdchange)
% tr=y;
f = find(tr(pkn)-tr(stn) < -(avgchangeAll+sd3*stdchangeAll));
% f = find(tr(stn)-tr(pkn) > sd3*std(tr(stn)-tr(pkn))); %Threshold set by stddev for change in the recording.
stn = stn(f);
pkn = pkn(f);

%Improved stn(c) signal onset refinement-- 2011-01-25 JBA
if nonfilt > 0
tr = x; %use the original non-low pass filtered data.  Good if the original acquisition rate is not to high (not too much fluctuation in transient). Otherwise use the filtered trace.
end
for c = 1:length(pkn)
    dfblock = diff(tr(stn(c):pkn(c)));
    if length(dfblock) > 1
    for j = linspace(length(dfblock),2,length(dfblock)-1)
       if dfblock(j) < 0 && dfblock(j-1) > 0
           break
       end
    end
    else
        j = 1;
    end
    stn(c)=stn(c) + j-1;
end

%fetch offset points based on where stn(c) is located--
decpt = [];
for c = 1:length(stn)
    [mn i] = min(tr(stn(c):min([stn(c)+maxOffsetTime size(x,2)])));  %find the minimum point index between stn(c) and 15 frames later (or end of recording). Should be signal peak.
    i = i+stn(c)-1; %set signal peak index i to the appropriate frame number.
        th = (tr(stn(c))+tr(i))/2; %offset will be half of dF. Could set this threshold value to something different, like getting entire transient period (set within 1SD of the total baseline signal)
    f = find(tr>th); %fetch all trace indices greater than the threshold
    f = f(f>i); %limit it to those indices occuring after the signal peak index i.
    if isempty(f)
        decpt(c) = size(x,2);
    else
        decpt(c) = f(1); %set the offset to the first point occuring at half of peak value after the signal peak has occured
    end
    if c < length(stn) && decpt(c) >= stn(c+1) %if c is not near end of recording and the current index is overlapping with the next spike onset index then make the current offset set to one frame before the next onset.
        decpt(c) = stn(c+1) - 1;
    end
    %Could add a loop here that merges transients if the time between offsets and subsequent onsets is less than blocksize
end


%Delete badframes----------------------------------------------------------
%setup list of badframes from calciumdxeventDetectArtifacts.m JBA 101025
if isfield(region,'artifactFrames')
    if ~isempty(region.artifactFrames)
        badframes=[];
        for i=1:size(region.artifactFrames,1)
            badframes{i}=region.artifactFrames(i,1):region.artifactFrames(i,2);
        end
        
        
        stnTemp=[1];
        decptTemp=[1];
        pknTemp=[1]; %
        for c = 1:length(stn)
            stnTemp=[stnTemp stn(c)];
            decptTemp=[decptTemp decpt(c)];
            pknTemp=[pknTemp pkn(c)]; %
            for j=1:length(badframes)
                f=find(badframes{j}==stn(c), 1);
                if ~isempty(f)
                    [dummy pk1]=min(tr(badframes{j}(end)+1:decpt(c)));
                    pk1=pk1+badframes{j}(end);
                    [dummy ind]= max(tr(badframes{j}(end)+1:pk1));
                    ind=ind+badframes{j}(end);
                    if ~isempty(pk1)
                        if abs(tr(ind))+2*stdchange < abs(tr(pk1))
                            stnTemp(end)=ind;
                        else
                            stnTemp=stnTemp(1:end-1);
                            decptTemp=decptTemp(1:end-1);
                            pknTemp=pknTemp(1:end-1); %
                        end
                    else
                        stnTemp=stnTemp(1:end-1);
                        decptTemp=decptTemp(1:end-1);
                        pknTemp=pknTemp(1:end-1); %
                    end
                end
            end
        end
        
        stn=stnTemp(2:end);
        decpt=decptTemp(2:end);
        pkn=pknTemp(2:end); %
    end
end
%--------------------------------------------------------------------------
%}

if strcmp(makePlots,'true')
	sign = -1;
%	figure;  %testing
	% subplot(2,1,1) %testing
	% imagesc(ntFilt2) %testing
	% subplot(2,1,2) %testing
	 plot(sign*x,'Color',[0.5 0.5 0.5]); %testing
	 hold on; %testing
	 plot(sign*y,'Color',[0 0 0]);
	 %Testing----------------------------------------------
	 for c = 1:length(pkn)
		 plot([stn(c) pkn(c)],sign*[tr(stn(c)) tr(pkn(c))],'-r');
		 plot(stn(c),sign*tr(stn(c)),'+r');
		 plot(decpt(c),sign*tr(decpt(c)),'*g');
	 end

%	str = {['hannfilterorder: ' num2str(hannfilterorder)], ['sd: ' num2str(sd)], ['sd2: ' num2str(sd2)], ['sd3: ' num2str(sd3)], ... 
%	['nonfilt: ' num2str(nonfilt)], ['hipass: ' num2str(hipass)], ['block_size: ' num2str(block_size)], ['start_baseline: ' num2str(start_baseline)], ...
%	['end_baseline: ' num2str(end_baseline)], ['maxoffsettime: ' num2str(maxOffsetTime)], ['windowAverage: ' windowAverage], ['baselineAverage: ' baselineAverage], ...
%	['slidingWinStartFrame: ' num2str(slidingWinStartFrame)], ['blockSizeMultiplier: ' num2str(blockSizeMultiplier)]};
%	%annotation('textbox', [.2 .4, .1, .1], 'String', str);
%	annotation('textbox', [.7 .8, .1, .1], 'String', str, 'Interpreter', 'none');
%	zoom xon
end

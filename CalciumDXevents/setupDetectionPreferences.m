function prefs = setupDetectionPreferences(region);

matlabUserPath = userpath;
matlabUserPath = matlabUserPath(1:end-1);
calciumdxprefs = fullfile(matlabUserPath,'calciumdxprefs.mat');
load(calciumdxprefs)

%--Make first preference set
prefs(1).name = 'normal';
prefs(1).params(1).name = 'hannfilterorder';
prefs(1).params(1).value = 2;
prefs(1).params(1).description = 'Hann low pass filter order, integer';

prefs(1).params(2).name = 'sd';
prefs(1).params(2).value = 2;
prefs(1).params(2).description = 'Number of std dev to make threshold for detection above baselineAverage, integer';

prefs(1).params(3).name = 'sd2';
prefs(1).params(3).value = 1;
prefs(1).params(3).description = 'No. of stddev above average local trace change, integer';

prefs(1).params(4).name = 'sd3';
prefs(1).params(4).value = 1;
prefs(1).params(4).description = 'No. of stddev above average whole trace change, integer';

prefs(1).params(5).name = 'nonfilt';
prefs(1).params(5).value = 1;
prefs(1).params(5).description = 'logical: 0 | 1. Determines whether or not to use the orignal, non-low pass filtered data for signal onset refinement.';

prefs(1).params(6).name = 'hipass';
prefs(1).params(6).value = 'true';
prefs(1).params(6).description = 'str: "true" | "false". Use high pass filter for detrending baseline?';

prefs(1).params(7).name = 'slidingWinStartFrame';
prefs(1).params(7).value = 3;
prefs(1).params(7).description = 'Starting frame location for sliding window, integer, def 3';

prefs(1).params(8).name = 'block_size';
prefs(1).params(8).value = 3;
prefs(1).params(8).description = 'Length of sliding window in frames in which to look for local peaks, integer, def 3 frames';

prefs(1).params(9).name = 'start_baseline';
prefs(1).params(9).value = round(22/region.timeres);
prefs(1).params(9).description = 'Baseline in frames for the sliding window from peak, integer, def 22 sec/region.timeres';

prefs(1).params(10).name = 'end_baseline';
prefs(1).params(10).value = round(4.5/region.timeres);
prefs(1).params(10).description = 'Baseline in frames for the sliding window from peak, integer, def 4.5 sec/region.timeres';

prefs(1).params(11).name = 'blockSizeMultiplier';
prefs(1).params(11).value = 2;
prefs(1).params(11).description = 'If next peak is inside N times the block size from last pk, then window will start from last peak, integer';

prefs(1).params(12).name = 'windowAverage';
prefs(1).params(12).value = 'mean';
prefs(1).params(12).description = 'str: "mean" | "median". Use weighted mean or median for window baseline.';

prefs(1).params(13).name = 'baselineAverage';
prefs(1).params(13).value = 'all';
prefs(1).params(13).description = 'str: "window" | "all". F0 baseline, either the sliding window or whole trace';

prefs(1).params(14).name = 'maxOffsetTime';
prefs(1).params(14).value = round(5/region.timeres);
prefs(1).params(14).description = 'Max no. frames for offset time, def 5 sec/region.timeres';


%--Make second preference set
prefs(2).name = 'waves';
prefs(2).params = prefs(1).params;
for i = 1:length(prefs(2).params)
	switch prefs(2).params(i).name
	 case 'hannfilterorder'
		 prefs(2).params(i).value = 10;
	 case 'nonfilt'
		 prefs(2).params(i).value = 0;
	 case 'hipass'
		 prefs(2).params(i).value = 'true';		
	 case 'maxOffsetTime'
		 prefs(2).params(i).value = 0;
	end
end


%--Add custom preference sets if they exist or else set up default 'custom1'
nPrefs = length(prefs);
if exist('dxeventsPrefs','var')
	for i=1:length(dxeventsPrefs.detector)
		switch dxeventsPrefs.detector(i).name
		 case 'calciumdxdettrial'
			for j = 1:length(dxeventsPrefs.detector(i).prefs)
				nPrefs = nPrefs+1;
				prefs(nPrefs).name = dxeventsPrefs.detector(i).prefs(j).name;
				prefs(nPrefs).params = dxeventsPrefs.detector(i).prefs(j).params;
			end
		end
	end
else	
	nPrefs = nPrefs+1;
	prefs(nPrefs).name = 'custom1';
	prefs(nPrefs).params = prefs(1).params;
	for i = 1:length(prefs(nPrefs).params)
		switch prefs(nPrefs).params(i).name
		 case 'hannfilterorder'
			 prefs(nPrefs).params(i).value = 2;
		 case 'sd'
			 prefs(nPrefs).params(i).value = 3;
		 case 'sd3'
			 prefs(nPrefs).params(i).value = 2;
		 case 'nonfilt'
			 prefs(nPrefs).params(i).value = 0;
		 case 'hipass'
			 prefs(nPrefs).params(i).value = 'false';		
		 case 'start_baseline'
			 prefs(nPrefs).params(i).value = 25;
		 case 'end_baseline'
			 prefs(nPrefs).params(i).value = 5;
		 case 'maxOffsetTime'
			 prefs(nPrefs).params(i).value = 10;
		end
	end
end

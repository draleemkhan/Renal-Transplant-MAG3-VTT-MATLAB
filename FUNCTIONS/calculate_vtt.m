function [MeanVTT_centroid, VTT_peak, Tinput_mean, Ttx_mean, Tinput_peak, Ttx_peak, Cp0, Rtx0, fp] = ...
    calculate_vtt(Cp, Rtx, t_mid, firstPassEndSec)

% calculate_vtt
%
% Purpose:
%   Calculate vascular transit time (VTT) in dynamic renal transplant MAG3 study.
%
% Methods:
%   1. Mean VTT using centroid / mean-arrival-time method
%   2. Peak-delay VTT using time-to-peak difference
%
% Inputs:
%   Cp              = vascular/input TAC
%   Rtx             = transplant kidney TAC
%   t_mid           = frame midpoint times in seconds
%   firstPassEndSec = end of first-pass window in seconds
%
% Outputs:
%   MeanVTT_centroid = mean vascular transit time by centroid method
%   VTT_peak         = peak-delay vascular transit time
%   Tinput_mean      = input mean arrival time
%   Ttx_mean         = transplant kidney mean arrival time
%   Tinput_peak      = input peak time
%   Ttx_peak         = transplant kidney peak time
%   Cp0              = baseline-corrected input TAC
%   Rtx0             = baseline-corrected transplant kidney TAC
%   fp               = logical index for first-pass frames

%% Force column vectors
Cp = Cp(:);
Rtx = Rtx(:);
t_mid = t_mid(:);

%% Match lengths
n = min([length(Cp), length(Rtx), length(t_mid)]);

Cp = Cp(1:n);
Rtx = Rtx(1:n);
t_mid = t_mid(1:n);

%% Define first-pass window
fp = t_mid <= firstPassEndSec;

if sum(fp) < 3
    error('First-pass window contains fewer than 3 frames. Increase firstPassEndSec or check frame times.');
end

%% Baseline correction using minimum value within first-pass window
Cp0  = Cp  - min(Cp(fp));
Rtx0 = Rtx - min(Rtx(fp));

Cp0(Cp0 < 0) = 0;
Rtx0(Rtx0 < 0) = 0;

%% Safety check
if sum(Cp0(fp)) == 0 || sum(Rtx0(fp)) == 0
    error('First-pass curves have zero area after baseline correction. Check ROIs or first-pass window.');
end

%% First-pass time vector
t_fp = t_mid(fp);

%% Mean arrival time / centroid method
% This is the preferred mean vascular transit time metric.
% Centroid = sum(time × activity) / sum(activity)

Tinput_mean = sum(t_fp .* Cp0(fp))  / sum(Cp0(fp));
Ttx_mean    = sum(t_fp .* Rtx0(fp)) / sum(Rtx0(fp));

MeanVTT_centroid = Ttx_mean - Tinput_mean;

%% Peak-delay method
% This is a secondary metric and may become zero if both curves peak in the same frame.

[~, idxIn] = max(Cp0(fp));
[~, idxTx] = max(Rtx0(fp));

Tinput_peak = t_fp(idxIn);
Ttx_peak    = t_fp(idxTx);

VTT_peak = Ttx_peak - Tinput_peak;

end
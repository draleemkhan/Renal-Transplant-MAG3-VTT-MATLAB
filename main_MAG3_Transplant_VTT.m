%% MAG3 Renal Transplant Vascular Transit Time Pipeline
% Author: Muhammad Aleem Khan
%
% Purpose:
% Quantify mean vascular transit time (VTT) in renal transplant dynamic MAG3 study.
%
% Outputs:
% 1. Vascular/input TAC
% 2. Transplant kidney TAC
% 3. Mean VTT using centroid / mean-arrival-time method
% 4. Peak-delay VTT
% 5. First-pass normalized curve figure
% 6. ROI figures
% 7. CSV and MAT results

clear; clc; close all;
addpath(genpath(pwd));

%% Output folder
repoFolder = pwd;
outputFolder = fullfile(repoFolder, 'outputs');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

%% Select dynamic MAG3 DICOM
[file, folder] = uigetfile({'*.dcm'}, 'Select dynamic MAG3 transplant renal DICOM');

if isequal(file,0)
    error('No DICOM file selected.');
end

dicomFile = fullfile(folder, file);

%% Load dynamic image
[img, info] = load_dynamic_dicom(dicomFile);

fprintf('Loaded image size: %d x %d x %d frames\n', size(img,1), size(img,2), size(img,3));

%% Frame timing
t_mid = get_frame_times(info);
t_mid = t_mid(:);

nFrames = size(img,3);

if length(t_mid) ~= nFrames
    n = min(length(t_mid), nFrames);
    img = img(:,:,1:n);
    t_mid = t_mid(1:n);
    warning('Frames and timing mismatch. Trimmed to %d frames.', n);
end

%% Reference images
sumAll = sum(img,3);
sumEarly = sum(img(:,:,1:min(20,size(img,3))),3);

sumAll_disp = enhance_inverse_display(sumAll);
sumEarly_disp = enhance_inverse_display(sumEarly);

figure;
imshow(sumAll_disp, []);
colormap(flipud(gray));
title('Inverse Grayscale Summed Dynamic Image');
exportgraphics(gcf,...
    fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'),...
    'Resolution',300);
savefig(gcf, fullfile(outputFolder,'01_inverse_summed_dynamic_image.fig'));

figure;
imshow(sumEarly_disp, []);
colormap(flipud(gray));
title('Inverse Grayscale Early First-Pass Image');
exportgraphics(gcf,...
    fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'),...
    'Resolution',300);
savefig(gcf, fullfile(outputFolder,'02_inverse_early_first_pass_image.fig'));

%% Draw vascular/input ROI
disp('Draw vascular/input ROI: iliac artery, aorta, or cardiac/aortic blood pool depending on field of view.');
[Cp, maskInput] = draw_roi_get_mask_tac(img, sumEarly, 'Draw vascular/input ROI');

figure;
imshow(sumEarly_disp, []);
colormap(flipud(gray));
title('Vascular/Input ROI');
hold on;
visboundaries(maskInput, 'Color', 'y', 'LineWidth', 1.5);
exportgraphics(gcf,...
    fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'),...
    'Resolution',300);
savefig(gcf, fullfile(outputFolder,'03_input_roi.fig'));

%% Draw transplant kidney ROI
disp('Draw transplant kidney ROI.');
[Rtx, maskTx] = draw_roi_get_mask_tac(img, sumAll, 'Draw transplant kidney ROI');

figure;
imshow(sumAll_disp, []);
colormap(flipud(gray));
title('Transplant Kidney ROI');
hold on;
visboundaries(maskTx, 'Color', 'c', 'LineWidth', 1.5);
exportgraphics(gcf,...
    fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'),...
    'Resolution',300);
savefig(gcf, fullfile(outputFolder,'04_transplant_kidney_roi.fig'));

%% Smooth TACs
Cp_s  = smoothdata(Cp(:),  'sgolay', 5);
Rtx_s = smoothdata(Rtx(:), 'sgolay', 5);

Cp_s(Cp_s < 0) = 0;
Rtx_s(Rtx_s < 0) = 0;

%% Plot full TACs
figure;
plot(t_mid, Cp_s, 'k', 'LineWidth', 2); hold on;
plot(t_mid, Rtx_s, 'b', 'LineWidth', 2);
xlabel('Time (sec)');
ylabel('Mean counts');
legend('Input','Transplant kidney');
title('Full Dynamic MAG3 TACs');
grid on;
exportgraphics(gcf,...
    fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'),...
    'Resolution',300);
savefig(gcf, fullfile(outputFolder,'05_full_TACs.fig'));

%% First-pass window
% For vascular transit, use early first-pass only.
% Start with 60 sec; if acquisition has 1–3 sec frames, 30–45 sec may be better.
firstPassEndSec = 60;

[MeanVTT_centroid, VTT_peak, Tinput_mean, Ttx_mean, Tinput_peak, Ttx_peak, Cp0, Rtx0, fp] = ...
    calculate_vtt(Cp_s, Rtx_s, t_mid, firstPassEndSec);

fprintf('\n--- MAG3 Transplant Vascular Transit Time Results ---\n');
fprintf('Input mean arrival time      = %.2f sec\n', Tinput_mean);
fprintf('Transplant mean arrival time = %.2f sec\n', Ttx_mean);
fprintf('Mean VTT (Centroid Method)   = %.2f sec\n', MeanVTT_centroid);
fprintf('\n');
fprintf('Input peak time              = %.2f sec\n', Tinput_peak);
fprintf('Transplant peak time         = %.2f sec\n', Ttx_peak);
fprintf('Peak-delay VTT               = %.2f sec\n', VTT_peak);

if VTT_peak == 0
    warning('Peak-delay VTT is zero. This may reflect limited temporal resolution or same-frame peaks.');
end

%% Plot first-pass normalized curves
figure;
plot(t_mid(fp), Cp0(fp)./max(Cp0(fp)), 'k', 'LineWidth', 2); hold on;
plot(t_mid(fp), Rtx0(fp)./max(Rtx0(fp)), 'b', 'LineWidth', 2);

xline(Tinput_mean, '--k', 'Input mean arrival');
xline(Ttx_mean, '--b', 'Transplant mean arrival');

xlabel('Time (sec)');
ylabel('Normalized counts');
legend('Input','Transplant kidney','Location','best');
title(sprintf('First-Pass VTT | Mean VTT = %.2f sec | Peak-Delay VTT = %.2f sec', ...
    MeanVTT_centroid, VTT_peak));
grid on;

exportgraphics(gcf,...
    fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'),...
    'Resolution',300);
savefig(gcf, fullfile(outputFolder,'06_first_pass_VTT.fig'));

%% Summary image
figure;
subplot(1,2,1);
imshow(sumEarly_disp, []);
colormap(flipud(gray));
title('Input ROI');
hold on;
visboundaries(maskInput, 'Color', 'y', 'LineWidth', 1.5);

subplot(1,2,2);
imshow(sumAll_disp, []);
colormap(flipud(gray));
title('Transplant Kidney ROI');
hold on;
visboundaries(maskTx, 'Color', 'c', 'LineWidth', 1.5);

sgtitle('MAG3 Transplant VTT ROI Summary');
exportgraphics(gcf,...
    fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'),...
    'Resolution',300);
savefig(gcf, fullfile(outputFolder,'07_roi_summary.fig'));

%% Save results
results.PatientName = '';
if isfield(info,'PatientName')
    results.PatientName = info.PatientName;
end

results.PatientID = '';
if isfield(info,'PatientID')
    results.PatientID = info.PatientID;
end

results.StudyDate = '';
if isfield(info,'StudyDate')
    results.StudyDate = info.StudyDate;
end

results.t_mid = t_mid;
results.Cp = Cp_s;
results.Rtx = Rtx_s;
results.maskInput = maskInput;
results.maskTx = maskTx;
results.firstPassEndSec = firstPassEndSec;

results.Tinput_meanArrival_sec = Tinput_mean;
results.Ttx_meanArrival_sec = Ttx_mean;
results.Mean_VTT_centroid_sec = MeanVTT_centroid;

results.Tinput_peak_sec = Tinput_peak;
results.Ttx_peak_sec = Ttx_peak;
results.PeakDelay_VTT_sec = VTT_peak;

save(fullfile(outputFolder,'MAG3_Transplant_VTT_Results.mat'), 'results');

%% Save numerical summary as CSV
summaryTable = table( ...
    Tinput_mean, Ttx_mean, MeanVTT_centroid, ...
    Tinput_peak, Ttx_peak, VTT_peak, firstPassEndSec, ...
    'VariableNames', {'Input_MeanArrival_sec','Transplant_MeanArrival_sec','Mean_VTT_CentroidMethod_sec', ...
                      'Input_Peak_sec','Transplant_Peak_sec','PeakDelay_VTT_sec','FirstPassWindow_sec'} );

writetable(summaryTable, fullfile(outputFolder,'MAG3_Transplant_VTT_Summary.csv'));

fprintf('\nAll outputs saved in:\n%s\n', outputFolder);
fprintf('\nPipeline completed successfully.\n');
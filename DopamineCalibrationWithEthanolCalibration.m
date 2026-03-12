%% Pixel-wise Calibration with Flat-Field Normalization
clear; clc; close all;

%% 1. Load Main Image Sequence (.tif)
folderPath = uigetdir('', 'Select the folder containing TIF images');
if folderPath == 0, error('User cancelled folder selection'); end
tifFiles = dir(fullfile(folderPath, '*.tif'));
numImages = length(tifFiles);
if numImages == 0, error('No TIF files found in the directory'); end

% Read first image to get dimensions
firstImg = imread(fullfile(folderPath, tifFiles(1).name));
[rows, cols] = size(firstImg);
imageStack = zeros(rows, cols, numImages, 'double');

fprintf('Loading %d images...\n', numImages);
for i = 1:numImages
    imageStack(:,:,i) = double(imread(fullfile(folderPath, tifFiles(i).name)));
end

%% 2. Pre-processing: 5x5 Spatial Smoothing
fprintf('Applying 5-by-5 spatial smoothing filter to image stack...\n');
h = fspecial('average', [5 5]); 
for i = 1:numImages
    imageStack(:,:,i) = imfilter(imageStack(:,:,i), h, 'replicate');
end

%% 3. Load Calibration Frame & Apply Normalization Factor
[calFile, calPath] = uigetfile('*.tif', 'Select the Reference Calibration Frame (.tif)');
if calFile == 0, error('User cancelled calibration file selection'); end

% Load and smooth the calibration frame
calFrame = double(imread(fullfile(calPath, calFile)));
h2 = fspecial('average', [15 15]); 
calFrameSmoothed = imfilter(calFrame, h2, 'replicate');

% Calculate Calibration Factor: 60 / pixel value
% We use '60 ./ calFrameSmoothed' for element-wise division
calFactorMap = 60 ./ calFrameSmoothed;

% Handle potential division by zero (e.g., dead pixels in cal frame)
calFactorMap(isinf(calFactorMap) | isnan(calFactorMap)) = 0;

fprintf('Normalizing image stack using calibration factor (Target = 60)...\n');
for i = 1:numImages
    imageStack(:,:,i) = imageStack(:,:,i) .* calFactorMap;
end

%% 4. Load Concentration Values
[excelFile, excelPath] = uigetfile({'*.xlsx';'*.csv'}, 'Select Concentration File');
if excelFile == 0, error('User cancelled file selection'); end
concentrations = readmatrix(fullfile(excelPath, excelFile));
concentrations = concentrations(~isnan(concentrations));
concentrations = concentrations(:);

if numImages ~= length(concentrations)
    error('Mismatch: %d images vs %d concentrations.', numImages, length(concentrations));
end

%% 5. Calculate Slope (b), Intercept (m), & R^2 (Vectorized)
% Fitting Equation: y = bx + m
fprintf('Calculating calibration metrics per pixel...\n');
pixelData = reshape(imageStack, [], numImages)'; 

% X matrix: 1st column is 'ones' for intercept (m), 2nd is concentrations for slope (b)
X = [ones(length(concentrations), 1), concentrations];
B = X \ pixelData; 

% Extract coefficients
interceptMap = reshape(B(1,:), [rows, cols]); % m
slopeMap = reshape(B(2,:), [rows, cols]);     % b

% R^2 Calculation
yFit = X * B;
yMean = mean(pixelData, 1);
SStot = sum((pixelData - yMean).^2, 1);
SSres = sum((pixelData - yFit).^2, 1);
R2 = 1 - (SSres ./ SStot);
R2(SStot == 0) = 0;
rSquaredMap = reshape(R2, [rows, cols]);

%% 6. Plot Heatmaps
%slopeRange = [prctile(slopeMap(:), 1), prctile(slopeMap(:), 99)]; 
slopeRange = [0, 80]; 
r2Range    = [0.9, 1.0]; 

fig = figure('Color', 'w', 'Position', [100, 100, 1400, 600], 'Name', 'Dopamine Calibration Report');

ax1 = subplot(1,2,1);
imagesc(slopeMap); colorbar; axis image; clim(slopeRange);
colormap(ax1, parula); title('Slope (b) (Normalized & Smoothed)');

ax2 = subplot(1,2,2);
imagesc(rSquaredMap); colorbar; axis image; clim(r2Range);
colormap(ax2, hot); title('R^2 (Linearity)');

%% 7. Display Global Averages
% Calculate the average slope (b) and intercept (m) across all pixels
avg_b = mean(slopeMap(:), 'omitnan');
avg_m = mean(interceptMap(:), 'omitnan');

fprintf('\n========================================\n');
fprintf('Global Pixel Averages for Fitting (y = bx + m):\n');
fprintf('Average Slope (b):      %.4f\n', avg_b);
fprintf('Average Intercept (m):  %.4f\n', avg_m);
fprintf('========================================\n');
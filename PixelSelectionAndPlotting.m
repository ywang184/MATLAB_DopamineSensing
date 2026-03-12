%% 6. Plot Heatmaps
%slopeRange = [prctile(slopeMap(:), 1), prctile(slopeMap(:), 99)]; 
slopeRange = [0, 80]; 
r2Range    = [0.9, 1.0]; 

fig = figure('Color', 'w', 'Position', [100, 100, 1400, 600], 'Name', 'Dopamine Calibration Report');

ax1 = subplot(1,2,1);
imagesc(slopeMap); colorbar; axis image; clim(slopeRange);
colormap(ax1, parula); title('Slope (Normalized & Smoothed)');

ax2 = subplot(1,2,2);
imagesc(rSquaredMap); colorbar; axis image; clim(r2Range);
colormap(ax2, hot); title('R^2 (Linearity)');
%% 9. Manual Pixel Selection & Validation Plotting
% This allows you to pick 3 specific points on the Slope Map for analysis.
% double check axis title
% update the file names

fprintf('\nACTION: Click 3 points on the Slope Map to analyze individual pixels.\n');
axes(ax1); % Ensure we are clicking on the Slope Map
hold on;

% 1. Get 3 points from the user
[selectedC, selectedR] = ginput(3); 

% Round to nearest integer for pixel coordinates
selectedR = round(selectedR);
selectedC = round(selectedC);

% Plot markers on the map and SAVE this version of the heatmap
plot(selectedC, selectedR, 'rx', 'MarkerSize', 15, 'LineWidth', 2);
saveas(gcf, 'SlopeMap_with_Pixel_Locations.png'); % Save the "Map with Marks"

% 2. Determine Global Y-Axis Limits for consistency
% We look at the min/max of all 3 selected pixels to set a single range
allSelectedData = imageStack(selectedR, selectedC, :);
yMin = min(allSelectedData(:)) * 0.9; % 10% padding
yMax = max(allSelectedData(:)) * 1.1;

figPix = figure('Name', 'Manual Pixel Validation', 'Color', 'w', 'Position', [100, 100, 1200, 400]);
pixelStats = cell(3, 1);

for p = 1:3
    r = selectedR(p);
    c = selectedC(p);
    
    % Boundary check
    r = max(1, min(r, rows));
    c = max(1, min(c, cols));
    
    % Extract normalized intensities
    yVals = squeeze(imageStack(r, c, :));
    
    % Get individual pixel stats
    idx = (c-1)*rows + r;
    p_slope = B(2, idx);
    p_inter = B(1, idx);
    p_R2 = R2(idx);
    
    % Generate the full fitting equation string
    eqStr = sprintf('y = %.2fx + (%.2f)', p_slope, p_inter);
    % Create subplot for each pixel
    subplot(1, 3, p);
    plot(concentrations, yVals, 'ks', 'MarkerFaceColor', [0.3 0.7 0.9], 'MarkerSize', 8); 
    hold on;
    plot(concentrations, p_slope*concentrations + p_inter, 'r-', 'LineWidth', 2);
    
    % --- Visual Styling ---
    grid off; 
    ylim([yMin yMax]); 
    ylabel('∆θ(mDeg)'); 
    xlabel('log(Concentration, nM)');
    title(sprintf('Pixel Location: (%d, %d)', r, c));
    
    % Legend showing the complete equation and R-squared
    legend('Data Points', sprintf('%s\nR^2: %.4f', eqStr, p_R2), 'Location', 'best');
    % -------------------
    
    % Store data for Excel export
    pixelStats{p} = [r, c, p_slope, p_inter, p_R2];
end

%     % Plotting individual pixel fits
%     subplot(1, 3, p);
%     plot(concentrations, yVals, 'ks', 'MarkerFaceColor', [0.3 0.7 0.9]); hold on;
%     plot(concentrations, p_slope*concentrations + p_inter, 'r-', 'LineWidth', 1.5);
% 
%     % --- Refinements ---
%     grid off; % 1. No grid lines
%     ylim([yMin yMax]); % 3. Consistent Y-axis range
%     % -------------------
% 
%     title(sprintf('Pixel (%d, %d)', r, c));
%     xlabel('log(Concentration, nM)'); 
%     if p == 1, ylabel('∆θ(mDeg)'); end
%     legend('Data', sprintf('Slope: %.2f\nR^2: %.4f', p_slope, p_R2), 'Location', 'best');
% 
%     % Store for Excel
%     pixelStats{p} = [r, c, p_slope, p_R2];
% end

saveas(figPix, 'Manual_Pixel_Fits_ConsistentY_03062026_1.png');

%% 10. Export Final Results to Excel
fprintf('\nExporting detailed results to Excel...\n');

% 1. Create ROI Summary Table
% This table has 3 columns: Metric, Value, StdDev
roiHeader = {'Metric', 'Value', 'StdDev'};
roiData = {
    'ROI_Slope', meanSlope, stdSlope;
    'ROI_RSquared', meanR2, stdR2
};
T_roi = cell2table(roiData, 'VariableNames', roiHeader);

% 2. Create Selected Pixel Table
% FIX: Ensure exactly 5 names to match [r, c, p_slope, p_inter, p_R2]
pixHeader = {'Pixel_Row', 'Pixel_Column', 'Slope', 'Intercept', 'RSquared'};

% Combine the cell array of results into one numeric matrix
pixelMatrix = vertcat(pixelStats{:});

% Convert to table
T_pix = array2table(pixelMatrix, 'VariableNames', pixHeader);

% 3. Write to file
excelOut = 'Calibration_Detailed_Report.xlsx';
writetable(T_roi, excelOut, 'Sheet', 'ROI_Summary');
writetable(T_pix, excelOut, 'Sheet', 'Selected_Pixels');

fprintf('Success! Excel file saved: %s\n', excelOut);

% Try to open the file automatically (Windows only)
if ispc
    winopen(excelOut);
end
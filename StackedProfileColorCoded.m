%% 1. Load the Excel Sheet
[file, path] = uigetfile('*.xlsx', 'Select the Excel profile sheet');
if isequal(file,0), error('User selected Cancel'); end
fullPath = fullfile(path, file);
dataTbl = readtable(fullPath, 'VariableNamingRule', 'preserve');
dataMat = table2array(dataTbl);

%% 2. Extract and Smooth Data
xAxis = dataMat(:, 1);
rawProfiles = dataMat(:, 2:end);
profiles = smoothdata(rawProfiles, 1, 'movmean', 10)/6.5536; 
timeLabels = dataTbl.Properties.VariableNames(2:end);

%% 3. Plotting (Top-Down Order) with Intensity Color Mapping
figure('Color', 'w', 'Units', 'normalized', 'Position', [0.1 0.1 0.6 0.8]);
hold on;

% --- SET YOUR CUSTOM COLOR RANGE HERE ---
cMin = 5;   % Replace with your desired minimum intensity
cMax = 30; % Replace with your desired maximum intensity
% ----------------------------------------

% Calculate stacking gap based on actual data to keep the layout looking good
dataMax = max(profiles(:));
stackGap = dataMax * 0.9; 
numProfiles = size(profiles, 2);

colormap(turbo); % Set the colormap for the whole figure

for i = 1:numProfiles
    % Reversed offset: First profile is highest
    offset = (numProfiles - i) * stackGap;
    currentY = profiles(:, i) + offset;

    % Prepare data for the surface trick (needs to be row vectors)
    x = xAxis';
    y = currentY';
    z = zeros(size(x));          % Flat in 3D space
    c = profiles(:, i)';         % Color mapped to the original, un-offset intensity

    % Draw the multi-colored line using surface
    surface([x;x], [y;y], [z;z], [c;c], ...
        'FaceColor', 'none', ...
        'EdgeColor', 'interp', ...
        'LineWidth', 1.5);

    % Labels (Arial, Size 12, No Bold)
    text(max(xAxis) * 1.02, currentY(end), char(timeLabels{i}), ...
        'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'normal', ...
        'VerticalAlignment', 'middle', 'Interpreter', 'none');
end

% Lock the color limits to your custom range
% Note: Use caxis([cMin, cMax]) if on MATLAB R2021b or older
clim([cMin, cMax]); 

% Add the shared colorbar to the left side
cb = colorbar;
cb.Location = 'westoutside'; 
cb.Label.String = 'Intensity';
cb.Label.FontName = 'Arial';
cb.Label.FontSize = 12;
cb.Label.FontWeight = 'bold';
cb.LineWidth = 1.0;

%% 4. Formatting: Borders and Axis
grid off;
box on; 
set(gca, 'LineWidth', 1.5, 'XColor', 'k', 'YColor', 'none'); 
set(gca, 'FontName', 'Arial', 'FontSize', 12);

%% 5. Vertical Scale Bar (50 units)
scaleVal = 25;
xRange = diff(get(gca, 'XLim'));

% Adjusted position closer to the lines to avoid overlapping the left colorbar
sbX = min(xAxis) - (0.02 * xRange); 

% Position the scale bar next to the top profile
sbYStart = (numProfiles - 1) * stackGap + min(profiles(:,1));    
line([sbX, sbX], [sbYStart, sbYStart + scaleVal], 'Color', 'k', 'LineWidth', 2.5);
capSize = xRange * 0.01;
line([sbX-capSize, sbX+capSize], [sbYStart, sbYStart], 'Color', 'k', 'LineWidth', 1.5);
line([sbX-capSize, sbX+capSize], [sbYStart+scaleVal, sbYStart+scaleVal], 'Color', 'k', 'LineWidth', 1.5);

% Scale Bar Label (Arial, Size 12, No Bold)
text(sbX - capSize, sbYStart + scaleVal/2, num2str(scaleVal), ...
    'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'right');

%% 6. Final Layout
xlabel('Shared X-Axis Units', 'FontName', 'Arial', 'FontSize', 14);
title('Top-Down Stacked Profiles', 'FontName', 'Arial', 'FontSize', 16);
% Pad X-axis for labels
set(gca, 'XLim', [min(xAxis) - (0.15 * xRange), max(xAxis) + (0.35 * xRange)]);
hold off;
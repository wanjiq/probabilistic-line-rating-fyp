%% Script 1: Weibull Parameter Estimation
% Load the data (Change 'wind_data.xlsx' to your actual file name)
data = readtable('weather_10yrwind.xlsx'); 

% Assuming your wind speed column is named 'Speed'
% If it is named differently, change data.Speed to data.YourColumnName
v = data.wind_speed; 

% Remove zero or negative values to avoid fitting errors
v(v <= 0) = []; 

% 1. Estimate Weibull Parameters using Maximum Likelihood Estimation (MLE)
% parmHat(1) is the Scale Parameter (c)
% parmHat(2) is the Shape Parameter (k)
[parmHat, ~] = wblfit(v);
c = parmHat(1);
k = parmHat(2);

fprintf('Estimated Scale Parameter (c): %.2f m/s\n', c);
fprintf('Estimated Shape Parameter (k): %.2f\n', k);

% 2. Visualization
figure;
histogram(v, 'Normalization', 'pdf', 'FaceColor', [0.7 0.8 1]); % Real data
hold on;

% Generate the fitted Weibull curve
x_range = 0:0.1:max(v);
y_weibull = wblpdf(x_range, c, k);
plot(x_range, y_weibull, 'r', 'LineWidth', 2);

title('Wind Speed Distribution (10-Year Data)');
xlabel('Wind Speed (m/s)');
ylabel('Probability Density');
legend('Measured Data', 'Fitted Weibull Curve');
grid on;
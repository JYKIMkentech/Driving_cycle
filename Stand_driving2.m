clc; clear; close all;

%% 설명서
% WLTC Driving 




%% Parameters and File Path
% File path
file_path = 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\RAW\WLTP-DHC-12-07e.xls';

% Physical constants for Power model (Tesla model 3)
a = 28.990 * 4.44822; % lbf to Newton
b = 0.4592 * 4.44822 / 0.44704; % lbf/mph to N/(m/s)
c = 0.011100 * 4.44822 / 0.44704^2; % lbf/mph^2 to N/(m/s)^2
m_vehicle = 2154.564; % vehicle mass in [kg]
epsilon = 1.05;

% Battery pack configuration
m_series = 6; % Number of cells in series
n_parallel = 74; % Number of parallel strings

% Battery parameters for a single cell
OCV_cell = 3.66; % [V] 
R_cell = 0.03 ;% Resistance [ohm]
nominal_capacity_Ah = 3.4; % [Ah]
Scaling_nominal_capacity_Ah = 55.6; % [Ah]
k = 16; % number of modules

OCV_cell = 3.2; % [V] 
R_cell = 0.0009; % Resistance [ohm]
nominal_capacity_Ah = 161; % [Ah]
Scaling_nominal_capacity_Ah = 55.6; % [Ah] % NE_CELL = 55.6Ah

%% Data Loading and Preprocessing
% Read the Excel file
data_unit = readtable(file_path, 'Sheet', 2);
data_unit(1, :) = [];


% Assume the columns are named 'Time', 'Speed_mph', etc.
% If the column names are different, adjust the following lines accordingly
time = data_unit.TotalElapsedTime;
speed_kmh = data_unit.WLTCClass3_Version5_VehicleSpeed;

% Convert speed from kmh to m/s (1 kmh = 0.27778 m/s)
speed_ms = speed_kmh * 0.27778; %[m/s]

%% Acceleration Calculation
acceleration = zeros(size(speed_ms));

% Central difference for interior points
for i = 2:length(time)-1
    acceleration(i) = (speed_ms(i+1) - speed_ms(i-1)) / (time(i+1) - time(i-1));
end

% Forward and Backward difference for the first and last points
acceleration(1) = (speed_ms(2) - speed_ms(1)) / (time(2) - time(1));
acceleration(end) = (speed_ms(end) - speed_ms(end-1)) / (time(end) - time(end-1));

% Add the calculated acceleration to the data_unit table
data_unit.Acceleration = acceleration; %[m/s^2]

% Total Distance
total_distance_km = sum((speed_ms(1:end-1) .* diff(time))) / 1000; 
fprintf('Total Distance: %.2f km\n', total_distance_km);

%% Power Model  
% Calculate pack power
% acceleration = data_unit.WLTCClass3_Version5_Acceleration;

pack_power = a * speed_ms + b * speed_ms.^2 + c * speed_ms.^3 + (1 + epsilon) * m_vehicle * speed_ms .* acceleration;
data_unit.PackPower = pack_power;

% Convert to cell power by dividing by the total number of cells (m * n)
cell_power = pack_power / (m_series * n_parallel * k );
data_unit.CellPower = cell_power;

%% Current Calculation

% -I^2 * R + OCV * I - P = 0 , P = I * V, V = OCV - I * R 
current = zeros(size(cell_power));

for i = 1:length(cell_power)
    P_cell = cell_power(i);
    discriminant = OCV_cell^2 - 4 * (-R_cell) * (-P_cell);

    if discriminant >= 0
        root1 = (-OCV_cell + sqrt(discriminant)) / (-2 * R_cell);
        root2 = (-OCV_cell - sqrt(discriminant)) / (-2 * R_cell);
        current(i) = min(root1, root2);
    else
        current(i) = NaN;
    end
end

data_unit.Current = current;

%% C-rate and Scaled Current Calculation
C_rate = current / nominal_capacity_Ah;
scaled_current = C_rate * Scaling_nominal_capacity_Ah;

data_unit.C_rate = C_rate;
data_unit.ScaledCurrent = scaled_current;

scaled_current = -scaled_current;

% Total charge and energy calculations
positive_current = current(current > 0);
positive_time = time(current > 0);

total_charge_As = trapz(positive_time, positive_current);
total_charge_Ah = total_charge_As / 3600;
total_used_Ah = trapz(time,scaled_current) / 3600; 
used_soc = (total_used_Ah/Scaling_nominal_capacity_Ah ) * 100;

%fprintf('Total Charge: %.2f Ah\n', total_charge_Ah);
fprintf('Total used Cap: %.2f Ah\n', total_used_Ah);
fprintf('Total used soc: %.2f %%\n', used_soc);

%% Plot Speed, Acceleration, and Distance
figure;
subplot(3,1,1);
plot(time, speed_ms);
xlabel('Time (seconds)');
ylabel('Speed (m/s)');
title('WLTC Speed vs Time');
grid on;

subplot(3,1,2);
plot(time, acceleration);
xlabel('Time (seconds)');
ylabel('Acceleration (m/s^2)');
title('WLTC Acceleration vs Time');
grid on;

subplot(3,1,3);
plot(time, [0; cumsum(speed_ms(1:end-1) .* diff(time))] / 1000);
xlabel('Time (seconds)');
ylabel('Distance (km)');
title('WLTC Distance vs Time');
grid on;

%% Plot Power and Current
figure;
subplot(2,1,1);
plot(time, pack_power);
xlabel('Time (seconds)');
ylabel('Power (W)');
title('WLTC Pack Power vs Time');
grid on;

subplot(2,1,2);
plot(time, current);
xlabel('Time (seconds)');
ylabel('Current (A)');
title('WLTC Cell Current vs Time');
grid on;

%% Plot C-rate and Scaled Current
figure;
subplot(2,1,1);
plot(time, -C_rate);
xlabel('Time (seconds)');
ylabel('C-rate');
title('WLTC Cell C-rate vs Time');
grid on;

subplot(2,1,2);
plot(time, scaled_current);
xlabel('Time (seconds)');
ylabel('Current (A)');
title('WLTC Scaled Cell Current vs Time');
grid on;

%% Display max speed, min speed , distance, elapsed time
max_speed_kmh = max(speed_ms) * 3.6; % m/s를 km/h로 변환
mean_speed_kmh = mean(speed_ms) * 3.6; % m/s를 km/h로 변환
total_distance_km = sum((speed_ms(1:end-1) .* diff(time))) / 1000; % 총 주행 거리 (km)
total_time_seconds = time(end) - time(1); % 총 소요시간 (초)

% 결과 출력
fprintf('최대 속도: %.2f km/h\n', max_speed_kmh);
fprintf('평균 속도: %.2f km/h\n', mean_speed_kmh);
fprintf('총 주행 거리: %.2f km\n', total_distance_km);
fprintf('총 소요 시간: %.2f 초\n', total_time_seconds);


%% Save Results to Excel
% output_table = table(time, scaled_current);
% output_folder = 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\Processed';  % 저장할 폴더 경로
% output_file_name = 'WLTP_unit_time_scaled_current.xlsx';  % 파일 이름
% 
% % 파일 전체 경로 (디렉토리 + 파일명)
% output_file_path = fullfile(output_folder, output_file_name);
% 
% % 테이블을 엑셀 파일로 저장
% writetable(output_table, output_file_path);
% fprintf('Excel file created successfully: %s\n', output_file_path);

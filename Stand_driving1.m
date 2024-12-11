clc; clear; close all;

%% Flow chart 
% 12.11 김준연 정리 완료 

% UDDS, US06, HWFET 속력 데이터 ---> 전류 데이터로 변환화는 코드


% 1. Velocity , Acceleration data --> Power 계산 ( coeff a, b, c 사용)
% 2. 전류에 대한 이차방정식을 통해 current 계산 

%% 주의 

% Raw data는 EPA 공식 홈페이지에서 다운 받음 
% a,b,c는 차량 고유의 coeff 의 값으로 LFP, NMC 차량에 따라 임의 선택하였음 
% 차량의 배터리 pack configuration 정보를 알고 있어야함 
% LFP OR NMC single parameter (nominal OCV, 내부 저항 , nominal capacity ) 알고 있어야함 
% 내부 저항은 논문 or Formation을 통해 overpotenal 계산으로 구할 수 있음 
% Scaling 할 capacity 알고 있어야함 
% epsilon = 1.05 고정 (논문 참조)

%% LFP 

% Tesla model 3 Long range AWD LFP 임 

% (출처 : https://www.batterydesign.net/tesla-lfp-model-3/)

% a = 34.98
% b = 0.0865
% c = 0.0148
% mass : 4250 lb --> 1927.768 kg 
% configuration : 106s 1p 
% (4 modules , 2x outer moudles of 25s 1p, 2x centre modules of 28s 1p) 
% 총 Cell : 106 개 
% LFP nominal OCV : 0.0009
% LFP nominal capcacity : 161 Ah

%% NMC

% Tesla model s Long range NMC 임 

% (출처1 : https://ieeexplore.ieee.org/document/8902005)
% (출처2 : https://circuitdigest.com/article/tesla-model-s-battery-system-an-engineers-perspective)

% a = 28.990
% b = 0.4592
% c = 0.0111
% mass = 4750 lb ---> 2154.564kg
% configuration : 6s 74p 
% modules 수 : 16 module --> 6 * 74 * 16 = 7104 개 cell 존재
% 총 cell : 7104개 
% NMC nominal OCV : 3.66 V
% NMC nominal Capacity : 3.4 Ah


%% Parameters and File Paths
% File paths
file_paths = struct( ...
    'udds', 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\RAW\uddscol.txt', ...
    'hwycol', 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\RAW\hwycol.txt', ...
    'us06', 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\RAW\us06col.txt'); % Added US06 file path

% Physical constants for Power model (Tesla model 3)
a = 34.98 * 4.44822; % lbf to Newton
b = 0.08650 * 4.44822 / 0.44704; % lbf/mph to N/(m/s)
c = 0.014800 * 4.44822 / 0.44704^2; % lbf/mph^2 to N/(m/s)^2
m_vehicle = 1927.768; % vehicle mass in [kg]
epsilon = 1.05;

% Battery pack configuration
m_series = 106; % Number of cells in series
n_parallel = 1; % Number of parallel strings
k = 1; % Number of modules 

% Battery parameters for a single cell
OCV_cell = 3.2; % [V] 
R_cell = 0.0009; % Resistance [ohm]
nominal_capacity_Ah = 161; % [Ah]
%Scaling_nominal_capacity_Ah = 55.6; % [Ah] 
Scaling_nominal_capacity_Ah = 55.6; % [Ah] % NE_CELL = 55.6Ah

%% File Selection
disp('Select the file to analyze:');
disp('1. UDDS (uddscol.txt)');
disp('2. HWYFET (hwycol.txt)');
disp('3. US06 (us06col.txt)'); % Added option for US06
file_choice = input('Enter the number of the file you want to process (1, 2, or 3): ');

if file_choice == 1
    file_path = file_paths.udds;
    disp('You have selected UDDS.');
    drive_cycle_name = 'UDDS';
elseif file_choice == 2
    file_path = file_paths.hwycol;
    disp('You have selected HWYCOL.');
    drive_cycle_name = 'HWFET';
elseif file_choice == 3
    file_path = file_paths.us06;
    disp('You have selected US06.');
    drive_cycle_name = 'US06';
else
    error('Invalid selection. Please enter 1, 2, or 3.');
end

%% Data Loading and Preprocessing
% Read the file
data_unit = readtable(file_path, 'Delimiter', '\t');
data_unit.Properties.VariableNames{1} = 'time';
data_unit.Properties.VariableNames{2} = 'speed_mph';

% Remove the first row if US06 is selected
if file_choice == 3
    data_unit(1, :) = [];
end

% Separate the first column as time and the second as speed
time = data_unit.time;
speed_mph = data_unit.speed_mph;

% Convert speed from mph to m/s (1 mph = 0.44704 m/s)
speed_ms = speed_mph * 0.44704;

%% Acceleration, Distance Calculation
acceleration = zeros(size(speed_ms));

% Central difference for interior points
for i = 2:length(time)-1
    acceleration(i) = (speed_ms(i+1) - speed_ms(i-1)) / (time(i+1) - time(i-1));
end

% Forward and Backward difference for the first and last points
acceleration(1) = (speed_ms(2) - speed_ms(1)) / (time(2) - time(1));
acceleration(end) = (speed_ms(end) - speed_ms(end-1)) / (time(end) - time(end-1));

% Add the calculated acceleration to the data_unit table
data_unit.acceleration = acceleration;

% Total Distance
total_distance_km = sum((speed_ms(1:end-1) .* diff(time))) / 1000;
fprintf('Total Distance: %.2f km\n', total_distance_km);

%% Power Model  
% Calculate pack power
pack_power = a * speed_ms + b * speed_ms.^2 + c * speed_ms.^3 + (1 + epsilon) * m_vehicle * speed_ms .* acceleration;
data_unit.pack_power = pack_power;

% Convert to cell power by dividing by the total number of cells (m * n)
cell_power = pack_power / (m_series * n_parallel * k);
data_unit.cell_power = cell_power;

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

data_unit.current = current;

%% C-rate and Scaled Current Calculation
C_rate = current / nominal_capacity_Ah;
scaled_current = C_rate * Scaling_nominal_capacity_Ah;

scaled_current = -scaled_current;

data_unit.C_rate = C_rate;
data_unit.scaled_current = scaled_current;

% Total charge and energy calculations
positive_current = current(current > 0);
positive_time = time(current > 0);

total_charge_As = trapz(positive_time, positive_current);
total_charge_Ah = total_charge_As / 3600;
total_used_Ah = trapz(time,scaled_current) / 3600; 
used_soc = (total_used_Ah/Scaling_nominal_capacity_Ah ) * 100;

fprintf('Total used Cap: %.2f Ah\n', total_used_Ah);
fprintf('Total used soc: %.2f %%\n', used_soc);

%% Plot Speed, Acceleration, and Distance
figure;
subplot(3,1,1);
plot(time, speed_ms);
xlabel('Time (seconds)');
ylabel('Speed (m/s)');
title([drive_cycle_name ' Speed vs Time']);
grid on;

subplot(3,1,2);
plot(time, acceleration);
xlabel('Time (seconds)');
ylabel('Acceleration (m/s^2)');
title([drive_cycle_name ' Acceleration vs Time']);
grid on;

subplot(3,1,3);
plot(time, [0; cumsum(speed_ms(1:end-1) .* diff(time))] / 1000);
xlabel('Time (seconds)');
ylabel('Distance (km)');
title([drive_cycle_name ' Distance vs Time']);
grid on;

%% Plot Power and Current
figure;
subplot(2,1,1);
plot(time, pack_power);
xlabel('Time (seconds)');
ylabel('Power (W)');
title([drive_cycle_name ' Pack Power vs Time']);
grid on;

subplot(2,1,2);
plot(time, current);
xlabel('Time (seconds)');
ylabel('Current (A)');
title([drive_cycle_name ' Cell Current vs Time']);
grid on;

%% Plot C-rate and Scaled Current
figure;
subplot(2,1,1);
plot(time, -C_rate);
xlabel('Time (seconds)');
ylabel('C-rate');
title([drive_cycle_name ' Cell C-rate vs Time']);
grid on;

subplot(2,1,2);
plot(time, scaled_current);
xlabel('Time (seconds)');
ylabel('Current (A)');
title([drive_cycle_name ' Scaled Cell Current vs Time']);
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


% %% Save Results to Excel
% output_table = table(time, scaled_current);
% 
% % 파일 저장 경로 설정 (지정한 경로)
% output_folder = 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\Processed';
% 
% if file_choice == 1
%     output_file_name = 'udds_unit_time_scaled_current.xlsx';
% elseif file_choice == 2
%     output_file_name = 'hwfet_unit_time_scaled_current.xlsx';
% else
%     output_file_name = 'us06_unit_time_scaled_current.xlsx'; % Save results for US06
% end
% 
% % 파일 전체 경로 (디렉토리 + 파일명)
% output_file_path = fullfile(output_folder, output_file_name);
% 
% % 테이블을 엑셀 파일로 저장
% writetable(output_table, output_file_path);
% fprintf('Excel file created successfully: %s\n', output_file_path);



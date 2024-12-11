clc; clear; close all;

%% 경로 설정
base_path = 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\RAW';

% Cycle 폴더 설정
cycle_folders = struct( ...
    'HW', fullfile(base_path), ...
    'CITY', fullfile(base_path));

% 파일 목록 출력 및 선택
disp('분석할 파일을 선택하세요:');
disp('1. BSL_HW1');
disp('2. BSL_HW2');
disp('3. BSL_CITY1');
disp('4. BSL_CITY2');
file_choice = input('분석할 파일의 번호를 입력하세요 (1, 2, 3, 4): ');

% 파일 선택에 따른 경로 설정
if file_choice == 1
    file_path = fullfile(cycle_folders.HW, '20190119_1903235.csv');
    disp('BSL_HW1을 선택하셨습니다.');
    drive_cycle_name = 'BSL HW1';
elseif file_choice == 2
    file_path = fullfile(cycle_folders.HW, '20190420_903436.csv'); % 파일명 예시
    disp('BSL_HW2를 선택하셨습니다.');
    drive_cycle_name = 'BSL HW2';
elseif file_choice == 3
    file_path = fullfile(cycle_folders.CITY, '20190101_240493.csv'); % 파일명 예시
    disp('BSL_CITY1을 선택하셨습니다.');
    drive_cycle_name = 'BSL CITY1';
elseif file_choice == 4
    file_path = fullfile(cycle_folders.CITY, '20190119_204688.csv'); % 파일명 예시
    disp('BSL_CITY2를 선택하셨습니다.');
    drive_cycle_name = 'BSL CITY2';
else
    error('잘못된 선택입니다. 1, 2, 3, 또는 4를 입력하세요.');
end

%% 데이터 로드 및 전처리
% CSV 파일 읽기
data_unit = readtable(file_path);

data_unit.Properties.VariableNames{1} = 'data_time';
data_unit.Properties.VariableNames{6} = 'speed';  % speed는 km/h 단위

% datetime을 사용하지 않고 문자열을 처리하여 시간 변환
% data_time 열이 셀 배열인지 확인 후 변환
if iscell(data_unit.data_time)
    data_time_str = data_unit.data_time; % 셀 배열
else
    data_time_str = cellstr(data_unit.data_time); % 문자열 배열을 셀 배열로 변환
end

% 첫 번째 시간 값을 datenum으로 변환
initial_time = datenum(data_time_str{1}, 'yyyy-mm-dd HH:MM:SS');

% 시간 데이터를 0초로 초기화하여 계산
time_seconds = zeros(size(data_time_str));
for i = 1:length(data_time_str)
    current_time = datenum(data_time_str{i}, 'yyyy-mm-dd HH:MM:SS');
    time_seconds(i) = (current_time - initial_time) * 24 * 3600;  % 초 단위로 변환
end

% 새로운 'time' 열을 테이블에 추가
data_unit.time = time_seconds;
time = data_unit.time;

% 속도를 m/s로 변환 (1 km/h = 0.27778 m/s)
data_unit.speed = data_unit.speed * 0.27778;
speed_ms = data_unit.speed;

%% 가속도 및 거리 계산
acceleration = zeros(size(speed_ms));

% 중앙 차분법을 사용한 가속도 계산
for i = 2:length(time)-1
    acceleration(i) = (speed_ms(i+1) - speed_ms(i-1)) / (time(i+1) - time(i-1));
end

% 첫 번째 및 마지막 점에 대한 가속도 계산 (전진/후진 차분법)
acceleration(1) = 0 ; %(speed_ms(2) - speed_ms(1)) / (time(2) - time(1));
acceleration(end) = (speed_ms(end) - speed_ms(end-1)) / (time(end) - time(end-1));

% 데이터에 가속도 추가
data_unit.acceleration = acceleration;

% 총 거리 계산
total_distance_km = sum((speed_ms(1:end-1) .* diff(time))) / 1000;
fprintf('총 주행 거리: %.2f km\n', total_distance_km);

%% Power 모델 적용
% Tesla Model 3 물리 상수
a = 28.990 * 4.44822; % lbf to Newton
b = 0.4592 * 4.44822 / 0.44704; % lbf/mph to N/(m/s)
c = 0.011100 * 4.44822 / 0.44704^2; % lbf/mph^2 to N/(m/s)^2
m_vehicle = 2154.564; % vehicle mass in [kg]
epsilon = 1.05;

% 배터리 팩 구성 및 셀 파라미터

m_series = 6; % 직렬 셀 수
n_parallel = 74; % 병렬 셀 수
OCV_cell = 3.6; % [V]
R_cell = 0.03; % 저항 [ohm]
nominal_capacity_Ah = 3.4; % [Ah]
Scaling_nominal_capacity_Ah = 55.6; % [Ah]
k = 16 ; % module 수 

m_series = 106; % 직렬 셀 수
n_parallel = 1; % 병렬 셀 수
OCV_cell = 3.2; % [V]
R_cell = 0.0009; % 저항 [ohm]
nominal_capacity_Ah = 161; % [Ah]
Scaling_nominal_capacity_Ah = 55.6; % [Ah] % NE_CELL = 55.6Ah

% 팩 파워 계산
pack_power = a * speed_ms + b * speed_ms.^2 + c * speed_ms.^3 + (1 + epsilon) * m_vehicle * speed_ms .* acceleration;
data_unit.pack_power = pack_power;

% 셀 파워로 변환
cell_power = pack_power / (m_series * n_parallel * k);
data_unit.cell_power = cell_power;

%% 전류 계산
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

%% C-rate 및 스케일링된 전류 계산
C_rate = current / nominal_capacity_Ah;
scaled_current = C_rate * Scaling_nominal_capacity_Ah;

% scaled_current에 음수 부호를 추가
scaled_current = -scaled_current;

data_unit.C_rate = C_rate;
data_unit.scaled_current = scaled_current;

% 누적 충전량(Q) 계산
Q = cumtrapz(time, abs(scaled_current)) / 3600; % 초를 시간으로 변환하여 Ah 단위로
data_unit.Q = Q;

% 총 충전량 및 사용량 계산
positive_current = current(current > 0);
positive_time = time(current > 0);

total_charge_As = trapz(positive_time, positive_current);
total_charge_Ah = total_charge_As / 3600;
total_used_Ah = trapz(time,scaled_current) / 3600; 
used_soc = (total_used_Ah/Scaling_nominal_capacity_Ah ) * 100;

fprintf('총 사용 용량: %.2f Ah\n', total_used_Ah);
fprintf('총 사용 SOC: %.2f %%\n', used_soc);

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

%% Plot C-rate and Scaled Current with Q
figure;
subplot(2,1,1);
plot(time, -C_rate);
xlabel('Time (seconds)');
ylabel('C-rate');
title([drive_cycle_name ' Cell C-rate vs Time']);
grid on;

subplot(2,1,2);
yyaxis left
plot(time, scaled_current, 'b');
xlabel('Time (seconds)');
ylabel('Scaled Current (A)');
title([drive_cycle_name ' Scaled Cell Current and Q vs Time']);
grid on;

yyaxis right
plot(time, Q, 'r');
ylabel('Cumulative Charge Q (Ah)');
legend('Scaled Current (A)', 'Q (Ah)');


%% 1028 figure 추가

% 색상 매트릭스 정의
c_mat = lines(2); % 첫 번째 색상: 파란색, 두 번째 색상: 빨간색

% Figure 4 생성
figure(4)
yyaxis left
plot(time, scaled_current, 'Color', c_mat(1,:), 'LineWidth', 1.5);
xlabel('Time (seconds)', 'FontSize', 12, 'Color', 'k'); 
ylabel('Current (A)', 'FontSize', 12, 'Color', c_mat(1,:)); 
title([drive_cycle_name 'Current and Q vs Time'], 'FontSize', 12, 'Color', 'k', 'FontWeight', 'bold'); 
grid on;

yyaxis right
plot(time, Q, 'Color', c_mat(2,:), 'LineWidth', 1.5);
ylabel('Cumulative Charge Q (Ah)', 'FontSize', 12, 'Color', c_mat(2,:)); 
legend('Current (A)', 'Q (Ah)', 'Location', 'best');




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


%% 결과를 엑셀로 저장
% output_table = table(time, scaled_current, Q);
% 
% % 파일 저장 경로 설정 (지정한 경로)
% output_folder = 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\Processed';
% 
% % 엑셀 파일명 설정
% if file_choice == 1
%     output_file_name = 'BSL_HW1_time_scaled_current_Q.xlsx';
% elseif file_choice == 2
%     output_file_name = 'BSL_HW2_time_scaled_current_Q.xlsx';
% elseif file_choice == 3
%     output_file_name = 'BSL_CITY1_time_scaled_current_Q.xlsx';
% else
%     output_file_name = 'BSL_CITY2_time_scaled_current_Q.xlsx';
% end
% 
% % 파일 전체 경로 (디렉토리 + 파일명)
% output_file_path = fullfile(output_folder, output_file_name);
% 
% % 테이블을 엑셀 파일로 저장
% writetable(output_table, output_file_path);
% fprintf('엑셀 파일이 성공적으로 생성되었습니다: %s\n', output_file_path);

output_table = table(time, scaled_current);

% 파일 저장 경로 설정 (지정한 경로)
output_folder = 'G:\공유 드라이브\Battery Software Lab\Driving cycle\55.6Ah_NE\Processed';

% 엑셀 파일명 설정
if file_choice == 1
    output_file_name = 'BSL_HW1_time_scaled_current.xlsx';
elseif file_choice == 2
    output_file_name = 'BSL_HW2_time_scaled_current.xlsx';
elseif file_choice == 3
    output_file_name = 'BSL_CITY1_time_scaled_current.xlsx';
else
    output_file_name = 'BSL_CITY2_time_scaled_current.xlsx';
end

% 파일 전체 경로 (디렉토리 + 파일명)
output_file_path = fullfile(output_folder, output_file_name);

% 테이블을 엑셀 파일로 저장
writetable(output_table, output_file_path);
fprintf('엑셀 파일이 성공적으로 생성되었습니다: %s\n', output_file_path);


2024.12.11 김준연 

LFP,NMC인지에 따라 변환

Driving cycle 종류에 따라 변환 

stand_driving1 : UDDS, US06, HWFET 
stand_driving2 : WLTC 

BSL_driving : BSL_city1, BSL_city2, BSL_HW1, BSL_HW2 존재

% Raw data는 EPA 공식 홈페이지에서 다운 받음 
% a,b,c는 차량 고유의 coeff 의 값으로 LFP, NMC 차량에 따라 임의 선택하였음  ( G: 구글 드라이브 : Protocol : testcar 엑셀파일 참조, Target coeff 참조)
% 차량의 배터리 pack configuration 정보를 알고 있어야함 
% LFP OR NMC single parameter (OCV, 내부 저항 , nominal capacity ) 알고 있어야함 
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

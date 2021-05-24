figset('-init', [1,1]);
clear; % close all
% % setDefaultFigureStyle([2,2], 1);
%% file and constant
dataset_path = 'F:/loctag/aoa/data/200817/';
descFile = fullfile(dataset_path, 'settings.json');
coordinatesFile = fullfile(dataset_path, 'coordinates.xlsx');
calFile = fullfile(dataset_path, 'cal.json');

c0 = 3e8;
Da = 0.026;
scIndex = [-28,-26,-24,-22,-20,-18,-16,-14,-12,-10,-8,-6,-4,-2,-1,1,3,5,7,9,11,13,15,17,19,21,23,25,27,28];
scIndexHT40 = [-58,-54,-50,-46,-42,-38,-34,-30,-26,-22,-18,-14,-10,-6, -2,2,6,10,14,18,22,26,30,34,38,42,46,50,54];
%% read settings and data
desc = jsondecode(fileread(descFile));
[T, hs, rssis] = convertCsiFileToMat(coordinatesFile, 1, desc.rx_ant_perm, hex2dec('01'));
refAoa = atan2d(T.tx_y-T.y, T.tx_x-T.x);
%% geo
calPtIdxs = find(abs(refAoa-90)<1e-6 | abs(refAoa+90)<1e-6);
%% read the calibration file, if file does not exist, build it.
if exist(calFile,'file')
    pathDelay = jsondecode(fileread(calFile));
    fprintf('1\n')
else    
    calPtIdx = calPtIdxs(1);
    h = hs{calPtIdx};
    % path delay calibration
    h_p = angle(h);
    h_up = unwrap(h_p, [], 2);
%     plot(scIndex, h_up);
    p_diff = mean(h_up, 2);
    [h_fup, p] = polyfitval(scIndex, h_up, 1);
    p_diff_2 = mean(h_fup, 2);
    p_diff = mod(p_diff-21*pi, 2*pi)-pi;
    pathDelay = p_diff/(2*pi)*c0/desc.rx_freq;  % unit: m
    filewrite(calFile, jsonencode(pathDelay));
    fprintf('2\n')
end
% 计算相位补偿值
cc = exp(-1j*2*pi*desc.rx_freq/c0.*pathDelay);

%% 遍历
Aoa = nan(length(refAoa),1);
for k = 1:length(refAoa)
    h = hs{k};
    % 补偿
    h(1,:) = h(1,:).*cc(1);
    h(2,:) = h(2,:).*cc(2);
    h(3,:) = h(3,:).*cc(3);
    % 通过线性拟合对unwrapped phase进行平滑
    h_p = angle(h);
    h_up = unwrap(h_p, [], 2);
    [h_fup, p] = polyfitval(scIndex, h_up, 1); %平滑
%      h = h.*exp(1j.*(h_fup-h_up)); %使用平滑后的相位值
%     figure
%     plot(scIndex, h_up);
%     ylabel('Phase (rad)')
%     xlabel('Subcarrier index')
%     hold; grid on
%     plot(scIndex, unwrap(angle(h),[],2), '--');
    %% MUSIC algorithm start
    X = h(:,10:15);   % 准备X 
    Rxx = X*X'/2;   % 计算协方差
    
    [E, D] = eig(Rxx);  % 计算特征值和特征向量
    [d,idx] = sort(diag(D), 'descend'); % 降序排列特征值和特征向量
    D = D(:, idx); %Vector of sorted eigenvalues
    E = E(:, idx); %Sort eigenvectors accordingly
    En = E(:, 2:length(E)); %Noise eigenvectors (ASSUMPTION: M IS KNOWN)
    
    AzSearch = 0:180; %Azimuth values to search
    KSearch = [2 1 0]'*(cos(deg2rad(AzSearch))*Da*desc.rx_freq/c0);
    ASearch = exp(-1j*2*pi.*KSearch);
    % 执行搜索
    P = zeros(size(KSearch,2),1);
    for m = 1:size(ASearch, 2)
        a = ASearch(:,m);
        %     print(a)
        P(m) = norm(En'*a);
    end
    % 得到Pmusic谱密度
    P = 1.0./P;
    %% MUSIC algorithm end
    % 找出峰值/最大值点
    % [pks, Aoa] = findpeaks(P, AzSearch);
    % [pks,idx] = sort(pks);
    % Aoa = Aoa(idx);
    [v, pks] = max(P);
    Aoa(k) = AzSearch(pks);
    
    % 绘图并标记峰值点
%     figure;
%     plot(AzSearch, P); grid on
%     ylabel('Pmusic')
%     xlabel('AoA (deg)')
%     text(Aoa(k)+2, v(1), ['\leftarrow' sprintf('AoA=%.0f (refVal=%.0f)', Aoa(k), refAoa(k))]);
%     title(sprintf('cdn:(%.1f,%.1f) AoA: %.0f rssi: %.1f', T.x(k),T.y(k), refAoa(k), rssis(k)));
end
% refAoa = [153	135	180	135	117	90	90	0	45];
% Aoa = [51	70	77	159	77	90	92	87	0];

[refAoa_ordered,idx] = sort(refAoa);

figure;
plot(refAoa(idx), '--+');
hold on
plot(Aoa(idx), '-+');
grid on;
ylabel('Angle (deg)')
xlabel('Sample')
legend('reference', 'estimated value');


% 从数据集生成指纹
close all;
clear;
load('file_list.mat');
dataset_path = 'dataset/dataset0327/trainset/';

c0 = 3e8;
Da = 0.04;
desc.rx_freq = 2462e6;
% pkt_count_valid = zeros(max(file_no_list), 4); % (tag1, tag2, tag3, tx)
% pkt_count_total = zeros(max(file_no_list), 4); % (tx11b, tx11n, tag11b, tag11n)

% 初始化一个空特征结构体
null_feat.txMac = '00:00:00:00:00:00';
null_feat.id = 0;
null_feat.rss = -100;
null_feat.ant_rss = [-100 -100 -100];
null_feat.tag_rss = double(-100);
null_feat.csi = [];

% %% 相位补偿
% refAoa = atan2d(T.tx_y-T.y, T.tx_x-T.x);
% %% geo
% calPtIdxs = find(abs(refAoa-90)<1e-6 | abs(refAoa+90)<1e-6);
% %% read the calibration file, if file does not exist, build it.
% if exist(calFile,'file')
%     pathDelay = jsondecode(fileread(calFile));
%     fprintf('1\n')
% else
%     calPtIdx = calPtIdxs(1);
%     h = hs{calPtIdx};
%     % path delay calibration
%     h_p = angle(h);
%     h_up = unwrap(h_p, [], 2);
% %     plot(scIndex, h_up);
%     p_diff = mean(h_up, 2);
%     [h_fup, p] = polyfitval(scIndex, h_up, 1);
%     p_diff_2 = mean(h_fup, 2);
%     p_diff = mod(p_diff-21*pi, 2*pi)-pi;
%     pathDelay = p_diff/(2*pi)*c0/desc.rx_freq;  % unit: m
%     filewrite(calFile, jsonencode(pathDelay));
%     fprintf('2\n')
% end
% % 计算相位补偿值
% cc = exp(-1j*2*pi*desc.rx_freq/c0.*pathDelay);
% 
% %% 遍历
% Aoa = nan(length(refAoa),1);




%% 训练点
train_feat = cell(2,1); %max(file_no_list)
for m=4 %max(file_no_list)
    file_path_prefix = sprintf('%s%03d', dataset_path, m);
    if ~isfile(strcat(file_path_prefix,'z'))
%         train_feat(m,4) = null_feat;
%         train_feat(m,3) = null_feat;
%         train_feat(m,2) = null_feat;
        train_feat{m}{1} = null_feat;
        continue
    end
    %% 读取Tx包（非反射）
    pkt_trace = loctag_read_log_file(strcat(file_path_prefix,'z'));
    pkt_count_bn = length(pkt_trace);
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
    pkt_count_b = sum(rate_vector==0x1b);    
    pkt_count_n = sum(rate_vector==0x80);
%     pkt_trace_n = pkt_trace(rate_vector==0x80);
    fprintf('%d: AllNoErr(%d): b(%d)/n(%d)\n', m,pkt_count_bn, pkt_count_b, pkt_count_n);
    % 读取11b&11n包
    % pkt_trace = pkt_trace(rate_vector==0x1b);    
    train_feat{m} = cell(1,pkt_count_bn); %max(file_no_list)
    for pkt_index = 1:pkt_count_bn
        train_feat{m}{pkt_index}.timestamp = pkt_trace{pkt_index}.timestamp/1e6;
        train_feat{m}{pkt_index}.txMac = pkt_trace{pkt_index}.txMac;
        train_feat{m}{pkt_index}.id = pkt_trace{pkt_index}.id;
        train_feat{m}{pkt_index}.rate = pkt_trace{pkt_index}.rate;
        train_feat{m}{pkt_index}.rss = pkt_trace{pkt_index}.rss;
        train_feat{m}{pkt_index}.ant_rss = pkt_trace{pkt_index}.ant_rss;
        train_feat{m}{pkt_index}.tag_rss = pkt_trace{pkt_index}.tag_rss;
        train_feat{m}{pkt_index}.csi = pkt_trace{pkt_index}.csi;
    end
    
    timestamp_v = cellfun(@(x) double(x.timestamp), train_feat{m}, 'UniformOutput', true);
    id_v = cellfun(@(x) double(x.id), train_feat{m}, 'UniformOutput', true);
    n_v = cellfun(@(x) double(x.rate==0x80), train_feat{m}, 'UniformOutput', true);
    rss_v = cellfun(@(x) double(x.rss), train_feat{m}, 'UniformOutput', true);
%     figure
%     scatter(timestamp_v, n_v);
%     figure
%     scatter(timestamp_v, id_v);
%     figure
%     scatter(timestamp_v, rss_v);
%     figure
    figure; hold on;
    pkt_n_indexs = find(rate_vector==0x80);
    colororder([0    0.4470    0.7410;    0.8500    0.3250    0.0980]);
    for kk = 1:length(pkt_n_indexs)
        h = squeeze(train_feat{m}{pkt_n_indexs(kk)}.csi(:,1,:));
        sc_idx = [-28:-1, 1:28];
    %     csi_abs = db(abs(csi));
        csi_phase = angle(h);
        csi_phase_diff = [csi_phase(2,:)-csi_phase(1,:); csi_phase(3,:)-csi_phase(1,:)];
        csi_phase_diff(:,1) = wrapTo2Pi(csi_phase_diff(:,1));
        csi_phase_diff = unwrap(csi_phase_diff, [], 2);
        csi_phase_diff_mean = mean(csi_phase_diff, 2);
    %     csi_eff = mean(csi_abs, 'all');
    % %     csi_phase_diff = [csi_phase(2,:)-csi_phase(1,:); csi_phase(3,:)-csi_phase(1,:)];
        plot(kk, csi_phase_diff_mean(1), '+');
        plot(kk, csi_phase_diff_mean(2), '+');
    %     ylim([-10 20])


    % 通过线性拟合对unwrapped phase进行平滑
        h_p = angle(h);
        h_up = unwrap(h_p, [], 2);
        [h_fup, p] = polyfitval(sc_idx, h_up, 1); %平滑
         h = h.*exp(1j.*(h_fup-h_up)); %使用平滑后的相位值
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
        for mmm = 1:size(ASearch, 2)
            a = ASearch(:,mmm);
            %     print(a)
            P(mmm) = norm(En'*a);
        end
        % 得到Pmusic谱密度
        P = 1.0./P;
        %% MUSIC algorithm end
        % 找出峰值/最大值点
        % [pks, Aoa] = findpeaks(P, AzSearch);
        % [pks,idx] = sort(pks);
        % Aoa = Aoa(idx);
        [v, pks] = max(P);
%         Aoa(kk) = AzSearch(pks);
        % 绘图并标记峰值点
    %     figure;
%         plot(AzSearch, P); %grid on
    %     ylabel('Pmusic')
    %     xlabel('AoA (deg)')
    %     text(Aoa(k)+2, v(1), ['\leftarrow' sprintf('AoA=%.0f (refVal=%.0f)', Aoa(k), refAoa(k))]);
    %     title(sprintf('cdn:(%.1f,%.1f) AoA: %.0f rssi: %.1f', T.x(k),T.y(k), refAoa(k), rssis(k)));
    %     plot(sc_idx, csi_phase);
    %     ylim([-2*pi, 2*pi]);
    end
%     plot(1:length(pkt_n_indexs), Aoa, '+');
end

% save('loctag_rss_loc_dataset.mat', 'coordinates', 'file_no_list', 'pkt_count_total', 'pkt_count_valid', 'train_feat', 'test_feat');

% rss_vector = cellfun(@(x) x.rss,pkt_trace);
% tag_rss_vector = cellfun(@(x) x.tag_rss,pkt_trace);
% id_count = histogram(id_vector, unique(id_vector)); %
% figure
% rss_count = histogram(rss_vector, unique(rss_vector)); %
% tag_rss_vector = histogram(tag_rss_vector, unique(tag_rss_vector)); %

% id_vector = cellfun(@(x) x.id,pkt_trace);
% sample_idx = 16;
% csi_entity = pkt_trace{sample_idx};


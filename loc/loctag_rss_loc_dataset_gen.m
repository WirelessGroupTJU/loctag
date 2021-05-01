% 从数据集生成指纹

clear;
load('file_list.mat');
dataset_path = 'f:/dataset0327/';

pkt_count_valid = zeros(max(file_no_list), 4); % (tag1, tag2, tag3, tx)
pkt_count_total = zeros(max(file_no_list), 4); % (tx11b, tx11n, tag11b, tag11n)

% 初始化一个空特征结构体
null_feat.txMac = '00:00:00:00:00:00';
null_feat.id = 0;
null_feat.rss = -100;
null_feat.ant_rss = [-100 -100 -100];
null_feat.tag_rss = double(-100);
null_feat.csi = [];

%% 训练点
for m=1:max(file_no_list)
    file_path_prefix = sprintf('%s%03d', dataset_path, m);
    if ~isfile(strcat(file_path_prefix,'a'))
        train_feat(m,4) = null_feat;
        train_feat(m,3) = null_feat;
        train_feat(m,2) = null_feat;
        train_feat(m,1) = null_feat;
        continue
    end
    %% 读取Tx包（非反射）
    pkt_trace = loctag_read_log_file(strcat(file_path_prefix,'a'));
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
    pkt_count_total(m, 1) = sum(rate_vector==0x1b);
    pkt_count_total(m, 2) = sum(rate_vector==0x80);
    % 读取11b包
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    pkt_count_valid(m, 4) = length(pkt_trace_b);
    pkt_record_b = pkt_trace_b{1};

    % fea(m,4).timestamp = pkt_record_b.timestamp;
    train_feat(m,4).txMac = pkt_record_b.txMac;
    train_feat(m,4).id = pkt_record_b.id;
    train_feat(m,4).rss = pkt_record_b.rss;
    train_feat(m,4).ant_rss = pkt_record_b.ant_rss;
    train_feat(m,4).tag_rss = pkt_record_b.tag_rss;
    train_feat(m,4).csi = pkt_record_b.csi;

    % 读取11b包
    % pkt_trace_n = pkt_trace(rate_vector==0x80);
    %% 读取Tag包（反射）
    pkt_trace = loctag_read_log_file(strcat(file_path_prefix,'z'));
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
    pkt_count_total(m, 3) = sum(rate_vector==0x1b);
    pkt_count_total(m, 4) = sum(rate_vector==0x80);
    % 读取11b包
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    id_vector = cellfun(@(x) x.id,pkt_trace);

    for n=1:3
        pkt_trace_b = pkt_trace(id_vector==n);
        pkt_count_valid(m, n) = length(pkt_trace_b);
        if length(pkt_trace_b)>=1
            pkt_record_b = pkt_trace_b{1}; %%
    %       fea(m,n).timestamp = pkt_record_b.timestamp;
            train_feat(m,n).txMac = pkt_record_b.txMac;
            train_feat(m,n).id = pkt_record_b.id;
            train_feat(m,n).rss = pkt_record_b.rss;
            train_feat(m,n).ant_rss = pkt_record_b.ant_rss;
            train_feat(m,n).tag_rss = pkt_record_b.tag_rss;
            train_feat(m,n).csi = pkt_record_b.csi;
        else
    %       fea(m,n).timestamp = pkt_record_b.timestamp;
            train_feat(m,n) = null_feat;
            train_feat(m,n).txMac = pkt_record_b.txMac;
            train_feat(m,n).id = n;
        end
    end
end

%% 测试点
for m=1:max(file_no_list)
    file_path_prefix = sprintf('%s%03d', dataset_path, m);
    if ~isfile(strcat(file_path_prefix,'a'))
        test_feat(m,4) = null_feat;
        test_feat(m,3) = null_feat;
        test_feat(m,2) = null_feat;
        test_feat(m,1) = null_feat;
        continue
    end
    %% 读取Tx包（非反射）
    pkt_trace = loctag_read_log_file(strcat(file_path_prefix,'a'));
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
    pkt_count_total(m, 1) = sum(rate_vector==0x1b);
    pkt_count_total(m, 2) = sum(rate_vector==0x80);
    % 读取11b包
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    pkt_count_valid(m, 4) = length(pkt_trace_b);
    pkt_record_b = pkt_trace_b{end}; %%

    % fea(m,4).timestamp = pkt_record_b.timestamp;
    test_feat(m,4).txMac = pkt_record_b.txMac;
    test_feat(m,4).id = pkt_record_b.id;
    test_feat(m,4).rss = pkt_record_b.rss;
    test_feat(m,4).ant_rss = pkt_record_b.ant_rss;
    test_feat(m,4).tag_rss = pkt_record_b.tag_rss;
    test_feat(m,4).csi = pkt_record_b.csi;

    % 读取11b包
    % pkt_trace_n = pkt_trace(rate_vector==0x80);
   %% 读取Tag包（反射）
    pkt_trace = loctag_read_log_file(strcat(file_path_prefix,'z'));
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
    pkt_count_total(m, 3) = sum(rate_vector==0x1b);
    pkt_count_total(m, 4) = sum(rate_vector==0x80);
    % 读取11b包
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    id_vector = cellfun(@(x) x.id,pkt_trace);

    for n=1:3
        pkt_trace_b = pkt_trace(id_vector==n);
        pkt_count_valid(m, n) = length(pkt_trace_b);
        if length(pkt_trace_b)>=1
            pkt_record_b = pkt_trace_b{end};
    %       fea(m,n).timestamp = pkt_record_b.timestamp;
            test_feat(m,n).txMac = pkt_record_b.txMac;
            test_feat(m,n).id = pkt_record_b.id;
            test_feat(m,n).rss = pkt_record_b.rss;
            test_feat(m,n).ant_rss = pkt_record_b.ant_rss;
            test_feat(m,n).tag_rss = pkt_record_b.tag_rss;
            test_feat(m,n).csi = pkt_record_b.csi;
        else
    %       fea(m,n).timestamp = pkt_record_b.timestamp;
            test_feat(m,n).txMac = pkt_record_b.txMac;
            test_feat(m,n).id = n;
            test_feat(m,n).rss = -100;
            test_feat(m,n).ant_rss = [-100 -100 -100];
            test_feat(m,n).tag_rss = double(-100);
            test_feat(m,n).csi = [];
        end
    end
end

save('loctag_rss_loc_dataset.mat', 'coordinates', 'file_no_list', 'pkt_count_total', 'pkt_count_valid', 'train_feat', 'test_feat');

% rss_vector = cellfun(@(x) x.rss,pkt_trace);
% tag_rss_vector = cellfun(@(x) x.tag_rss,pkt_trace);
% id_count = histogram(id_vector, unique(id_vector)); %
% figure
% rss_count = histogram(rss_vector, unique(rss_vector)); %
% tag_rss_vector = histogram(tag_rss_vector, unique(tag_rss_vector)); %

% id_vector = cellfun(@(x) x.id,pkt_trace);
% sample_idx = 16;
% csi_entity = pkt_trace{sample_idx};
% csi = squeeze(csi_entity.csi(:,1,:));
% sc_idx = [-28:-1, 1:28];
% csi_abs = db(abs(csi));
% csi_phase = unwrap(angle(csi));
% plot(sc_idx, csi_abs);
% ylim([0 60])
% figure
% plot(sc_idx, csi_phase);
% ylim([-2*pi, 2*pi]);

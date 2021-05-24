
function loctag_rss_loc_dataset_gen(dataset_path)
% 训练集点与测试集点的文件名与坐标需要完全对应
% descFile = fullfile(dataset_path, 'settings.json');
% desc = jsondecode(fileread(descFile));
coordFile = fullfile(dataset_path, 'coordinates.xlsx');
T = readtable(coordFile, 'ReadVariableNames',true);
% filter
T = T(T.flag==0, :); % flag 0:正常采样点; 1-3: Tag所在点
file_no_str = T.file_no;
file_no = cellfun(@str2num, file_no_str);
coord = [T.x T.y];
% 获得路径
[path, ~, ~] = fileparts(coordFile);

%% 训练集
train_file_no = fullfile(path, 'trainset', file_no_str);
train_pkt_count = zeros(length(train_file_no), 4);  % (tag1, tag2, tag3, tx)
train_feat = zeros(length(train_file_no), 4); % (tag1, tag2, tag3, tx)
for m=1:length(train_file_no)
    %% 读取AP包（AP直接信号RSS）
    pkt_trace = loctag_read_log_file(strcat(train_file_no{m},'a'));
    rate_vector = cellfun(@(x) x.rate, pkt_trace);
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    % 计数
    train_pkt_count(m,4) = sum(rate_vector==0x1b);
    % 读取RSSI作为特征
    train_feat(m,4) = mean(cellfun(@(x) double(x.rss), pkt_trace_b));
    %% 读取Tag包（反射）
    pkt_trace = loctag_read_log_file(strcat(train_file_no{m},'z'));
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    % 读取每个Tag的RSS
    id_vector = cellfun(@(x) x.id, pkt_trace_b);
    for n=1:3
        train_pkt_count(m, n) = sum(id_vector==n);
        if train_pkt_count(m, n)>=1
            pkt_trace_b_tmp = pkt_trace_b(id_vector==n);
            train_feat(m,n) = mean(cellfun(@(x) double(x.rss), pkt_trace_b_tmp));
        else
            train_feat(m,n) = -100;
        end
    end
end

%% 测试集
test_file_no = fullfile(path, 'testset', file_no_str);
test_pkt_count = zeros(length(test_file_no), 4);
test_feat = zeros(length(test_file_no), 4);
prop = 0.12;
for m=1:length(test_file_no)
    %% 读取AP包（AP直接信号RSS）
    pkt_trace = loctag_read_log_file(strcat(test_file_no{m},'a'));
    rate_vector = cellfun(@(x) x.rate, pkt_trace);
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    % 计数
    test_pkt_count(m,4) = sum(rate_vector==0x1b);
    % 读取RSSI作为特征
    sample_index = gen_sample_index(test_pkt_count(m,4), prop);
    test_feat(m,4) = mean(cellfun(@(x) double(x.rss), pkt_trace_b(sample_index)));

    %% 读取Tag包（反射）
    pkt_trace = loctag_read_log_file(strcat(test_file_no{m},'z'));
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
    pkt_trace_b = pkt_trace(rate_vector==0x1b);
    % 读取每个Tag的RSS
    id_vector = cellfun(@(x) x.id, pkt_trace_b);
    for n=1:3
        test_pkt_count(m, n) = sum(id_vector==n);
        if test_pkt_count(m, n)>=1
            pkt_trace_b_tmp = pkt_trace_b(id_vector==n);
            sample_index = gen_sample_index(test_pkt_count(m,n), prop);
            test_feat(m,n) = mean(cellfun(@(x) double(x.rss), pkt_trace_b_tmp(sample_index)));
        else
            test_feat(m,n) = -100;
        end
    end
end
mkdir('results');
save('results/loctag_rss_loc_dataset.mat', 'file_no', 'coord', 'train_pkt_count', 'test_pkt_count', 'train_feat', 'test_feat');
end

function index = gen_sample_index(n, prop)
    x = ceil(n*prop);
    if x==0
        index = 1;
    else
        index = 1:x;
    end
end
clear; close all;
dataset_path = 'dataset/dataset0327/';
loctag_csi_loc_dataset_gen_(dataset_path);
function loctag_csi_loc_dataset_gen_(dataset_path)
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
train_pkt_count_csi = zeros(length(train_file_no), 2);  % (tag1, tag2, tag3, tx)
train_feat_csi = zeros(length(train_file_no), 4); % (tag1, tag2, tag3, tx)
for m= 1:length(train_file_no)
    %% 读取AP包（AP直接信号RSS）
%     figure; hold on;
    pkt_trace = loctag_read_log_file(strcat(train_file_no{m},'a'));
    train_feat_csi(m, 3:4) = loctag_csi_to_feat(pkt_trace, T.ant_dir(m), 0, 1);
    
    pkt_trace = loctag_read_log_file(strcat(train_file_no{m},'z'));
    train_feat_csi(m, 1:2) = loctag_csi_to_feat(pkt_trace, T.ant_dir(m), 1, 1);
%     print('-dpng','-r150', sprintf('results/z-%02d',m));
end
fprintf('end\n');
%% 测试集
test_file_no = fullfile(path, 'testset', file_no_str);
test_pkt_count_csi = zeros(length(test_file_no), 4);
test_feat_csi = zeros(length(test_file_no), 4);
prop = 0.2;
for m=1:length(test_file_no)
    %% 读取AP包（AP直接信号RSS）
    pkt_trace = loctag_read_log_file(strcat(test_file_no{m},'a'));
    test_feat_csi(m, 3:4) = loctag_csi_to_feat(pkt_trace, T.ant_dir(m), 0, prop);
    
    pkt_trace = loctag_read_log_file(strcat(train_file_no{m},'z'));
    test_feat_csi(m, 1:2) = loctag_csi_to_feat(pkt_trace, T.ant_dir(m), 1, prop);
    
end
mkdir('results');
save('results/loctag_csi_loc_dataset.mat', 'file_no', 'coord', 'train_pkt_count_csi', 'test_pkt_count_csi', 'train_feat_csi', 'test_feat_csi');
end

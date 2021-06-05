clear; close all;
figset('-init',[1,1]);
%% 读取或加载数据集、设置初始变量、常量
dataset_path = 'dataset/dataset0327/';
%load: 'file_no', 'coord', 'pkt_count', 'train_feat', 'test_feat'
if ~exist('results/loctag_rss_loc_dataset-0.12.mat', 'file')
    loctag_rss_loc_dataset_gen(dataset_path);
end
load('results/loctag_rss_loc_dataset-0.12.mat');

descFile = fullfile(dataset_path, 'settings.json');
desc = jsondecode(fileread(descFile));
tag_coord = [0.4,0.4; 0.4,-0.4; -0.4,-0.4]; % 标签1/2/3，对应文件名前缀：53/45/44

%% KNN定位
warning off
dbstop if error

%% 读取特征
trainset_label = 1:length(file_no);
% trainset_label = intersect(trainset_label, file_no_list); % 剔除不存在的的采样点
testset_label = 1:length(file_no);
% testset_label = intersect(testset_label, file_no_list); % 剔除不存在的的采样点
% 提取训练集RSS作为训练集特征
train_feat_mat = train_feat;%arrayfun(@(x) double(x.rss), train_feat, 'UniformOutput', true);
test_feat_mat = test_feat;%arrayfun(@(x) double(x.rss),test_feat, 'UniformOutput', true);
diff_feat_mat = test_feat_mat - train_feat_mat;

%% 不使用标签时的定位精度
ap_mask = [4];

mdl0 = fitcknn(train_feat_mat(trainset_label, ap_mask), trainset_label, 'NumNeighbors',1, 'Distance','euclidean');
[label0,score0,cost0] = predict(mdl0, test_feat_mat(testset_label, ap_mask));
error_vec0 = vecnorm(coord(label0,:)-coord(testset_label,:),2,2);

%% 使用标签时的定位精度
% tag_mask = [1 2 3 4];
tag_masks =  {{ [1 4], [2 4], [3 4]}, ...
                {[1 2 4], [1 3 4] [2 3 4]}, ...
                {[1 2 3 4]}};
lenged_texts = {{'AP', 'AP+LocTag\{1\}', 'AP+LocTag\{2\}', 'AP+LocTag\{3\}'},...
                {'AP', 'AP+LocTag\{1,2\}', 'AP+LocTag\{1,3\}', 'AP+LocTag\{2,3\}'},...
                {'AP', 'AP+LocTag\{1,2,3\}'}};

mean_error = zeros(3,1);
mean_error_down_percent = zeros(3,1);

for tag_num=1:3
    figure; hold on;
    hh = cdfplot(error_vec0); % 不使用标签时的CDF
    set(hh, 'LineStyle', '-', 'Color', 'k', 'LineWidth', 1);

    linestylelist = {'--', ':', '-.'};
    colorlist = 'rmb';
    error_vec = cell(length(tag_masks{tag_num}),1);
    for mm=1:length(tag_masks{tag_num})
        tag_mask = tag_masks{tag_num}{mm};
        % 训练及预测
        mdl2 = fitcknn(train_feat_mat(trainset_label,tag_mask), trainset_label, 'NumNeighbors',1,'Distance','euclidean');
        [label2,score2,cost2] = predict(mdl2, test_feat_mat(testset_label, tag_mask));
        error_vec{mm} = vecnorm(coord(label2,:)-coord(testset_label,:),2,2);
        
        fprintf(['[' repmat('%d ', 1, numel(ap_mask)) '] = %f, [' repmat('%d ', 1, numel(tag_mask)) '] = %f, FP=%d  ['],ap_mask, mean(error_vec0), tag_mask, mean(error_vec{mm}), length(trainset_label));
        % fprintf('%g ', train_set);
        fprintf(']\n');

        hh = cdfplot(error_vec{mm}); 
%         set(hh, 'LineStyle', linestylelist{mm}, 'Color', colorlist(mm));
    end
    mean_error0 = mean(error_vec0);
    mean_error(tag_num) = mean(cellfun(@mean, error_vec));
    mean_error_down_percent(tag_num) = (mean_error(tag_num)-mean_error0).*100./mean_error0;
    fprintf('NoTag = %f, %d Tag = %f, down = %.2f%%\n',mean(error_vec0), tag_num, mean_error(tag_num), mean_error_down_percent(tag_num));

    figset('-t-xl-yl','','Distance error (m)','CDF', ... 
        '-xt-yt-ym',0:10, 0:0.1:1, [0,1] ...
        );
    box on
    legend(lenged_texts{tag_num}, 'Location', 'southeast');
    print('-dpng','-r150', sprintf('results/ch5ErrCdf-%d',tag_num));

end


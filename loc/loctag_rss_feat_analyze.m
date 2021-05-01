clear; close all;
figset('-init',[1,1]);
%load: 'coordinates', 'file_no_list', 'pkt_count_total', 'pkt_count_valid', 'train_feat', 'test_feat'
load('loctag_rss_loc_dataset.mat'); 
tag_coordinates = [0.4,0.4; 0.4,-0.4; -0.4,-0.4]; % 标签1/2/3，对应文件名前缀：53/45/44
%% 数据分析
plot(coordinates(:,1), coordinates(:,2), '+'); hold on
plot(tag_coordinates(:,1), tag_coordinates(:,2), 's');
plot(0, 0, '^');

pts = coordinates(pkt_count_valid(:,3)~=0, :); %sum(pkt_count_valid(:,1:3), 2);
plot(pts(:,1), pts(:,2), 'o');

%% KNN定位
warning off
dbstop if error

%% 读取特征
train_set = file_no_list;
train_set = intersect(train_set, file_no_list); % 剔除不存在的的采样点
test_set = file_no_list;
test_set = intersect(test_set, file_no_list); % 剔除不存在的的采样点
% 提取训练集RSS作为训练集特征
train_feat_mat = arrayfun(@(x) double(x.rss), train_feat, 'UniformOutput', true);
test_feat_mat = arrayfun(@(x) double(x.rss),test_feat, 'UniformOutput', true);
diff_feat_mat = test_feat_mat - train_feat_mat;
%% 读取特征矩阵
% 正则化 %% 删掉效果更好
% min_feat = min(train_feat_mat);
% max_feat = max(train_feat_mat);
% for m=1:4
%     train_feat_mat(:,m) = (train_feat_mat(:,m)-min_feat(m))./(max_feat(m)-min_feat(m));
%     test_feat_mat(:,m) = (test_feat_mat(:,m)-min_feat(m))./(max_feat(m)-min_feat(m));
% end


%% 不使用标签时的定位精度
ap_mask = [4];

mdl1 = fitcknn(train_feat_mat(train_set,ap_mask), train_set, 'NumNeighbors',1, 'Distance','euclidean');
[label1,score1,cost1] = predict(mdl1, test_feat_mat(test_set, ap_mask));
error_vec1 = vecnorm(coordinates(label1,:)-coordinates(test_set,:),2,2);

%% 使用标签时的定位精度
tag_mask = [1 2 3 4];
tag_masks =  { [1 2 3 4]}; %,,};[1 4], [2 4], [3 4][1 2 4], [1 3 4] [2 3 4]

figure; hold on;
hh = cdfplot(error_vec1);
set(hh, 'LineStyle', '--', 'Color', 'k');
% set(h, 'Marker', '+');


% title('');
% xlabel('Distance error (m)');
% ylabel('CDF');

colorlist = 'rmb';

for mm=1:length(tag_masks)
    tag_mask = tag_masks{mm};

    mdl2 = fitcknn(train_feat_mat(train_set,tag_mask), train_set, 'NumNeighbors',1,'Distance','euclidean');
    [label2,score2,cost2] = predict(mdl2, test_feat_mat(test_set, tag_mask));
    error_vec{mm} = vecnorm(coordinates(label2,:)-coordinates(test_set,:),2,2);

    fprintf(['[' repmat('%d ', 1, numel(ap_mask)) '] = %f, [' repmat('%d ', 1, numel(tag_mask)) '] = %f, FP=%d  ['],ap_mask, mean(error_vec1), tag_mask, mean(error_vec{mm}), length(train_set));
    % fprintf('%g ', train_set);
    fprintf(']\n');

    hh = cdfplot(error_vec{mm}); 
    set(hh, 'LineStyle', '-', 'Color', colorlist(mm));
end

figset('-t-xl-yl','','Distance error (m)','CDF', ... 
    '-xt-yt-ym',0:10, 0:0.1:1, [0,1] ...
    );
box on
legend({'AP', 'AP+LocTag\{1,2,3\}', 'AP+LocTag\{1,3\}', 'AP+LocTag\{2,3\}'}, 'Location', 'southeast');
% print('-dpng','-r150', sprintf('ch5APNum3'));


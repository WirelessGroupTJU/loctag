clear; close all;
figset('-init',[1,1]);
%% 读取或加载数据集、设置初始变量、常量
dataset_path = 'dataset/dataset0327/';
%load: 'file_no', 'coord', 'pkt_count', 'train_feat', 'test_feat'
if ~exist('results/loctag_rss_loc_dataset-0.12crc.mat', 'file')
    loctag_rss_loc_dataset_gen(dataset_path);
end
load('results/loctag_rss_loc_dataset-0.12crc.mat');

descFile = fullfile(dataset_path, 'settings.json');
desc = jsondecode(fileread(descFile));
tag_coord = [0.4,0.4; 0.4,-0.4; -0.4,-0.4]; % 标签1/2/3，对应文件名前缀：53/45/44
%% 数据分析
tags = 1:3;
%% 覆盖范围分析
m=4;
tags_comp = tags;
figure; hold on; box on;
plot(0, 0, '^r', 'MarkerSize', 10,'MarkerFaceColor','r');
plot(coord(:,1), coord(:,2), '.k', 'MarkerSize', 1); % 绘制采样点
% plot(tag_coord(m,1), tag_coord(m,2), 'sm', 'MarkerSize', 10,'MarkerFaceColor','m');  % 绘制当前标签
plot(tag_coord(tags_comp,1), tag_coord(tags_comp,2), 'xk', 'MarkerSize', 10); % 绘制其它标签
% plot(tag_coord(tags_comp,1), tag_coord(tags_comp,2), 'sk', 'MarkerSize', 10); % 绘制其它标签
pts = coord(train_pkt_count(:,m)~=0, :); %sum(train_pkt_count(:,1:3), 2);
train_feat_mat = train_feat; %arrayfun(@(x) double(x.rss), train_feat, 'UniformOutput', true);
% scatter(pts(:,1), pts(:,2), 35, train_pkt_count(train_pkt_count(:,m)~=0, m), 'filled'); % 绘制覆盖范围
% mymap = [linspace(1,1,-62+82+1); linspace(1,0,-62+82+1); linspace(1,0,-62+82+1)]';
mymap = hsv2rgb([linspace(0.69, 0.69, -62+82+1); linspace(0.1,1,-62+82+1); linspace(1,1,-62+82+1)]');
colormap(mymap);
gah = scatter(pts(:,1), pts(:,2), 35, train_feat_mat(train_pkt_count(:,m)~=0, m), 'filled'); % 绘制覆盖范围
colorbar
caxis([-37, -17]);
figset('-t-xl-yl','','x (m)','y (m)', ... 
    '-xt-yt-xm-ym',-4:4, -5:1:4, [-3,3], [-5,3] ...
    );
print('-dpng','-r150', sprintf('results/ch5TagCover-%d',m));


for m=1:3
tags_comp = setdiff(tags, m);
figure; hold on; box on;
plot(0, 0, '^r', 'MarkerSize', 10,'MarkerFaceColor','r');
plot(coord(:,1), coord(:,2), '.k', 'MarkerSize', 1); % 绘制采样点
plot(tag_coord(m,1), tag_coord(m,2), 'sm', 'MarkerSize', 10,'MarkerFaceColor','m');  % 绘制当前标签
plot(tag_coord(tags_comp,1), tag_coord(tags_comp,2), 'xk', 'MarkerSize', 10); % 绘制其它标签
% plot(tag_coord(tags_comp,1), tag_coord(tags_comp,2), 'sk', 'MarkerSize', 10); % 绘制其它标签
pts = coord(train_pkt_count(:,m)~=0, :); %sum(train_pkt_count(:,1:3), 2);
train_feat_mat = train_feat; %arrayfun(@(x) double(x.rss), train_feat, 'UniformOutput', true);
% scatter(pts(:,1), pts(:,2), 35, train_pkt_count(train_pkt_count(:,m)~=0, m), 'filled'); % 绘制覆盖范围
% mymap = [linspace(1,1,-62+82+1); linspace(1,0,-62+82+1); linspace(1,0,-62+82+1)]';
mymap = hsv2rgb([linspace(0.69, 0.69, -62+82+1); linspace(0.1,1,-62+82+1); linspace(1,1,-62+82+1)]');
colormap(mymap);
gah = scatter(pts(:,1), pts(:,2), 35, train_feat_mat(train_pkt_count(:,m)~=0, m), 'filled'); % 绘制覆盖范围
colorbar
caxis([-82, -62]);
figset('-t-xl-yl','','x (m)','y (m)', ... 
    '-xt-yt-xm-ym',-4:4, -5:1:4, [-3,3], [-5,3] ...
    );
% print('-dpng','-r150', sprintf('results/ch5TagCover-%d',m));
end

%% RSS与距离关系分析
markerlist = {'bo', 'bo', 'bo', 'bd'};
% AP->Rx
figure; hold on; 
d2 = vecnorm(coord, 2, 2);
scatter(d2, train_feat_mat(:, 4), 25, markerlist{4}, 'filled');
tmp_index = d2>=0.8&train_pkt_count(:,4)~=0;
[fitresult, gof] = loctag_backscatter_loss_fit(d2(tmp_index), train_feat_mat(tmp_index, 4));
plot(fitresult, '--k');
figset('-t-xl-yl','','Distance (m)','RSS (dBm)', ... 
    '-xt-yt-xm-ym',0:6, -55:5:-15, [0,6], [-55,-15] ...
    );
box on; grid on;
% print('-dpng','-r150', sprintf('results/ch5LocRssWithDistFit-4'));

% Tag->Rx
for m=1:3
figure; hold on;      
d2 = vecnorm(coord - tag_coord(m,:), 2, 2);
scatter(d2, train_feat_mat(:, m), 25, markerlist{m}, 'filled'); % 绘制覆盖范围
tmp_index = d2>=0.8&train_pkt_count(:,m)~=0;
[fitresult, gof] = loctag_backscatter_loss_fit(d2(tmp_index), train_feat_mat(tmp_index, m));
plot(fitresult, '--k');
figset('-t-xl-yl','','Distance (m)','RSS (dBm)', ... 
    '-xt-yt-xm-ym',0:6, -100:5:-60, [0,6], [-100,-60] ...
    );
box on; grid on;
% print('-dpng','-r150', sprintf('results/ch5LocRssWithDistFit-%d', m));
fprintf('R^2=%.3f, DiffRSS: %.2f / ' ,gof.rsquare, mean(train_feat_mat(train_pkt_count(:,m)~=0, m)-train_feat_mat(train_pkt_count(:,m)~=0, 4)));
end
fprintf('\n');


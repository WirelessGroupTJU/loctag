clc
clear all
close all
%% 加载数据
load('../测试数据/D31.mat')
data=A(:,1:2);
%% 设置相关参数
cut_dist=0.8;
%% 统计每个数据点密度
disp("统计数据密度。。。")
data_density=cal_density(data,cut_dist);
%% 计算每个数据点的delta
disp("计算数据delta。。。")
data_delta=cal_delta(data,data_density);
%% 寻找聚类中心点
disp("寻找中心点。。。")
[center,center_index]=find_center(data,data_delta,data_density,cut_dist);
figure;
Plot_find_center(data,center)
%% 开始聚类
disp("聚类。。。")
cluster=Clustering(data,center,center_index,data_density);
figure;
PlotClusterinResult(data,cluster)

%% 密度计算函数
function data_density=cal_density(data,cut_dist)
    data_len=size(data,1);
    data_density=zeros(1,data_len);
    for idata_len=1:data_len
        temp_dist=pdist2(data,data(idata_len,:));
        data_density(idata_len)=sum(temp_dist<=cut_dist);
    end
end

%% 计算delta
function data_delta=cal_delta(data,data_density)
    data_len=size(data,1);
    data_delta=zeros(1,data_len);
    for idata_len=1:data_len
        index=data_density>data_density(idata_len);
        if sum(index)~=0
            data_delta(idata_len)=min(pdist2(data(idata_len,:),data(index,:)));
        else
            data_delta(idata_len)=max(pdist2(data(idata_len,:),data));
        end
    end
end

%% 寻找聚类中心点
function [center,center_index]=find_center(data,data_delta,data_density,cut_dist)
    R=data_density.*data_delta;
    [sort_R,R_index]=sort(R,"descend");
    gama=abs(sort_R(1:end-1)-sort_R(2:end));
    [sort_gama,gama_idnex]=sort(gama,"descend");
    gmeans=mean(sort_gama(2:end));
    %寻找疑似聚类中心点
    temp_center=data(R_index(gama>gmeans),:);
    temp_center_index=R_index(gama>gmeans);
    %进一步筛选中心点
    temp_center_dist=pdist2(temp_center,temp_center);
    temp_center_len=size(temp_center,1);
    center=[];
    center_index=[];
    %判断中心点之间距离是否小于2倍截断距离并中心点去重
    for icenter_len=1:temp_center_len
        temp_index=find(temp_center_dist(icenter_len,:)<2*cut_dist);
        [~,max_density_index]=max(data_density(temp_center_index(temp_index)));
        if sum(center_index==temp_center_index(temp_index(max_density_index)))==0
            center=[center;temp_center(temp_index(max_density_index),:)];
            center_index=[center_index,temp_center_index(temp_index(max_density_index))];
        end
        % center(icenter_len,:)=temp_center(temp_index(max_density_index),:);
    end
end

%% 聚类算法
function cluster=Clustering(data,center,center_index,data_density)
    data_len=size(data,1);
    data_dist=pdist2(data,data);
    cluster=zeros(1,data_len);
    % 标记中心点序号
    for i=1:size(center_index,2)
        cluster(center_index(i))=i;
    end
    % 对数据密度进行降序排序
    [sort_density,sort_index]=sort(data_density,"descend");
    for idata_len=1:data_len
        %判断当前数据点是否被分类
        if cluster(sort_index(idata_len))==0
            near=sort_index(idata_len);
            while 1
                near_density=find(data_density>data_density(near));
                near_dist=data_dist(near,near_density);
                [~,min_index]=min(near_dist);
                if cluster(near_density(min_index))
                    cluster(sort_index(idata_len))=cluster(near_density(min_index));
                    break;
                else
                    near=near_density(min_index);
                end
            end
        end
    end
end
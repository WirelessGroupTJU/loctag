clc
clear all
close all
%% ��������
load('../��������/D31.mat')
data=A(:,1:2);
%% ������ز���
cut_dist=0.8;
%% ͳ��ÿ�����ݵ��ܶ�
disp("ͳ�������ܶȡ�����")
data_density=cal_density(data,cut_dist);
%% ����ÿ�����ݵ��delta
disp("��������delta������")
data_delta=cal_delta(data,data_density);
%% Ѱ�Ҿ������ĵ�
disp("Ѱ�����ĵ㡣����")
[center,center_index]=find_center(data,data_delta,data_density,cut_dist);
figure;
Plot_find_center(data,center)
%% ��ʼ����
disp("���ࡣ����")
cluster=Clustering(data,center,center_index,data_density);
figure;
PlotClusterinResult(data,cluster)

%% �ܶȼ��㺯��
function data_density=cal_density(data,cut_dist)
    data_len=size(data,1);
    data_density=zeros(1,data_len);
    for idata_len=1:data_len
        temp_dist=pdist2(data,data(idata_len,:));
        data_density(idata_len)=sum(temp_dist<=cut_dist);
    end
end

%% ����delta
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

%% Ѱ�Ҿ������ĵ�
function [center,center_index]=find_center(data,data_delta,data_density,cut_dist)
    R=data_density.*data_delta;
    [sort_R,R_index]=sort(R,"descend");
    gama=abs(sort_R(1:end-1)-sort_R(2:end));
    [sort_gama,gama_idnex]=sort(gama,"descend");
    gmeans=mean(sort_gama(2:end));
    %Ѱ�����ƾ������ĵ�
    temp_center=data(R_index(gama>gmeans),:);
    temp_center_index=R_index(gama>gmeans);
    %��һ��ɸѡ���ĵ�
    temp_center_dist=pdist2(temp_center,temp_center);
    temp_center_len=size(temp_center,1);
    center=[];
    center_index=[];
    %�ж����ĵ�֮������Ƿ�С��2���ضϾ��벢���ĵ�ȥ��
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

%% �����㷨
function cluster=Clustering(data,center,center_index,data_density)
    data_len=size(data,1);
    data_dist=pdist2(data,data);
    cluster=zeros(1,data_len);
    % ������ĵ����
    for i=1:size(center_index,2)
        cluster(center_index(i))=i;
    end
    % �������ܶȽ��н�������
    [sort_density,sort_index]=sort(data_density,"descend");
    for idata_len=1:data_len
        %�жϵ�ǰ���ݵ��Ƿ񱻷���
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
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

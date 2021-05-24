%% �����㷨
function cluster=dpc_clustering(data,center,center_index,data_density)
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
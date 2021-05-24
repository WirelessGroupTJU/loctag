%% ÃÜ¶È¼ÆËãº¯Êı
function data_density=cal_density(data,cut_dist)
    data_len=size(data,1);
    data_density=zeros(1,data_len);
    for idata_len=1:data_len
        temp_dist=pdist2(data,data(idata_len,:));
        data_density(idata_len)=sum(exp(-(temp_dist./cut_dist).^2));
    end
end

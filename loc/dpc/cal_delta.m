%% ¼ÆËãdelta
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

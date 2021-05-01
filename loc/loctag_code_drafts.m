%% 读取特征矩阵
% % 正则化 %% 删掉效果更好
% min_feat = min(train_feat_mat);
% max_feat = max(train_feat_mat);
% for m=1:4
%     train_feat_mat(:,m) = (train_feat_mat(:,m)-min_feat(m))./(max_feat(m)-min_feat(m));
%     test_feat_mat(:,m) = (test_feat_mat(:,m)-min_feat(m))./(max_feat(m)-min_feat(m));
% end


%% 内部函数
function D2 = distfun(zi, zj)
    
    D2 = zeros(size(zj,1),1);
    for m=1:size(zj,1)
        nonzero_mask = ((zi~=-100)&(zj(m,:)~=-100));
        D2(m) = vecnorm(zi(nonzero_mask)-zj(m,nonzero_mask), 2);
    end
end


csi_trace = read_log_file('f:/dataset0327/001a');
sample_idx = 16;
csi_entity = csi_trace{sample_idx};
csi = squeeze(csi_entity.csi(:,1,:));
sc_idx = [-28:-1, 1:28];
csi_abs = db(abs(csi));
csi_phase = unwrap(angle(csi));
plot(sc_idx, csi_abs);
ylim([0 60])
figure
plot(sc_idx, csi_phase);
ylim([-2*pi, 2*pi]);

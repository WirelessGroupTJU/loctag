function feat = loctag_csi_to_feat(pkt_trace, ant_dir, is_tag, prop)
    % 输入一个trace文件
%     pkt_count_bn = length(pkt_trace);
    rate_vector = cellfun(@(x) x.rate,pkt_trace);
%     pkt_count_b = sum(rate_vector==0x1b);
    pkt_count_n = sum(rate_vector==0x80);
    pkt_trace_n = pkt_trace(rate_vector==0x80);
    if pkt_count_n==0
        feat = 0;
        return;
    end
    if prop<1
        index = gen_sample_index(pkt_count_n, prop);
        pkt_trace_n = pkt_trace(index);
        pkt_count_n = length(pkt_trace_n);
    end
    
    feat_tmp = zeros(pkt_count_n ,2);
    cnt = 0;
    for kk = 1:pkt_count_n
        sz = size(pkt_trace_n{kk}.csi);
        if length(sz)~=3 || ~all(sz==[3 1 56])
            continue;
        end
        cnt = cnt+1;
        h = squeeze(pkt_trace_n{kk}.csi(:,1,:));
%         sc_idx = [-28:-1, 1:28];
%         si_abs = db(abs(csi));
        csi_phase = angle(h);
        if ant_dir == 0
            csi_phase_diff = [csi_phase(2,:)-csi_phase(1,:); csi_phase(3,:)-csi_phase(1,:)];
        else % 180deg
            csi_phase_diff = [csi_phase(2,:)-csi_phase(3,:); csi_phase(1,:)-csi_phase(2,:)];
        end
        csi_phase_diff(:,1) = wrapTo2Pi(csi_phase_diff(:,1));
        csi_phase_diff = unwrap(csi_phase_diff, [], 2);
        
        csi_phase_diff_mean = mean(csi_phase_diff, 2);
    %     csi_eff = mean(csi_abs, 'all');

        feat_tmp(cnt, 1) = csi_phase_diff_mean(1);
        feat_tmp(cnt, 2) = csi_phase_diff_mean(2);

%         plot(kk, csi_phase_diff_mean(1), '+');
%         plot(kk, csi_phase_diff_mean(2), '+');
%         fprintf('%d: AllNoErr(%d): b(%d)/n(%d)\n', m,pkt_count_bn, pkt_count_b, pkt_count_n);
    end
    feat_tmp = mod(feat_tmp(1:cnt, :), pi);
    cut_dist = 0.08;
    data_density = cal_density(feat_tmp, cut_dist);
    data_delta = cal_delta(feat_tmp, data_density);
    [c_p,center_index] = find_center(feat_tmp,data_delta,data_density,cut_dist);
%     cluster = dpc_clustering(feat_tmp, c_p, center_index, data_density);
    if size(c_p,1)<1
        c_p = mean(feat_tmp,1);
    end        
    feat = c_p(1,:);
%     figure
%     Plot_find_center(feat_tmp,c_p); hold on;
%     PlotClusterinResult(feat_tmp,cluster);
    
% %     [class_idx, c_p] = kmeans(feat_tmp, 3);
%     if is_tag == 0
% %     plot(1:pkt_count_n, feat_tmp(:,1), 'r+', 1:pkt_count_n, feat_tmp(:,2), 'b+');
%         plot(feat_tmp(:,1), feat_tmp(:,2), 'r+');
%         plot(c_p(:,1), c_p(:,2), 'rx',...
%      'MarkerSize',40,'LineWidth',1');
%     else
% %         feat_tmp = rmoutliers(feat_tmp, 'percentiles',[5 95]);
%         plot(feat_tmp(:,1), feat_tmp(:,2), 'b+');
%         plot(c_p(:,1), c_p(:,2), 'bx',...
%      'MarkerSize',40,'LineWidth',1);
%     end
%     histogram2(feat_tmp(:,1), feat_tmp(:,2));
%     plot(feat_tmp(:,1), feat_tmp(:,2), 'b+');
%     plot(center(:,1), center(:,2), 'bx',...
%         'MarkerSize',30,'LineWidth',2);
%     
%     feat = c_p;
end



function index = gen_sample_index(n, prop)
    x = ceil(n*prop);
    if x==0
        index = 1;
    else
        index = 1:x;
    end
end

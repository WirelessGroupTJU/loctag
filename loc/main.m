% csi_trace = read_log_file('dataset/example.csi');
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
ylim([-2*pi, 2*pi])

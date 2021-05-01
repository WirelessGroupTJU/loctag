Q=0:5;
N=1:16;

[QQ, NN] = meshgrid(Q, N);
pp = 1./(2.^QQ);

pp2 = NN.*pp.*(1-pp).^(NN-1); %  (2.^qq-1).^(nn-1)./(2.^(qq.*nn));

figure; hold on
for m=1:length(Q)
    plot(NN(:,m), pp2(:,m).*NN(:,m));
end
% mesh(qq, nn, p);

% x2_s = [0 0 0 0 0 0 0 0   0 0 0 0 0 0 0 0  0 0 0 0 1 0 0];
% gs =   [1 0 0 1 0 0 0 1];
% [x1_zs, x1_zs_r] = gfdeconv(x2_s, gs, p)


% syms z;
% p = 2;
% x1_s = [0 0 0 0 0 0 0  0 0 1 0 0 1 0 1];
% x2 =   [0 0 0 0 0 0 0  1 1 1 1 1 1 1 1];
% gs = [1 0 0 1 0 0 0 1];
% [x1_zi, x1_zi_r] = gfdeconv(x1_s, gs, p);
% [x1_zs, x1_zs_r] = gfdeconv(x2, gs, p);
% 
% x1_zi
% x1_zi_r
% 
% x1_zs
% x1_zs_r

% x1_zi_z = sum (x1_zi.*z.^[-7:7])
% x1_zs_z = sum (x1_zs.*z.^[-7:7])
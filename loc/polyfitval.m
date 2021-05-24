function [Y2, P] = polyfitval(x, Y, n)
%FILEWRITE 用n阶多项式拟合x,y，并返回在x处拟合后的值
%   此处显示详细说明
    P = zeros(size(Y,1), n+1);
    Y2 = zeros(size(Y));
    for m=1:size(Y, 1)
        P(m,:) = polyfit(x, Y(m,:), n);
        Y2(m,:) = polyval(P(m,:), x);
    end
end

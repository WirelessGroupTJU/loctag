function [Y2, P] = polyfitval(x, Y, n)
%FILEWRITE ��n�׶���ʽ���x,y����������x����Ϻ��ֵ
%   �˴���ʾ��ϸ˵��
    P = zeros(size(Y,1), n+1);
    Y2 = zeros(size(Y));
    for m=1:size(Y, 1)
        P(m,:) = polyfit(x, Y(m,:), n);
        Y2(m,:) = polyval(P(m,:), x);
    end
end

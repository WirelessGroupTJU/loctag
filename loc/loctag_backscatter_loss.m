d1 = 0.8;
d2 = 0:0.1:6;
figset('-init',[1,1]);
py = ff(d1, d2);


plot(d2, py);
grid on;

function [Py] = ff(d1,d2)
Py = 24+40*log10(3e8/(4*pi*2.4e9)) + 20*log10(2)- 20*log10(d1+d2)+15;

end
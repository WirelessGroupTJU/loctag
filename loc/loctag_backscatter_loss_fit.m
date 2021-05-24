function [fitresult, gof] = loctag_backscatter_loss_fit(xx, yy)
%CREATEFIT(XX,YY)
%  Create a fit.
%
%  Data for 'untitled fit 1' fit:
%      X Input : xx
%      Y Output: yy
%  Output:
%      fitresult : a fit object representing the fit.
%      gof : structure with goodness-of fit info.
%
%  另请参阅 FIT, CFIT, SFIT.

%  由 MATLAB 于 09-May-2021 20:11:38 自动生成


%% Fit: 'untitled fit 1'.
[xData, yData] = prepareCurveData( xx, yy );

% Set up fittype and options.
ft = fittype( 'a*log10(x)+b', 'independent', 'x', 'dependent', 'y' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
opts.StartPoint = [0.0357116785741896 0.849129305868777];

% Fit model to data.
[fitresult, gof] = fit( xData, yData, ft, opts );

% Plot fit with data.
% figure( 'Name', 'untitled fit 1' );
% h = plot( fitresult, xData, yData );
% legend( h, 'yy vs. xx', 'untitled fit 1', 'Location', 'NorthEast', 'Interpreter', 'none' );
% % Label axes
% xlabel( 'xx', 'Interpreter', 'none' );
% ylabel( 'yy', 'Interpreter', 'none' );
% grid on



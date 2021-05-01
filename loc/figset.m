function  figset(varargin)
%绘图设定
% 返回值: None
% Syntax:
%    figset(OptsA, varA1,varA2,...,OptsB,varB1,varB2,...)
%    figset(fig, OptsA, varA1,varA2,...,OptsB,varB1,varB2,...)
% 选项字符串:
%    -t title 图标题
%    -xl xlabel -yl ylabel 轴标签
%    -xm xlim   -ym ylim   坐标范围
%    -xt XTick  -yt YTick  显示刻度的位置
%    -lengend legend 图例
%    -init 初始化绘图默认值，应在绘图前调用
%    -saveall 以指定前缀保存所有Figure为png格式.
% Examples:
%     figset('-init',[1,1])
%     plot(0:10, 0:0.1:1);
%     hold on
%     h=plot(0:10, 0.5:0.05:1);
%     figset(h, '-t-xl-yl','Example title','example xlabel','example ylabel', ...    % h为当前图形句柄，可选，未设置时作用于当前Axes
%         '-xt-yt-xm',0:1:10, 0:0.1:1, [0,10], ...               % 等价于XTick=0:1:10 YTick=0:0.1:1 xlim([-100 -20])     
%         '-legend', {'example legendA','example legend B'});    %图例，多个字符串用{}括起来作为一个cell数组
%        %注意：选项字符串与参数一一对应，无顺序要求，并且每个选项是可选的
%     figset('-saveall',['Figout/M-']); %将当前所有Figure保存在Figout文件夹（应保证该文件夹已存在），文件名分别为M-01.png M-02.png ...
%  
% Author: S.E.Wei
if nargin<1
    error('缺失参数');
else
    curpos = 1;
    if isa(varargin{1},'matlab.graphics.axis.Axes')
        curpos = curpos+1;
        gah = varargin{1};        
    elseif isa(varargin{1},'matlab.graphics.chart.primitive.Line')
        curpos = curpos+1;
        gah = varargin{1}.Parent(1);        
    elseif isa(varargin{1},'matlab.ui.Figure')
        curpos = curpos+1;
        gahs = varargin{1}.Children;
        axesnum=0;
        for ki = 1:length(gahs)
            if isa(gahs(ki),'matlab.graphics.axis.Axes')
                gah = gahs(ki);
                axesnum = axesnum+1;
                if axesnum>1
                    error('当前Figure有多个Axes');
                end
            end
        end
    elseif numel(get(groot,'Children'))>0
        gah = gca;
    end
    while curpos<=nargin
        if ~isa(varargin{curpos},'char')
            error('Format string not found');
        else
            props = strsplit(varargin{curpos},'-');
            props = props(~strcmpi(props,''));  %去空
            nvars = sum(~(strcmpi(props,'')));
            if curpos+nvars>nargin
                error([varargin{curpos} ' 对应的实参数目不足']);
            else
                varcnt = 1;
                for m=1:length(props)
                    switch props{m}
                        case 't' 
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            title(gah, varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'xl'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            xlabel(gah, varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'yl'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            ylabel(gah, varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'xm'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            xlim(gah, varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'ym'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            ylim(gah, varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'xt'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            set(gah,'XTick', varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'xtl'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            set(gah,'XTickLabel', varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'yt'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            set(gah,'YTick', varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'ytl'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            set(gah,'YTickLabel', varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'legend'
                            if ~exist('gah','var')
                                error('找不到Axes句柄');
                            end
                            legend(gah, varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'init'
                            figureSetDefault(varargin{curpos+varcnt});
                            varcnt = varcnt+1;
                        case 'saveall'
                            grh = groot;
                            figs = grh.Children;
                            for n=1:length(figs)
                                print(figs(n),'-dpng','-r150',[varargin{curpos+varcnt} num2str(figs(n).Number,'%02d')]);
                                print(figs(n),'-depsc','-r150',[varargin{curpos+varcnt} num2str(figs(n).Number,'%02d')]);
                            end
                            varcnt = varcnt+1;
                        otherwise
                            error(['Unknown parameter: -' props{m}]);
                    end %end switch
                end %end for
                curpos = curpos+varcnt;               
            end % end if number check  
        end % end if type check
    end
    if curpos-1~=nargin
        warning('多余的参数被忽略');
    end
end
end
function figureSetDefault(varargin)
rows=1;
cols=1;
linewidth = 1;
if numel(varargin{1})>=2
rows=varargin{1}(1);
cols=varargin{1}(2);
end
if numel(varargin{1})>=3
    linewidth = varargin{1}(3);
end
widthRef = [560 880 1200]; heightRef = [420 660 900];
set(groot, 'DefaultFigurePosition', [400-rows*100, 300-cols*75, widthRef(cols), heightRef(rows)]);
% set(groot, 'DefaultFigurePaperPositionMode','manual');
% set(groot, 'DefaultFigurePaperPosition', [0, 0, widthRef(rows), heightRef(cols)]);
set(groot, 'DefaultAxesPosition', [.12, .13, .78, .79]);
% set(groot, 'DefaultAxesPosition', [.11, .13, .76, .76]);
set(groot, 'DefaultLineLineWidth',linewidth);
% set(groot, 'defaultAxesLineStyleOrder',{'-',':'});
set(groot, 'DefaultAxesFontsize',14);
set(groot, 'DefaultAxesFontname','Times New Roman'); %'Times New Roman'
set(groot, 'DefaultTextFontsize',16);
set(groot, 'DefaultTextFontname','Times New Roman');
set(groot, 'DefaultColorBarFontsize',14);
set(groot, 'DefaultColorBarFontname','Times New Roman'); %'Times New Roman'
set(0,'DefaultAxesFontWeight','bold');
set(0,'DefaultTextFontWeight','bold');
end
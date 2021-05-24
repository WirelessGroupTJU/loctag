function Plot_find_center(data,center)
    hold on
    %% 绘制数据
    plot(data(:,1),data(:,2),'*','Color','red')
    %% 绘制中心点
    plot(center(:,1),center(:,2),'O','LineWidth',2,'MarkerSize',12,'Color','black')
end
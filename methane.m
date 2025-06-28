%% introduction
% This script corrects the EPA's US greenhouse gas emissions data to
% account for EPA's systematic underestimation of methane pollution from
% natural gas infrastructure.

%% data import
rawData = readtable('US-methane-data.csv','NumHeaderLines',1);
year = rawData{:,1}; % year
gasProductionVolume = rawData{:,2}/1000; % US natural gas production, billion ft^3/a
gasDownstreamConsumptionVolume = rawData{:,3}/1000; % US residential and commercial natural gas consumption, billion ft^3/a
EPAgasSystemMethaneEmissions = rawData{:,5}/1000; % US natural gas system methane emissions, Gt/a CO2e
netEmissions = rawData{:,6}/1000; % net (gross - removal) total US greenhouse gas emissions, billion metric tonnes per year (Gt/a)

%% calculations
% gas production mass
gasDensity = 0.051; % density of natural gas at standard temperature and pressure, lb/ft^3
gasProductionMass = gasProductionVolume*gasDensity/2205; % US natural gas production, Gt/a CH4
gasDownstreamConsumptionMass = gasDownstreamConsumptionVolume*gasDensity/2205; % US residential and commercial natural gas consumption, Gt/a CH4

% methane pollution from gas production
n = 1e6; % number of Monte Carlo samples
ny = length(year); % number of years
Ru = repmat((2.95 + 0.087*randn(1,n))/100,ny,1); % 2008+ upstream/mistream emission rate from Sherwin 2024
Ru(year < 2008,:) = repmat((1.32 + 0.285/1.96*randn(1,n))/100,sum(year < 2008),1); % pre-2008 EPA upstream/midstream emission rate from Alvarez 2018
Rd = repmat((2.48 + 0.388*randn(1,n))/100,ny,1); % downstream emission rate from Sargent 2021, McKain 2015, Wunch 2016, Lamb 2016
methaneEmissions = Ru.*gasProductionMass ...
    + Rd.*gasDownstreamConsumptionMass; % methane emissions, Gt/a CH4

% global warming potential and CO2 equivalent from CH4
% GWP sources: https://www.iea.org/reports/methane-tracker-2021/methane-and-climate-change
gwp100 = 29.8 + 11/1.96*randn(1,n); % 100-year global warming potential of methane
gwp20 = 82.5 + 25.8/1.96*randn(1,n); % 20-year global warming potential of methane
methaneCO2e100 = repmat(gwp100,ny,1).*methaneEmissions; % methane emissions, Gt/a CO2e at GWP100
methaneCO2e20 = repmat(gwp20,ny,1).*methaneEmissions; % methane emissions, Gt/a CO2e at GWP20

% adjusted gross emissions
adjustedGrossCO2e100 = netEmissions - EPAgasSystemMethaneEmissions + methaneCO2e100; % adjusted gross emissions, Gt/a CO2e at methane GWP100
adjustedGrossCO2e20 = netEmissions - EPAgasSystemMethaneEmissions + methaneCO2e20; % adjusted gross emissions, Gt/a CO2e at methane GWP20

%% GWP100 and GWP20 plots
f1 = figure(1); clf
yMax = 9; % y-axis upper limit

% central emission estimates
subplot(1,3,1:2), plot(year, netEmissions, 'k')
hold on, plot(year, mean(adjustedGrossCO2e100,2), 'r')
plot(year, mean(adjustedGrossCO2e20,2), 'r--')

% filled areas of 95% confidence interval
fill([year; flip(year)], [quantile(adjustedGrossCO2e100,0.025,2); flip(quantile(adjustedGrossCO2e100,0.975,2))], ...
    'r', 'FaceAlpha', 0.2, 'LineStyle', 'none')
fill([year; flip(year)], [quantile(adjustedGrossCO2e20,0.025,2); flip(quantile(adjustedGrossCO2e20,0.975,2))], ...
    'r', 'FaceAlpha', 0.2, 'LineStyle', 'none')

% axes
ylim([0,yMax]), ylabel({'United States net greenhouse gas emissions','(billion tonnes per year of CO$_2$ equivalent)'})
xlim([1990,2022])
xticks(1990:2:2022)
grid on

% legend
legend('Unadjusted Environmental Protection Agency estimate','Estimate adjusted for methane emissions at GWP100',...
    'Estimate adjusted for methane emissions at GWP20','95\% confidence intervals of adjusted estimates','location','south')

% annotation
i = find(year==2005); % index of reference emissions year
v = netEmissions(i); % magnitude of emissions peak
dx = 0.3; % annotation x offset
text(year(i),0.98*v,{'$\uparrow$',sprintf('%.2g Gt/a',round(10*v)/10),'in 2005'},...
    'color','k','horizontalalignment','center','verticalalignment','top')
text(year(ny) + dx,netEmissions(ny),sprintf('%.2g',round(10*netEmissions(ny))/10),'color','k')
text(year(ny) + dx,mean(adjustedGrossCO2e100(ny,:)),sprintf('%.2g',round(10*mean(adjustedGrossCO2e100(ny,:)))/10),'color','r')
text(year(ny) + dx,mean(adjustedGrossCO2e20(ny,:)),sprintf('%.2g',round(10*mean(adjustedGrossCO2e20(ny,:)))/10),'color','r')

%% GWP sensitivity plot
% 2022 emissions vs. GWP plot
gwp = linspace(10,115,1e2)'; % range of methane GWPs to plot over
adjustedGrossCO2e2022 = netEmissions(end) - EPAgasSystemMethaneEmissions(end) ...
    + repmat(gwp,1,n).*methaneEmissions(end,:); % adjusted gross emissions, Gt/a CO2e at varying methane GWPs

% central 2022 CO2e estimates vs. GWP
subplot(1,3,3), plot(gwp, mean(adjustedGrossCO2e2022,2), 'r')
xlabel('Methane GWP')
xlim([min(gwp),max(gwp)])
ylim([0,yMax])

% filled area of 95% confidence interval
hold on, fill([gwp; flip(gwp)], [quantile(adjustedGrossCO2e2022,0.025,2); flip(quantile(adjustedGrossCO2e2022,0.975,2))], ...
    'r', 'FaceAlpha', 0.2, 'LineStyle', 'none')

% GWP100 annotation
dy = 0.2; % annotation y offset
a = area([quantile(gwp100,0.025),quantile(gwp100,0.975)], max(ylim)*[1 1], 'facecolor', 'b', 'linestyle', 'none');
a.FaceAlpha = 0.1;
xline(mean(gwp100),'b--','linewidth',2)
text(mean(gwp100),dy,'GWP100 mean = 29.8','color','b',...
    'rotation',90,'verticalalignment','bottom','horizontalalignment','left')

% mean GWP20
a = area([quantile(gwp20,0.025),quantile(gwp20,0.975)], max(ylim)*[1 1], 'facecolor','b', 'linestyle', 'none');
a.FaceAlpha = 0.1;
xline(mean(gwp20),'b--','linewidth',2)
text(mean(gwp20),dy,'GWP20 mean = 82.5','color','b',...
    'rotation',90,'verticalalignment','bottom','horizontalalignment','left')

% emissions at central GWP estimates
x = linspace(0,mean(gwp100),1e2);
plot(x,0*x+mean(adjustedGrossCO2e100(ny,:)),'k--','linewidth',1)
x = linspace(0,mean(gwp20),1e2);
plot(x,0*x+mean(adjustedGrossCO2e20(ny,:)),'k--','linewidth',1)

% legend
legend('2022 emissions','location','northwest')

%% display
fprintf('----------------------- 2022 US net emission estimates -----------------------\n')
fprintf('GWP100: %.3g (%.3g to %.3g) Gt/a,',...
    mean(adjustedGrossCO2e100(end,:)),...
    quantile(adjustedGrossCO2e100(end,:),0.025),...
    quantile(adjustedGrossCO2e100(end,:),0.975))
fprintf(' %.3g (%.3g to %.3g) percent decrease.\n',...
    100*(1-mean(adjustedGrossCO2e100(end,:))/6.6),...
    100*(1-quantile(adjustedGrossCO2e100(end,:),0.025)/6.6),...
    100*(1-quantile(adjustedGrossCO2e100(end,:),0.975)/6.6))
fprintf('GWP20: %.3g (%.3g to %.3g) Gt/a,',...
    mean(adjustedGrossCO2e20(end,:)),...
    quantile(adjustedGrossCO2e20(end,:),0.025),...
    quantile(adjustedGrossCO2e20(end,:),0.975))
fprintf(' %.3g (%.3g to %.3g) percent increase.\n',...
    100*(mean(adjustedGrossCO2e20(end,:))/6.6-1),...
    100*(quantile(adjustedGrossCO2e20(end,:),0.025)/6.6-1),...
    100*(quantile(adjustedGrossCO2e20(end,:),0.975)/6.6-1))
fprintf('----------------------- 2022 US methane from natural gas -----------------------\n')
fprintf('GWP100: %.3g (%.3g to %.3g) Gt CO2e/a.\n',...
    mean(methaneCO2e100(end,:)),...
    quantile(methaneCO2e100(end,:),0.025),...
    quantile(methaneCO2e100(end,:),0.975))
fprintf('GWP20: %.3g (%.3g to %.3g) Gt CO2e/a.\n',...
    mean(methaneCO2e20(end,:)),...
    quantile(methaneCO2e20(end,:),0.025),...
    quantile(methaneCO2e20(end,:),0.975))




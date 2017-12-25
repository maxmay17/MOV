%% Evolutionary Learning for Algo trading
% Use of  evolutionary learning (genetic algorithm) to select our signals and
% the logic used to build the trading strategy.
%GA()
%initialize population
%find fitness of population
%while (termination criteria is reached) do
%parent selection
%crossover with probability pc
%mutation with probability pm
%decode and fitness calculation
%survivor selection
%find best
%return best

%% Load in some AAPL data (Excel)
% AAPL is Apple inc. shares and data is sampled daily
data = xlsread('aapl_data.xlsx');
testPts = floor(0.8*length(data(:,6)));
QtClose = data(1:testPts,6);
QtCloseV = data(testPts+1:end,6);
annualScaling = sqrt(250);
cost = 0.01;
addpath('gaFiles')

%% Replicate the MA+RSI approach using evolutionary learning
% First gather the indicator signals for the training set
N =80; M = 81; thresh = 83; P = 9; Q = 7;
sma = leadlag(QtClose,N,M,annualScaling,cost);
srs = rsi(QtClose,[P,Q],thresh,annualScaling,cost);
marsi(QtClose,N,M,[P,Q],thresh,annualScaling,cost)

signals = [sma srs];
names = {'MA','RSI'};


%% Trading signals
% Plot the "state" of the market represented by the signals
figure
ax(1) = subplot(2,1,1); plot(QtClose);
ax(2) = subplot(2,1,2); imagesc(signals')
cmap = colormap([1 0 0; 0 0 1; 0 1 0]);
set(gca,'YTick',1:length(names),'YTickLabel',names);
linkaxes(ax,'x');

%% Generate initial population
% Generate initial population of signals we'll use to seed the search
% space.
close all
I = size(signals,2);
pop = initializePopulation(I);
imagesc(pop)
xlabel('Bit Position'); ylabel('Individual in Population')
colormap([1 0 0; 0 1 0]); set(gca,'XTick',1:size(pop,2))

%% Fitness Function
% Objective is to find a target bitstring (minimum value of -Sharpe Ratio)
type fitness
%%
% Objective function definition as a function handle (the optimization
% sovlers need a function as an input, this is how to define them)
obj = @(pop) fitness(pop,signals,QtClose,annualScaling,cost)
%%
% Evaluate objective for initial population
obj(pop)
%% Solve With Genetic Algorithm
% Find best trading rule and maximum Sharpe ratio (min -Sharpe ratio)
options = gaoptimset('Display','iter','PopulationType','bitstring',...
    'PopulationSize',size(pop,1),...
    'InitialPopulation',pop,...
    'CrossoverFcn', @crossover,...
    'MutationFcn', @mutation,...
    'PlotFcns', @plotRules,...
    'Vectorized','on');

[best,minSh] = ga(obj,size(pop,2),[],[],[],[],[],[],[],options)

%% Evaluate Best Performer
s = tradeSignal(best,signals);
s = (s*2-1); % scale to +/-1
r  = [0; s(1:end-1).*diff(QtClose)-abs(diff(s))*cost/2];
sh = annualScaling*sharpe(r,0);

% Plot results
figure
ax(1) = subplot(2,1,1);
plot(QtClose)
title(['Evolutionary Learning Resutls, Sharpe Ratio = ',num2str(sh,3)])
ax(2) = subplot(2,1,2);
plot([s,cumsum(r)])
legend('Position','Cumulative Return')
title(['Final Return = ',num2str(sum(r),3), ...
    ' (',num2str(sum(r)/QtClose(1)*100,3),'%)'])
linkaxes(ax,'x');


%% Check validation set
sma = leadlag(QtCloseV,N,M,annualScaling,cost);
srs = rsi(QtCloseV,[P Q],thresh,annualScaling,cost);
marsi(QtCloseV,N,M,[P Q],thresh,annualScaling,cost)

signals = [sma srs];
s = tradeSignal(best,signals);
s = (s*2-1); % scale to +/-1
r  = [0; s(1:end-1).*diff(QtCloseV)-abs(diff(s))*cost/2];
sh = annualScaling*sharpe(r,0);

% Plot results
figure
ax(1) = subplot(2,1,1);
plot(QtCloseV)
title(['Evolutionary Learning Resutls, Sharpe Ratio = ',num2str(sh,3)])
ax(2) = subplot(2,1,2);
plot([s,cumsum(r)])
legend('Position','Cumulative Return')
title(['Final Return = ',num2str(sum(r),3), ...
    ' (',num2str(sum(r)/QtCloseV(1)*100,3),'%)'])
linkaxes(ax,'x');
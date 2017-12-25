%% Intro to Algo Trading. Movavg and RSI
% This demo is an introduction to using MATLAB to develop and test a simple
% trading strategy using an exponential moving average and RSI

%%
% Use all cores on my laptop (a quadcore, so 4
% virtual cores).
%parpool (4)


%% Load in some AAPL data (Excel)
% AAPL is Apple inc. shares and data is sampled daily
data = xlsread('aapl_data.xlsx');
testPts = floor(0.8*length(data(:,6)));
QtClose = data(1:testPts,6);
QtCloseV = data(testPts+1:end,6);

%% Create a simple lead/lag technical indicator
% We'll use two exponentially weighted moving averages
% https://www.fidelity.com/learning-center/trading-investing/technical-analysis/technical-indicator-guide/ema
[lead,lag]=movavg(QtClose,5,20,'e');
plot([QtClose,lead,lag]), grid on
legend('Close','Lead','Lag','Location','Best')

%%
% Create trading signal assuming 250 trading days per year
s = zeros(size(QtClose));
s(lead>lag) = 1;                         % Buy  (long)
s(lead<lag) = -1;                        % Sell (short)
r  = [0; s(1:end-1).*diff(QtClose)];   % Return
sh = sqrt(250)*sharpe(r,0);              % Annual Sharpe Ratio

%%
% Plot results
ax(1) = subplot(2,1,1);
plot([QtClose,lead,lag]); grid on
legend('Close','Lead','Lag','Location','Best')
title(['First Pass Results, Annual Sharpe Ratio = ',num2str(sh,5)])
ax(2) = subplot(2,1,2);
plot([s,cumsum(r)]); grid on
legend('Position','Cumulative Return','Location','Best')
linkaxes(ax,'x')

%% Best parameter
% Perform a parameter sweep to identify the best setting.
annualScaling = sqrt(250);
sh = nan(100,1);
for m = 2:100
    [~,~,sh(m)] = leadlag(QtClose,1,m);
end

[~,mxInd] = max(sh);
leadlag(QtClose,1,mxInd,annualScaling)

%% Estimate parameters over a range of values
% Return to the two moving average case and identify the best one.
sh = nan(100,100);
tic
for n = 1:100  
    for m = n:100
        [~,~,sh(n,m)] = leadlag(QtClose,n,m,annualScaling);
    end
end
toc

%%
% Plot results
figure
surfc(sh), shading interp, lighting phong
view([80 35]), light('pos',[0.5, -0.9, 0.05])
colorbar

%%
% Plot best Sharpe Ratio
[maxSH,row] = max(sh);    % max by column
[maxSH,col] = max(maxSH); % max by row and column
leadlag(QtClose,row(col),col,annualScaling)

%% Evaluate performance on validation data
leadlag(QtCloseV,row(col),col,annualScaling)

%% Include trading costs
% add the trading cost associated with the bid/ask spread.  
cost=0.01; % bid/ask spread
range = {1:1:100,1:1:100};
annualScaling = sqrt(250);
llfun =@(x) leadlagFun(x,QtClose,annualScaling,cost);

tic
[maxSharpe,param,sh,vars] = parameterSweep(llfun,range);
toc

figure
surfc(vars{1},vars{2},sh), shading interp, lighting phong
title(['Max Sharpe Ratio ',num2str(maxSharpe,3),...
    ' for Lead ',num2str(param(1)),' and Lag ',num2str(param(2))]);
view([80 35]), light('pos',[0.5, -0.9, 0.05])
colorbar
figure
leadlag(QtCloseV,row(col),col,annualScaling,cost)

%% RSI on data series
% https://www.fidelity.com/learning-center/trading-investing/technical-analysis/technical-indicator-guide/RSI
rs = rsindex(QtClose,14);
plot(rs), title('RSI')

%% RSI on detrended series
% RSI can often be improved by removing the longer term trend.  
rs2 = rsindex(QtClose-movavg(QtClose,60,60),14);
hold on
plot(rs2,'g')
%legend('RSI on raw data','RSI on detrended data')
hold off


%%
% RSI trading strategy.  Note that the trading signal is generated when the
% RSI value is above/below the upper/lower threshold.  We'll use a 70%
% threshld (for the upper, the lower is 1-0.7 = 30%).
rsi(QtClose,[15,20],70,annualScaling,cost)

%% RSI performance
% Let's find the best perfrorming set of parameters.  In the interest of
%
range = {1:300,1:300,83}; 
rsfun = @(x) rsiFun(x,QtClose,annualScaling,cost);
tic
[~,param] = parameterSweep(rsfun,range);
toc
rsi(QtClose,param(1:2),param(3),annualScaling,cost)

%% Test on validation set
%
rsi(QtCloseV,param(1:2),param(3),annualScaling,cost)
%rsi(QtCloseV,[20,14],75,annualScaling,cost)

%% MA + RSI
% Put the moving average together with the RSI.
N = 82; M = 83; % from previous calibration
[sr,rr,shr] = rsi(QtClose,param(1:2),param(3),annualScaling,cost);
[sl,rl,shl,lead,lag] = leadlag(QtClose,N,M,annualScaling,cost);

s = (sr+sl)/2;
r  = [0; s(1:end-1).*diff(QtClose)-abs(diff(s))*cost/2];
sh = annualScaling*sharpe(r,0);

figure
ax(1) = subplot(2,1,1);
plot([QtClose,lead,lag]); grid on
legend('Close',['Lead ',num2str(N)],['Lag ',num2str(M)],'Location','Best')
title(['MA+RSI Results, Annual Sharpe Ratio = ',num2str(sh,3)])
ax(2) = subplot(2,1,2);
plot([s,cumsum(r)]); grid on
legend('Position','Cumulative Return','Location','Best')
title(['Final Return = ',num2str(sum(r),3),' (',num2str(sum(r)/QtClose(1)*100,3),'%)'])
linkaxes(ax,'x')

%% MA+RSI model
% The model in a single function call (same as above but as function)
marsi(QtClose,N,M,param(1:2),param(3),annualScaling,cost)


%% Best parameters

range = {80:100, 80:100, 2:10, 1:10, 83};
fun = @(x) marsiFun(x,QtClose,annualScaling,cost);

tic
[maxSharpe,param,sh] = parameterSweep(fun,range);
toc

param

marsi(QtClose,param(1),param(2),param(3:4),param(5),annualScaling,cost)
%% Run on validation set
marsi(QtCloseV,param(1),param(2),param(3:4),param(5),annualScaling,cost)



function helperVisualizeVelocityProfile(rrSim,actorID, signalName)
%helperVisualizeVelocityProfile plots the logged data in SDI.
%
% NOTE: The name of this helper function and it's functionality may
% change without notice in a future release, or the helper function
% itself may be removed.
%

% Copyright 2021 The MathWorks, Inc.

% Get map information.
rrMap = rrSim.getMap;
% Get data log.
data = rrSim.get("SimulationLog");

sdiRun = Simulink.sdi.createRun(signalName);
plotFigure = findobj('Type','figure', 'Name', 'Vehicle Path');
if isempty(plotFigure)
    % Create new figure and axes
    plotFigure = figure('Name','Vehicle Path','NumberTitle','off');
end

% Get the required data from the log
egoPoseData = data.get('Pose', 'ActorID', actorID);
egoVelocityData = data.get('Velocity', 'ActorID', actorID);
time = [egoPoseData.Time];
position_x = arrayfun(@(x)  x.Pose(1,4), egoPoseData);
position_y = arrayfun(@(x)  x.Pose(2,4), egoPoseData);
velocity = arrayfun(@(x)  norm(x.Velocity,2), egoVelocityData);

% Create time series for velocity
velocityTS = timeseries(velocity, time);
velocityTS.Name = strcat(signalName, "_velocity");

% Create time series for x coordinate of vehicle
positionXTS = timeseries(position_x, time);
positionXTS.Name = strcat(signalName, "_position_x");

% Create time series for y coordinate of vehicle
positionYTS = timeseries(position_y, time);
positionYTS.Name = strcat(signalName, "_position_y");

% Create dataset to store all the time series
signal_ds = Simulink.SimulationData.Dataset;
signal_ds.Name = signalName;
signal_ds = addElement(signal_ds,positionXTS);
signal_ds = addElement(signal_ds,positionYTS);
signal_ds = addElement(signal_ds,velocityTS);

% Add data to SDI
Simulink.sdi.addToRun(sdiRun,'vars', signal_ds);
Simulink.sdi.view

% Check if lateral error is present in logged data
runIDs = Simulink.sdi.getAllRunIDs;
for i = fliplr(runIDs')
    r = Simulink.sdi.getRun(i);
    sId = getSignalIDsByName(r,'position_error');
    if ~isempty(sId)
        break
    end
end

% Update the plot layout
if isempty(sId)
    % Change subplot layout to 1 rows and 1 columns
    Simulink.sdi.setSubPlotLayout(1,1);
else
    s = Simulink.sdi.getSignal(sId);
    % Change subplot layout to 2 rows and 1 columns
    Simulink.sdi.setSubPlotLayout(2,1);
    plotOnSubPlot(s,2,1,true);
    Simulink.sdi.setSubplotLimits(2,1,'yRange',[0,0.5]);
end

% plot velocity
sdiRunObj = Simulink.sdi.getRun(sdiRun);
signalId = getSignalIDsByName(sdiRunObj,strcat(signalName, "_velocity"));
s = Simulink.sdi.getSignal(signalId(end));
plotOnSubPlot(s,1,1,true);
Simulink.sdi.setSubplotLimits(1,1,'yRange',[0,20]);
Simulink.sdi.setSubplotLimits(1,1,'tRange',[0,15]);


%% Plot position on map
lanes = rrMap.map.lanes;
% Loop through each of the lane specifications and plot their coordinates
figure(plotFigure)
hold on
for i = 1 : numel(lanes)
    control_points = lanes(i).geometry.values;
    x_coordinates = arrayfun(@(cp)  cp.x, control_points);
    y_coordinates = arrayfun(@(cp)  cp.y, control_points);
    plot(x_coordinates, y_coordinates, 'black');
end
plot(position_x, position_y, 'DisplayName', signalName, 'Color','R','LineWidth',2)
hold off
axis equal
title("Ego Trajectory and Lane Centers")
ylabel("Y (m)")
xlabel("X (m)")
% Set limits based on actor positions with a padding
padLim = 20;
xlim([min(position_x)-padLim, max(position_x)+padLim])
ylim([min(position_y)-padLim, max(position_y)+padLim])
end

function helperSLTrajectoryFollowerWithRRScenarioSetup(nvp)
%helperSLTrajectoryFollowerWithRRScenarioSetup initializes parameters for
%the model.
% 
% MaxPathPoints name-value argument defines the upper limit on the number
% of path points to read from RoadRunner Scenario.
%
% NOTE: The name of this helper function and it's functionality may
% change without notice in a future release, or the helper function
% itself may be removed.
%

% Copyright 2021-2024 The MathWorks, Inc.

%%
arguments
    nvp.MaxPathPoints = 500;
end

%% Model parameters
assignin('base','timeStep',           0.05);    % Time gap               (s)

%% Path following controller parameters
assignin('base','tau',             0.5);     % Time constant for longitudinal dynamics 1/s/(tau*s+1)
assignin('base','time_gap',        1.5);     % Time gap               (s)
assignin('base','default_spacing', 10);      % Default spacing        (m)
assignin('base','max_ac',          2);       % Maximum acceleration   (m/s^2)
assignin('base','min_ac',          -3);      % Minimum acceleration   (m/s^2)
assignin('base','max_steer',       0.26);    % Maximum steering       (rad)
assignin('base','min_steer',       -0.26);   % Minimum steering       (rad) 
assignin('base','PredictionHorizon', 30);    % Prediction horizon     
assignin('base','v0_ego', 0);                % Initial longitudinal velocity (m/s)
assignin('base','tau2', 0.07);               % Longitudinal time constant (brake)             (N/A)
assignin('base','max_dc', 10);               % Maximum deceleration   (m/s^2)

%% Dynamics modeling parameters
assignin('base','m',  1575);                 % Total mass of vehicle                          (kg)
assignin('base','Iz', 2100);                 % Yaw moment of inertia of vehicle               (m*N*s^2)
assignin('base','Cf', 19000);                % Cornering stiffness of front tires             (N/rad)
assignin('base','Cr', 33000);                % Cornering stiffness of rear tires              (N/rad)
assignin('base','lf', 1.5130);               % Longitudinal distance from c.g. to front tires (m)
assignin('base','lr', 1.3050);               % Longitudinal distance from c.g. to rear tires  (m)

%% Create Simulink bus
helperCreateBusForTrajectoryFollowerWithRRScenario
set_param('TrajectoryFollowerRRTestBench/RoadRunner Scenario','PathPoints',num2str(nvp.MaxPathPoints));
% Create RoadRunner interface buses
evalin("base","load('rrScenarioSimTypes.mat')")
end
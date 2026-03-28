classdef getEgoSpeed < matlab.System
    % getEgoSpeed - Extracts speed based on current time from RoadRunner path data
    
    properties(Nontunable)
        % Maximum number of path points
        MaxNumPoints = 5000;
    end
    
    % Pre-computed constants
    properties(Access = private)
        TimeArray;
        SpeedArray;
        NumValidPoints;
    end
    
    methods
        % Constructor
        function obj = getEgoSpeed(varargin)
            coder.allowpcode('plain');
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:})
        end
    end
    
    methods(Access = protected)
        
        function speed = stepImpl(obj, currentTime, msgs)
            % Initialize output
            speed = 0;
            
            % Process messages to extract timing data
            if ~isempty(msgs) && (msgs.PathTarget.NumPoints > 0)
                pathTarget = msgs.PathTarget;
                
                % Update stored timing data
                obj.NumValidPoints = min(obj.MaxNumPoints, double(pathTarget.NumPoints));
                
                if pathTarget.HasTimings
                    for i = 1:obj.NumValidPoints
                        obj.TimeArray(i) = pathTarget.Timings(i).Time;
                        obj.SpeedArray(i) = pathTarget.Timings(i).Speed;
                    end
                end
            end
            
            % Interpolate speed based on current time
            if obj.NumValidPoints > 0
                validTimes = obj.TimeArray(1:obj.NumValidPoints);
                validSpeeds = obj.SpeedArray(1:obj.NumValidPoints);
                
                if currentTime <= validTimes(1)
                    speed = validSpeeds(1);
                elseif currentTime >= validTimes(end)
                    speed = validSpeeds(end);
                else
                    % Linear interpolation
                    speed = interp1(validTimes, validSpeeds, currentTime, 'linear');
                end
            end
        end
        
        function setupImpl(obj)
            % Initialize arrays
            obj.TimeArray = zeros(obj.MaxNumPoints, 1);
            obj.SpeedArray = zeros(obj.MaxNumPoints, 1);
            obj.NumValidPoints = 0;
        end
        
        function out = getOutputSizeImpl(~)
            % Return size for output port
            out = [1 1];
        end
        
        function interface = getInterfaceImpl(~)
            import matlab.system.interface.*;
            interface = [Input("currentTime", Data), ...
                        Input("msgs", Message), ...
                        Output("speed", Data)];
        end
        
        function out = getOutputDataTypeImpl(~)
            out = "double";
        end
        
        function out = isOutputComplexImpl(~)
            out = false;
        end
        
        function out = isOutputFixedSizeImpl(~)
            out = true;
        end
    end
    
    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = "Interpreted execution";
        end
        
        function header = getHeaderImpl
            % Define header panel for System block dialog
            header = matlab.system.display.Header(...
                'Title', 'Get Ego Speed', ...
                'Text', 'Extracts speed based on current time from RoadRunner path data.', ...
                'ShowSourceLink', false);
        end
    end
end

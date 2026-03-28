classdef HelperReferencePoseOnPath < matlab.System
    % HELPERREFERENCEPOSEONPATH computes reference pose of the ego vehicle
    % on reference path based on previous pose.
    %
    % NOTE: The name of this System Object and its functionality may change
    % without notice in a future release, or the System Object itself may
    % be removed.
    %
    
    % Copyright 2021-2024 The MathWorks, Inc.

    % Pre-computed constants
    properties(Access = private)

        % Starting Index of section containing reference pose
        SectionStartIndex = 1;

        % Prevous reference pose and curvature
        RefPosePrev
        RefCurvaturePrev

        % Reference path
        RefPath
        % Reference curvature of whole path
        RefCurvature
    end

    methods(Access = protected)
        function [RefPointOnPath, RefCurvature, IsGoalReached] = stepImpl(obj, PrevVehicleInfo, Trajectory, NumTrajPoints)
            
            % Getting Pose information from currPosePrev
            currPose = [PrevVehicleInfo.CurrPose(1), PrevVehicleInfo.CurrPose(2), deg2rad(PrevVehicleInfo.CurrPose(3))];

            if isempty(obj.RefPath) || ~isequal(obj.RefPath,Trajectory)
            % Interpolate waypoints and caluculate curvatures
                [waypoints, curvatures] = generateCurvatures(obj,Trajectory,NumTrajPoints);
                obj.RefPath = waypoints;
                obj.RefCurvature = curvatures;
            end

            % Obtain reference pose on the path based on the previous pose
            [IsGoalReached,RefPointOnPath,RefCurvature] = computeReferenceStateBasedOnPose(...
                obj,currPose,obj.RefPath,obj.RefCurvature);

            % Update the pose and curvature for next time step
            obj.RefPosePrev = RefPointOnPath;
            obj.RefCurvaturePrev = RefCurvature;
        end

        % Generate curvatures from the trajectory
        function [refPose, refCurvature] = generateCurvatures(obj, trajectory, numTrajPoints)
            % Remove repetetive waypoints
            [~,uniqueId] = unique(trajectory(1:numTrajPoints,:),'rows','stable');
            trajectory = trajectory(uniqueId,:);

            % Interpolate based on distance
            interpDistance = 3;
            cumDistance = [0, cumsum(vecnorm(diff(trajectory),2,2))'];
            interpNumTrajPoints = round(cumDistance(end)/interpDistance);
            cumDistanceResample = linspace(0, cumDistance(end), interpNumTrajPoints);
            % Interpolate the postion
            refPose = zeros(interpNumTrajPoints,3);
            refPose(:,1) = interp1(cumDistance,trajectory(:,1),cumDistanceResample);
            refPose(:,2) = interp1(cumDistance,trajectory(:,2),cumDistanceResample);

            % Get reference yaw using interpolated position
            refYaw = getYaw(obj,refPose(:,1:2),interpNumTrajPoints);
            refPose = [refPose(:,1:2), refYaw];

            % Calculating curvature
            [~,~,~,refCurvature] = smoothPathSpline(refPose, ones(interpNumTrajPoints,1),interpNumTrajPoints);
            refPose(:,3) = deg2rad(refPose(:,3));
        end

        % Caluculate yaw from the positions
        function refYaw = getYaw(~, trajectory, numTrajPoints)
            refYaw = zeros(numTrajPoints,1);
            
            for idx = 2:numTrajPoints
                % Get the positions
                currPoint = trajectory(idx-1, :);
                nextPoint = trajectory(idx, :);
                % Caluculate yaw
                if ~all(nextPoint == currPoint)
                    tangent = (nextPoint - currPoint)/ norm(nextPoint - currPoint);
                    tangent = tangent / norm(tangent);
                    yaw = atan2d(tangent(2), tangent(1));
                    % Store the yaw
                    refYaw(idx-1,1) = yaw;
                else
                    refYaw(idx-1,1) = refYaw(idx-2,1);
                end
            end
            refYaw(end,1) = refYaw(end-1,1);
        end

        % Caluclate reference pose on the path based on the previous pose
        function [isGoalReached,refPoseCurr,refCurvature] = computeReferenceStateBasedOnPose(...
                obj, currPosePrev, waypoints, curvatures)
            
            if obj.SectionStartIndex < 1
                obj.SectionStartIndex = 1;
            end
            
            refPoseCurr  = zeros(1, 3);
            refCurvature = 0;
            isGoalReached = true;
            
            numWaypoints = size(waypoints,1);
            if (numWaypoints == 0)
                return;
            end
            
            % Distance between section start and end points
            DeltaXY = [waypoints(obj.SectionStartIndex+1,1)-waypoints(obj.SectionStartIndex,1),...
                       waypoints(obj.SectionStartIndex+1,2)-waypoints(obj.SectionStartIndex,2)];
            
            % Distance between current position and section starting point
            RXY = [currPosePrev(1)-waypoints(obj.SectionStartIndex,1),...
                   currPosePrev(2)-waypoints(obj.SectionStartIndex,2)];
            
            % Normalized distance between current position and section starting point
            u = (RXY.*DeltaXY)/(DeltaXY.*DeltaXY);
            
            % Find section ending point
            indexIncrement = ceil(u-1);
            
            if indexIncrement<0
                % In current section
                indexIncrement = 0;
            end
            if u >=1
                % Increment to appropriate section 
                % with the assumption that the distance between waypoints is 
                % approximately equal for near sections
                obj.SectionStartIndex = obj.SectionStartIndex+indexIncrement;
                
                % Adjust u to account for new section starting point
                u = u - indexIncrement;
            end
            
            if obj.SectionStartIndex < (numWaypoints-1)
                % Operating within valid sections
                currentSectionEndIndex = obj.SectionStartIndex+1;
                nextSectionEndIndex    = currentSectionEndIndex+1;
                % Target States at end point of current and next sections
                XYTarget0 = [waypoints(obj.SectionStartIndex,1),...
                             waypoints(obj.SectionStartIndex,2)];
                XYTarget1 = [waypoints(currentSectionEndIndex,1),...
                             waypoints(currentSectionEndIndex,2)];
                YawTarget0 = waypoints(obj.SectionStartIndex,3);
                YawTarget1 = waypoints(currentSectionEndIndex,3);
                
                CurvatureTarget1 = curvatures(currentSectionEndIndex);
                CurvatureTarget2 = curvatures(nextSectionEndIndex);
                
                % Section weights         
                Weight1 = (1-u);
                Weight2 = u;
                % Target position
                XYTargetCurr = Weight1*XYTarget0+Weight2*XYTarget1;
                YawTargetCurr = Weight1*YawTarget0+Weight2*YawTarget1;
                % Desired RefPose
                refPoseCurr = [XYTargetCurr rad2deg(YawTargetCurr)];
                
                % Desired curvature
                refCurvature = Weight1*CurvatureTarget1+Weight2*CurvatureTarget2;
                isGoalReached = false;
                
            else
                % Maintain last heading between points
                refPoseCurr = obj.RefPosePrev;   
                refCurvature = obj.RefCurvaturePrev;
                obj.SectionStartIndex = numWaypoints-1;
                isGoalReached = true;
            end
        end


        function resetImpl(~)
            % Initialize / reset discrete-state properties
        end

        function icon = getIconImpl(~)
            % Use class name slightly raised above center
            icon = [mfilename("class"), newline, newline, newline, newline];
        end

        function [out,out2,out3] = getOutputSizeImpl(~)
            % Return size for each output port
            out = [1 3];
            out2 = [1 1];
            out3 = [1 1];
        end

        function [out,out2,out3] = getOutputDataTypeImpl(~)
            % Return data type for each output port
            out = "double";
            out2 = "double";
            out3 = "boolean";
        end

        function [out,out2,out3] = isOutputComplexImpl(~)
            % Return true for each output port with complex data
            out = false;
            out2 = false;
            out3 = false;
        end

        function [out,out2,out3] = isOutputFixedSizeImpl(~)
            % Return true for each output port with fixed size
            out = true;
            out2 = true;
            out3 = true;
        end
        
    end

    methods(Access = protected, Static)
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = "Interpreted execution";
        end
    end
end

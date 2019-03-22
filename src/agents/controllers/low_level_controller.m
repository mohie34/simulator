classdef low_level_controller < handle
properties
    n_agent_states
    n_agent_inputs
    desired_trajectory
    n_outputs = 0 ;
end

methods
%% constructor
    function LLC = low_level_controller(varargin)
        for idx = 1:2:length(varargin)
            LLC.(varargin{idx}) = varargin{idx+1} ;
        end
    end
    
%% setup
    function setup(LLC,A)
        % method: setup(A)
        %
        % Take in an agent file and set up the relevant parameters
        % necessary for the low-level controller to operate
        
        LLC.n_agent_states = A.n_states ;
        LLC.n_agent_inputs = A.n_inputs ;
    end
    
%% get control inputs
    function U = get_control_inputs(~,~,t,~,varargin)
        % method: U = get_control_inputs(agent,t_cur,z_cur,T_ref,U_ref,Z_ref)
        %
        % Given an agent, current time, current state, and reference
        % trajectory as time/input/desired state, generate a control input
        % to pass to the agent's dynamics.
        %
        % This method is meant to be called by A.dynamics when in the
        % forward-integration loop of A.integrator. By default, it linearly
        % interpolates an input U at the time t given T_ref and U_ref.
        
        T_ref = varargin{1} ;
        U_ref = varargin{2} ;
        
        U = match_trajectories(t,T_ref,U_ref) ;
    end

%% verbose display
    function vdisp(LLC,s,l)
    % Display a string s if the message's verbose level l is greater
    % than or equal to the planner's verbose level.
        if nargin < 3
            l = 1 ;
        end
        if LLC.verbose >= l
            if ischar(s)
                disp(['        LLC: ',s])
            else
                disp('        LLC: String not provided!')
            end
        end
    end
end
end
classdef rigid_body_agent_SE3 < agent_3D
properties
    % parameters
    m = 1 ; % kg
    J = eye(3) ; % inertia matrix
    Jinv = eye(3) ;
    g = 9.81 ; % gravity
    gravity_on_flag = true ;
    gravity_direction = [0;0;-1] ; % default "down" direction
    
    % states: (position, velocity, angular_velocity) \in R^9
    velocity_indices = 4:6 ;
    angular_velocity_indices = 7:9 ;
    attitude = eye(3) ; % each slice in dim 3 is a rotation matrix
    
    % timing
    integrator_time_discretization = 0.05 ;
    animation_time_discretization  = 0.1 ;
    
    % plotting
    plot_frame_flag = true ;
    plot_frame_scale = 1 ;
    plot_frame_colors = eye(3) ;
    animation_plot_buffer = 1 ; % meter
end

methods
%% constructor
    function A = rigid_body_agent_SE3(m,J,varargin)
        A@agent_3D(varargin{:}) ;
        A.m = m ;
        A.J = J ;
        A.Jinv = inv(J) ;
        
        if A.n_states < 9
            % This agent has states for position in R^3, velocity in R^3,
            % and angular velocity in R^3 (which gets mapped to so(3) via
            % the hat map for computing attitude dynamics.
            A.n_states = 9 ;
        end
        
        % set up the additional plot data fields needed
        A.plot_data.e1_data = [] ;
        A.plot_data.e2_data = [] ;
        A.plot_data.e3_data = [] ;
    end
    
%% reset
    function reset(A,position,attitude)
        % method: reset(state)
        %
        % This method uses the default reset as follows:
        %   A.reset(state)    % given a full A.n_states-by-1 state
        %   A.reset(position) % given a 3-by-1 position
        % 
        % In the above cases, the agent's attitude defaults to eye(3).
        % Alternatively, you can call this method with an attitude
        % represented as a 3-by-3 matrix in SO(3) as:
        %   A.reset(state,attitude)
        %   A.reset(position,attitude)
        if nargin < 2
            position = zeros(9,1) ;
        end
        
        reset@agent_3D(A,position)
        if nargin > 2
            A.attitude = attitude ;      
        else
            A.attitude = eye(3) ;
        end
    end
    
%% move
    function move(A,t_move,T_ref,U_ref,Z_ref)
        if nargin < 5
            Z_ref = [] ;
        end
        
        [T_used,U_used,Z_used] = A.move_setup(t_move,T_ref,U_ref,Z_ref) ;
        
        % get current state and orientation
        z_cur = A.state(:,end) ;
        R_cur = A.attitude(:,:,end) ;
        
        % call integrator to simulate agent's dynamics
        [tout,zout,Rout] = A.integrator(@(t,y,R) A.dynamics(t,y,R,T_used,U_used,Z_used),...
                                        [0, t_move], z_cur, R_cur) ;
        
        A.commit_move_data(tout,zout,Rout,T_used,U_used) ;       
    end
    
    function commit_move_data(A,tout,zout,Rout,T_used,U_used)
        commit_move_data@agent_3D(A,tout,zout,T_used,U_used) ;
        A.attitude = cat(3,A.attitude,Rout) ;
    end
    
%% default integrator with SO(3)
    function [tout,yout,Rout] = integrator(A,fun,tspan,y0,R0)
        [tout,yout,Rout] = ode1_with_SO3(fun,tspan,y0,R0,...
                                         A.integrator_time_discretization,...
                                         A.angular_velocity_indices) ;
    end
    
%% dynamics
    function zd = dynamics(A,t,z,~,T_ref,U_ref,~)
        % method: dz/dt = dynamics(t,z,R,T_ref,U_ref,Z_ref)
        %
        % Compute the dynamics in position, velocity, and angular velocity
        % given the input time T_ref, force (rows 1--3 of U_in), and moment
        % (rows 4--6 of U_ref). The
        %
        % Note that acceleration due to gravity is added by default. This
        % can be changed by setting A.gravity_on_flag to false.
        
        % compute current force and moment inputs
        U = match_trajectories(t,T_ref,U_ref) ;
        F = U(1:3) ;
        M = U(4:6) ;
        
        % add gravity to the input force
        if A.gravity_on_flag
            F = F + A.g.*A.gravity_direction ;
        end
        
        % change in position
        xd = z(A.velocity_indices) ;
        
        % change in velocity
        vd = F ;
        
        % change in angular velocity
        O = z(A.angular_velocity_indices) ;
        Od = A.Jinv*(M - cross(O,A.J*O)) ;
        
        % output dynamics
        zd = [xd ; vd ; Od] ;
    end
    
%% plotting
    function plot(A,color)
        if nargin < 2
            color = [0 0 1] ;
        end
        
        % run agent_3D plot (trajectory data)
        plot@agent_3D(A,color) ;
        
        % get state
        p = A.state(A.position_indices,end) ;
        R = A.attitude(:,:,end) ;
        
        if A.plot_frame_flag
            % plot the coordinate frame defined by the body's rotation matrix
            if A.check_if_plot_is_available('e1_data')
                new_plot_data = plot_coord_frame_3D(R,p,'Data',A.plot_data) ;
            else
                % create new coordinate frame plot data
                hold on
                new_plot_data = plot_coord_frame_3D(R,p,...
                                'Scale',A.plot_frame_scale,...
                                'Colors',A.plot_frame_colors,...
                                'LineWidth',2) ;                   
                hold off
            end

            % update A.plot_dta
            A.plot_data.e1_data = new_plot_data.e1_data ;
            A.plot_data.e2_data = new_plot_data.e2_data ;
            A.plot_data.e3_data = new_plot_data.e3_data ;
        end
    end
    
    function R_out = plot_at_time(A,t)
        % method R_t = plot_at_time(t)
        %
        % Plot the rigid body's coordinate frame at the specified time t,
        % which should be in the interval of [A.time(1),A.time(end)]. Note
        % that the attitude plotted is approximate, computed using an Euler
        % step on SO(3) relative to the closest time available in A.time.
        
        % get state at time t
        z_t = match_trajectories(t,A.time,A.state) ;
        p_t = z_t(A.position_indices);
        
        % find the time closest to t in the saved time
        [~,t_closest_idx] = min(abs(A.time - t)) ;
        t_closest = A.time(t_closest_idx) ;
        
        % get rotation matrix at time closest to t, then perform an Euler
        % step in SO(3) to get the rotation at t
        R_t_closest = A.attitude(:,:,t_closest_idx) ;
        dt = t - t_closest ;
        O_t = z_t(A.angular_velocity_indices) ;
        F = expm(dt.*skew(O_t)) ;
        R_t = F*R_t_closest ;
        
        % check whether or not to create new plot data
        if A.check_if_plot_is_available('e1_data')
            new_plot_data = plot_coord_frame_3D(R_t,p_t,'Data',A.plot_data) ;
        else
            % create new coordinate frame plot data
            new_plot_data = plot_coord_frame_3D(R_t,p_t,...
                            'Scale',A.plot_frame_scale,...
                            'Colors',A.plot_frame_colors,...
                            'LineWidth',2) ;             
        end

        % update A.plot_data
        A.plot_data.e1_data = new_plot_data.e1_data ;
        A.plot_data.e2_data = new_plot_data.e2_data ;
        A.plot_data.e3_data = new_plot_data.e3_data ;
        
        if nargout > 0
            R_out = R_t ;
        end
    end
    
    function animate(A)
        % method: animate()
        %
        % Given the agent's executed trajectory, animate it for the
        % duration given by A.time. The time between animated frames is
        % given by A.animation_time_discretization.
        
        % get time
        t_vec = A.time(1):A.animation_time_discretization:A.time(end) ;
        
        % get axis limits
        z = A.state(A.position_indices,:) ;
        xmin = min(z(1,:)) - A.animation_plot_buffer ;
        xmax = max(z(1,:)) + A.animation_plot_buffer ;
        ymin = min(z(2,:)) - A.animation_plot_buffer ;
        ymax = max(z(2,:)) + A.animation_plot_buffer ;
        zmin = min(z(3,:)) - A.animation_plot_buffer ;
        zmax = max(z(3,:)) + A.animation_plot_buffer ;        
        
        for t_idx = t_vec
            A.plot_at_time(t_idx)
            axis equal
            axis([xmin xmax ymin ymax zmin zmax])            
            pause(A.animation_time_discretization)
        end
    end
end
end
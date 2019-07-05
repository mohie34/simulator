function out = check_if_plot_is_available(simulator_object,fieldname)
    % out = check_if_plot_is_available(simulator_object,fieldname)
    %
    % Given a simulator object (agent, world, or planner), and a fieldname
    % of object.plot_data, check if that fieldname (and the corresponding
    % plot data) is available. Also check if a figure is up in the global
    % figure root. If both the figure and the object's plot data are
    % available, return true.
    
    if nargin < 2
        F = fieldnames(simulator_object.plot_data) ;
        fieldname = F{1} ;
    end
    try
        fh = get(groot,'CurrentFigure') ;
        h = simulator_object.plot_data.(fieldname) ;
        out = ~(isempty(h) || ~all(isvalid(h)) || isempty(fh)) ;
    catch
        out = false ;
    end
end
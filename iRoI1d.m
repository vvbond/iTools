classdef iRoI1d < iTool
% Interactive tool for specifying a 1D region of interest (ROI).
%
% Usage
% =====
%  iRoI1d                   
%  roi = iRoI1d             
%  roi = iRoI1d(interval)   
%  roi = iRoI1d(hax, interval)
% 
% Input
% =====
%  no input     - create a 1d ROI in the current axes interactively by click-and-dragging. 
%
% Optional
% --------
%  interval     - a 2-vector of the ROI's [start, end] position on the x-axis of the current axes.  
%  hax          - handle of the axes for the ROI.
%
% Properties
% ==========
%  interval     - 2-vector defining the current interval of the ROI.
%  width        - scalar, ROI's interval width.
%  data         - structure with .x and .y fields holding ROI's x-coordinate and y-data values.
%
% Context menu
% ============
%  View data    - opens a separate figure with a plot of the ROI data.  
%  Peaks Finder - sends ROI data to the iPeaksFinder utility.
%  Delete       - deletes ROI object and its plot.
%
% Example
% =======
% figure, plot(cumsum(rand(1000,1)*2-1)), roi = iRoI1d([200 600])
%
% See also: iPoint, iLineSegment, iRectangle, iRectROI, iPeaksFinder.

% (c) Vladimir Bondarenko, http://www.mathworks.co.uk/matlabcentral/fileexchange/authors/52876
    
    %% Properties
    properties
        facealpha = .1
%         lineStyle           % string, specifies the color and style of the vertical lines.
%         lineColor           % color of the two side lines.
%         lineWidth           % scalar, defines the width of the vertical lines.
        displayFcn            % handle of the display function, returning an info string: str = f(roi).
                              % Default: @(roi) num2str(roi.width, '%5.2f').
%         displayPosition    % 4-vector of [left top height width] parameters of the display box. Default: [.7 .85 .1 .1]
    end

    properties(Dependent)
        interval            % 2-vector specifying the [from to] range of the ROI in the axis format, e.g., datetime.
        width               % interval width in the axis format.
        data                % ROI data stored in a structure as .x and .y coordinates.
        interval_num        % 2-vector in numeric format.
        width_num           % interval width in numeric format.
        vertices            % vertices defining the ROI's rectangular patch object.
    end

    events
        roiCreated
        roiChanged
    end
        
    methods
        %% Constructor
        function r = iRoI1d(interval)
            
            % Defaults:
%             r.lineStyle = '-';
%             r.lineColor = [.5 .5 .5];
%             r.lineWidth = 2;
%             r.displayPosition = [.65 .85 .1 .1];
            r.flags.roiPlotOn = false;
            if nargin == 0
                interval = [];
            end
            
            % Display function:
            r.displayFcn = @(roi) num2str(roi.width, '%5.2f');
            if r.is_valid_handle('hax') && isa(r.handles.hax.XAxis, 'matlab.graphics.axis.decorator.DatetimeRuler')
                r.displayFcn = @(roi) datestr(roi.width, 'MM:SS');
            end            

            % Range initialization:
            if ~isempty(interval)
                r.init(interval);
                r.init_plot();
            else
                r.store_window_callbacks();
                r.handles.ilines(1) = ixline(r.handles.hax, []);
                addlistener(r.handles.ilines(1), 'lineCreated', @(src,evt) r.ginput_end(src,evt));
            end
            

        end
        
        %% Destructor
        function delete(r)
            delete(r.handles.ilines);
            if r.is_valid_handle('rect'), delete(r.handles.rect); end
            if r.is_valid_handle('infotext'), delete(r.handles.infotext); end
        end

        %% Init
        function init(r, interval)
            r.handles.ilines(1) = ixline(r.handles.hax, interval(1));
            r.handles.ilines(2) = ixline(r.handles.hax, interval(2));
        end

        function init_plot(r)
            hold(r.handles.hax, 'on');
            r.handles.rect = fill(r.vertices(:,1), r.vertices(:,2), 'b', 'FaceAlpha', r.facealpha);
            hold(r.handles.hax, 'off');

            r.display_info();
            
            % Interactivity:
            addlistener(r.handles.ilines, 'positionChanged', @(src,evt) r.update() );
            set(r.handles.rect, 'ButtonDownFcn', @(src,evt) rect_bdcb(r,src,evt));
            
            % Context menu:
            r.handles.cm = uicontextmenu;
            r.handles.cmenu(1) = uimenu(r.handles.cm, 'Label', 'View data', 'tag', 'switch_roi_plot', 'checked', 'off', 'callback', @(src,evt) r.switch_roi_plot());
            r.handles.cmenu(end+1) = uimenu(r.handles.cm, 'Label', 'Peaks Finder', 'checked', 'off', 'callback', @(src,evt) r.roi_find_peaks());
            r.handles.cmenu(end+1) = uimenu(r.handles.cm, 'Label', 'Delete', 'tag', 'delete', 'checked', 'off', 'callback', @(src,evt) r.delete());
            set(r.handles.rect, 'UIContextMenu', r.handles.cm);

            % Notification:
            notify(r,'plotCreated');
        end
        
        %% Interactions 
        function ginput_end(r, ~, ~)
            r.handles.ilines(2) = ixline(r.handles.hax, r.handles.ilines(1).Value);
            r.init_plot();
            click_evt = struct('Button', 1);
            r.handles.ilines(2).bdcb([], click_evt);
            r.handles.listeners = event.listener(r.handles.ilines(2), 'buttonUp', @(src,evt) r.roi_created_cb(src,evt));
        end

        function roi_created_cb(r, ~, ~)
            r.restore_window_callbacks();
            delete(r.handles.listeners(end));
            r.handles.listeners(end) = [];
            notify(r, 'roiCreated');
        end

        % button down callback
        function rect_bdcb(r,~,evt)
            
            if evt.Button ~= 1, return; end
            dx = r.interval_num(1) - r.currentPoint(1);
            r.store_window_callbacks();
            set(r.handles.hfig, 'windowButtonMotionFcn', @(src,evt) wbmcb(r,src,evt, dx),...
                                'windowButtonUpFcn',     @(src,evt) wbucb(r,src,evt),...
                                'pointer', 'left');
        end
                
        % window button motion callback
        function wbmcb(r,~,~, dx)
            roi_width = diff(r.interval_num);
            r.handles.ilines(1).Value = r.currentPoint(1) + dx;
            r.handles.ilines(2).Value = r.handles.ilines(1).Value + roi_width;
        end
        
        % window button up callback
        function wbucb(r,~,~)
            r.restore_window_callbacks();
            notify(r, 'buttonUp');
        end        
        
        %% ROI update
        function update(r)
            set(r.handles.rect, 'XData', r.vertices(:,1), 'YData', r.vertices(:,2));
            set(r.handles.infotext, 'Position', r.vertices([2,7]), 'String', r.displayFcn(r));
            if r.flags.roiPlotOn
                r.plot_data();
            end
            notify(r, 'roiChanged');
        end
        
        %% Annotation
        function display_info(r)
            r.handles.infotext = text(r.vertices(2,1), r.vertices(3,2), r.displayFcn(r), 'FontSize', 16);
        end

        function s = infoString(r)
            s = datestr(r.width, 'HH:MM:SS');
%             s = ['ROI: [' num2str(r.rng', '%5.2f ') ']' ];
        end
    end

    %% RoI operations
    methods
        % Check which elements of v fall within roi's interval. 
        function ind = within(r, v)
            ind = within(ruler2num(v, r.handles.hax.XAxis), r.interval_num);
        end

        function plot_data(r)
            if ~r.is_valid_handle('roiplot')
                T = [ 1 0 0 0;
                      0 1 0 -.5;
                      0 0 1 0;
                      0 0 0 .5 ];
                hfig = figure('OuterPosition', get(r.handles.hfig, 'OuterPosition')*T');
                r.handles.roiplot = plot(r.data.x, r.data.y);
                grid on, box on, axis tight;
                iAxes.set_keyboard_shortcuts(hfig);
            else
                set(r.handles.roiplot, 'XData', r.data.x, 'YData', r.data.y);
            end
        end
    
        function roi_find_peaks(r)
            r.handles.peaksFinder = iPeaksFinder(r.data.y, r.data.x);
        end
    end

    %% Setters & Getters
    methods
        function val = get.interval_num(r)
            val = [r.handles.ilines.Value];
        end

        function val = get.interval(r)
            val = num2ruler(r.interval_num, r.handles.hax.XAxis);
        end

        function val = get.vertices(r)
            ylims = get(r.handles.hax, 'YLim');
            val = [r.interval_num([1 2 2 1]); ylims([1 1 2 2])]';
        end

        function val = get.width(r)
            val = diff(num2ruler(r.interval_num, r.handles.hax.XAxis));
        end

        function val = get.width_num(r)
            val = diff(r.interval_num);
        end

        function data = get.data(r)
            l = arrayfilter(@(a) isa(a, 'matlab.graphics.chart.primitive.Line'), r.handles.hax.Children);
            if isempty(l)
                data = [];
                return;
            end
            ind  = r.within(l(1).XData);
            data = struct('x', l.XData(ind), 'y', l.YData(ind));
        end
    
        function switch_roi_plot(r)
            menuitem = findobj(r.handles.cm, 'tag', 'switch_roi_plot');
            menuitem.Checked = ifthel(menuitem.Checked == "on", "off", "on");
            if menuitem.Checked == "on"
                r.flags.roiPlotOn = true;
                r.plot_data();
            else
                r.flags.roiPlotOn = false;
            end

        end
    end
end


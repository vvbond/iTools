classdef iROI < iTool
% Interactive tool for specifying a 1D region of interest (ROI).
%
% Usage
% =====
%  iROI
%  roi = iROI
%  roi = iROI(interval)   
%  roi = iROI(hax, interval)
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
% figure, plot(cumsum(rand(1000,1)*2-1)), roi = iROI([200 600])
%
% See also: iROI_tool, iPoint, iLineSegment, iRectangle, iRectROI, iPeaksFinder.

% (c) Vladimir Bondarenko, http://www.mathworks.co.uk/matlabcentral/fileexchange/authors/52876
    
    %% Properties
    properties(SetObservable)
        alpha = .1
        color = 'b';
        lineStyle           % string, specifies the color and style of the vertical lines.
        lineColor           % color of the two side lines.
        lineWidth           % scalar, defines the width of the vertical lines.
        displayFcn          % handle of the display function, returning an info string: str = f(roi).
                            % Default: @(roi) num2str(roi.width, '%5.2f').
%         displayPosition    % 4-vector of [left top height width] parameters of the display box. Default: [.7 .85 .1 .1]
    end

    properties(Hidden)
        color_hl = 'g'
        alpha_frozen = .1
        color_frozen = 'b'
        lineColor_frozen
        lineWidth_frozen = 2
        lineStyle_frozen = ':'
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
        roiDeleted
    end
        
    methods
        %% Constructor
        function roi = iROI(interval)
            
            % Defaults:
%             roi.lineStyle = '-';
%             roi.lineColor = [.5 .5 .5];
%             roi.lineWidth = 2;
%             roi.displayPosition = [.65 .85 .1 .1];
            roi.tag = 'roi';
            roi.flags.roiPlotOn = false;
            roi.flags.hl = false;
            roi.flags.frozen = false;
            if nargin == 0
                interval = [];
            end
            
            % Display function:
            roi.displayFcn = @(roi) num2str(roi.width, '%5.2f');
            if roi.is_valid_handle('hax') && isa(roi.handles.hax.XAxis, 'matlab.graphics.axis.decorator.DatetimeRuler')
                roi.displayFcn = @(roi) datestr(roi.width, 'MM:SS');
            end            

            % Range initialization:
            if ~isempty(interval)
                roi.init(interval);
                roi.init_plot();
            else
                roi.store_window_callbacks();
                roi.handles.ilines(1) = ixline(roi.handles.hax, []);
                addlistener(roi.handles.ilines(1), 'lineCreated', @(src,evt) roi.ginput_end(src,evt));
            end
        end
        
        %% Destructor
        function delete(roi)
            delete(roi.handles.ilines);
            if roi.is_valid_handle('rect'), delete(roi.handles.rect); end
            if roi.is_valid_handle('infotext'), delete(roi.handles.infotext); end
            notify(roi, 'roiDeleted');
        end

        %% Init
        function init(roi, interval)
            roi.handles.ilines(1) = ixline(roi.handles.hax, interval(1));
            roi.handles.ilines(2) = ixline(roi.handles.hax, interval(2));
        end

        function create_context_menu(roi)
            roi.handles.cm = uicontextmenu;
            roi.handles.cmenu(1) = uimenu(roi.handles.cm, 'Label', 'Zoom', 'tag', 'zoom_xlim_in', 'checked', 'off', 'callback', @(src,evt) roi.zoominout(src,evt));
            roi.handles.cmenu(end+1) = uimenu(roi.handles.cm, 'Label', 'View data', 'tag', 'switch_roi_plot', 'checked', 'off', 'callback', @(src,evt) roi.switch_roi_viewdata(src,evt));
            roi.handles.cmenu(end+1) = uimenu(roi.handles.cm, 'Label', 'Peaks Finder', 'checked', 'off', 'callback', @(src,evt) roi.roi_peaks_finder());
            roi.handles.cmenu(end+1) = uimenu(roi.handles.cm, 'Label', 'Freeze', 'tag', 'roi_freeze', 'checked', 'off', 'Separator', 'on', 'callback', @(src,evt) roi.freeze());
            roi.handles.cmenu(end+1) = uimenu(roi.handles.cm, 'Label', 'Export to workspace', 'checked', 'off', 'Separator', 'off', 'callback', @(src,evt) roi.export_to_workspace());
            roi.handles.cmenu(end+1) = uimenu(roi.handles.cm, 'Label', 'Delete', 'tag', 'delete', 'checked', 'off', 'callback', @(src,evt) roi.delete());
            set(roi.handles.rect, 'UIContextMenu', roi.handles.cm);
        end
        
        function init_plot(roi)
            hold(roi.handles.hax, 'on');
            roi.handles.rect = fill(roi.vertices(:,1), roi.vertices(:,2), roi.color, 'FaceAlpha', roi.alpha);
            hold(roi.handles.hax, 'off');

            roi.display_info();
            
            % Interactivity:
            set(roi.handles.rect, 'ButtonDownFcn', @(src,evt) roi.rect_bdcb(src,evt));
            addlistener(roi.handles.ilines, 'positionChanged', @(src,evt) roi.update() );
            addlistener(roi, 'color', 'PostSet', @(src,evt) roi.rect_postset_cb());
            addlistener(roi, 'alpha', 'PostSet', @(src,evt) roi.rect_postset_cb());
            addlistener(roi, 'lineColor', 'PostSet', @(src,evt) set(roi.handles.ilines, 'color', roi.lineColor));
            addlistener(roi, 'lineWidth', 'PostSet', @(src,evt) set(roi.handles.ilines, 'lineWidth', roi.lineWidth));
            addlistener(roi, 'lineStyle', 'PostSet', @(src,evt) set(roi.handles.ilines, 'lineStyle', roi.lineStyle));

            % Context menu:
            roi.create_context_menu();

            % Init line params:
            roi.lineStyle = roi.handles.ilines(1).lineStyle;
            roi.lineWidth = roi.handles.ilines(1).lineWidth;
            roi.lineColor = roi.handles.ilines(1).color;
            roi.lineColor_frozen = roi.lineColor;

            % Notification:
            notify(roi,'plotCreated');
        end
        
        %% Interactions 
        function ginput_end(roi, ~, ~)
            roi.handles.ilines(2) = ixline(roi.handles.hax, roi.handles.ilines(1).Value);
            roi.init_plot();
            click_evt = struct('Button', 1);
            roi.handles.ilines(2).bdcb([], click_evt);
            roi.handles.listeners = event.listener(roi.handles.ilines(2), 'buttonUp', @(src,evt) roi.roi_created_cb(src,evt));
        end

        function roi_created_cb(roi, ~, ~)
            roi.restore_window_callbacks();
            delete(roi.handles.listeners(end));
            roi.handles.listeners(end) = [];
            notify(roi, 'roiCreated');
        end

        % button down callback
        function rect_bdcb(roi,~,evt)
            if evt.Button ~= 1, return; end
            dx = roi.interval_num(1) - roi.currentPoint(1);
            roi.store_window_callbacks();
            set(roi.handles.hfig, 'windowButtonMotionFcn', @(src,evt) wbmcb(roi,src,evt, dx),...
                                  'windowButtonUpFcn',     @(src,evt) wbucb(roi,src,evt),...
                                  'pointer', 'left');
        end
                
        % window button motion callback
        function wbmcb(roi,~,~, dx)
            roi_width = diff(roi.interval_num);
            roi.handles.ilines(1).Value = roi.currentPoint(1) + dx;
            roi.handles.ilines(2).Value = roi.handles.ilines(1).Value + roi_width;
        end
        
        % window button up callback
        function wbucb(roi,~,~)
            roi.restore_window_callbacks();
            notify(roi, 'buttonUp');
        end
        
        %% ROI update
        function update(roi)
            set(roi.handles.rect, 'XData', roi.vertices(:,1), 'YData', roi.vertices(:,2));
            set(roi.handles.infotext, 'Position', roi.vertices([2,6]), 'String', roi.displayFcn(roi));
            if roi.flags.roiPlotOn
                roi.view_data();
            end
            notify(roi, 'roiChanged');
        end
        
        %% Annotation & Appeal
        function display_info(roi)
            roi.handles.infotext = text(roi.vertices(2,1), roi.vertices(2,2), roi.displayFcn(roi), 'FontSize', 16);
        end
        
        function highlight(roi, clr)
            if nargin == 1, clr = roi.color_hl; end
            if islogical(clr)
                if clr == false 
                    if roi.flags.hl
                        roi.color = roi.cache.color;
                        roi.flags.hl = false;
                        return
                    else
                        return
                    end
                else
                    clr = roi.color_hl;
                end
            end
            if ~roi.flags.hl, roi.cache.color = roi.color; end
            roi.color = clr;
            roi.flags.hl = true;
        end
    end

    %% RoI operations
    methods
        % Check which elements of v fall within roi's interval. 
        function ind = within(roi, v)
            ind = within(ruler2num(v, roi.handles.hax.XAxis), roi.interval_num);
        end

        function view_data(roi)
            if ~roi.is_valid_handle('roiview_plot')
                T = [ 1 0 0 0;
                      0 1 0 -.5;
                      0 0 1 0;
                      0 0 0 .5 ];
                hfig = figure('OuterPosition', get(roi.handles.hfig, 'OuterPosition')*T');
                roi.handles.roiview_plot = plot(roi.data.x, roi.data.y);
                roi.handles.roiview_hax = roi.handles.roiview_plot.Parent;
                title(roi.handles.roiview_hax, sprintf('ROI: %s', range(roi.interval)), roi.interval);
                grid on, box on, axis tight;
                iAxes.set_keyboard_shortcuts(hfig);
                iAxes.set_interactions(roi.handles.roiview_hax);
                roi.handles.roiview_rlz     = iRulerz('x');
                roi.handles.roiview_roitool = iROI_tool;
            else
                set(roi.handles.roiview_plot, 'XData', roi.data.x, 'YData', roi.data.y);
                title(roi.handles.roiview_hax, sprintf('ROI: %s', range(roi.interval)), roi.interval);
            end
        end
    
        function roi_peaks_finder(roi)
            if roi.is_valid_handle('peaksFinder') && roi.handles.peaksFinder.flags.done
                roi.handles.peaksFinder.init_plot();
            else
                roi.handles.peaksFinder = iPeaksFinder(roi.data.y, roi.data.x);
                roi.handles.peaksFinder.handles.Parent = roi;
                addlistener(roi, 'roiChanged', @(src,evt) roi.handles.peaksFinder.invalidate());
            end
        end
    end

    %% Setters & Getters
    methods
        function val = get.interval_num(roi)
            val = [roi.handles.ilines.Value];
        end

        function val = get.interval(roi)
            val = num2ruler(roi.interval_num, roi.handles.hax.XAxis);
        end

        function val = get.vertices(roi)
            ylims = get(roi.handles.hax, 'YLim');
            val = [roi.interval_num([1 2 2 1]); ylims([1 1 2 2])]';
        end

        function val = get.width(roi)
            val = diff(num2ruler(roi.interval_num, roi.handles.hax.XAxis));
        end

        function val = get.width_num(roi)
            val = diff(roi.interval_num);
        end

        function data = get.data(roi)
            l = arrayfilter(@(a) isa(a, 'matlab.graphics.chart.primitive.Line'), roi.handles.hax.Children);
            if isempty(l)
                data = [];
                return;
            end
            ind  = roi.within(l(1).XData);
            data = struct('x', vec(l.XData(ind)), 'y', vec(l.YData(ind)));
        end
    
    end
    %% Callbacks
    methods
        function switch_roi_viewdata(roi, src, ~)
            src.Checked = ifthel(src.Checked == "on", "off", "on");
            if src.Checked == "on"
                roi.flags.roiPlotOn = true;
                roi.view_data();
            else
                roi.flags.roiPlotOn = false;
            end
        end

        function zoominout(roi, src, ~)
            src.Checked = ifthel(src.Checked == "on", "off", "on");
            if src.Checked == "on"
                roi.cache.xlims = roi.handles.hax.XAxis.Limits;
                xlim(roi.handles.hax, interval_resize(roi.interval, 1.1));
            else
                xlim(roi.handles.hax, roi.cache.xlims);
            end
        end

        function freeze(roi, force)
            if nargin == 1, force = false; end
            cmitem = findall(roi.handles.cmenu, 'tag', 'roi_freeze');
            if cmitem.Checked == "on" && force, return; end
            cmitem.Checked = ifthel(cmitem.Checked == "on", "off", "on");
            if cmitem.Checked == "on" 
                set(roi.handles.rect, 'ButtonDownFcn', []);
                roi.handles.ilines(1).freeze();
                roi.handles.ilines(2).freeze();
                % Store lines properties:
                roi.cache.lineWidth = roi.lineWidth;
                roi.cache.lineColor = roi.lineColor;
                roi.cache.lineStyle = roi.lineStyle;
                % Change line appearance to indicate the frozen status:
                roi.lineStyle = roi.lineStyle_frozen;
                roi.lineWidth = roi.lineWidth_frozen;
                roi.flags.frozen = true;
            else
                set(roi.handles.rect, 'ButtonDownFcn', @(src,evt) roi.rect_bdcb(src,evt));
                roi.handles.ilines(1).freeze();
                roi.handles.ilines(2).freeze();
                % Restore the previous line appearance:
                roi.lineWidth = roi.cache.lineWidth;
                roi.lineStyle = roi.cache.lineStyle;
                roi.flags.frozen = false;
            end
        end

        function rect_postset_cb(roi, ~, ~)
            roi.handles.rect.FaceColor = roi.color;
            roi.handles.rect.FaceAlpha = roi.alpha;
        end
    end
end


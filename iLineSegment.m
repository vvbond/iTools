classdef iLineSegment < iTool
% Interactive (straight for now) line segment.
%
% Example:
% 1) Define a straight line segment interactively:
%  figure, axis(axis*5);  iseg = iLineSegment()
% 2) Create a segment programmatically:
%  figure, axis(axis*10); iseg = iLineSegment([1 2; 6 9]);
%                         iseg = iLineSegment([iPoint([1,8]), iPoint([8,1])]);  
% 3) Mix of the above:
%  figure, axis(axis*10); iseg = iLineSegment(iPoint([5,5]));
%
% See also: iPoint.                disp('setting color');

    properties(Dependent)
        len
        slope
        xrng
        yrng
        xdata
        ydata
    end

    properties(SetObservable)
        cpt                 % 2-vector of control iPoints (instances of iPoint).
        marker = 'o'
        lineWidth = 3       % line width.
        lineColor           % line color.
        lineStyle           % line style.
    end
        
    events
        segmentCreated
        sizeChanged
    end
    
    %% {Con,De}structor
    methods
        function iseg = iLineSegment(varargin)
        % Create a line segment in 2D.
        %
        % Usage:    iseg = iLineSegment
        %           iseg = iLineSegment(cpt)
        %           iseg = iLineSegment(lineSpec)
        %           iseg = iLineSegment(cpt, lineSpec)
        %
        % INPUT:
        %  none     - create a straight line segment in the current figure.
        %  cpt      - control points. Either a k-vector of iPoints or 
        %             a 2-by-k array of [x; y] coordintates of k control points.
        %             If k = 1, the remaining control point is specified interactively.
        %  lineSpec - string specifying line color, widht, style and marker.  
        %             E.g., '3b--d'.
        %
        % Examples:
        %
        %  figure, axis(axis*5);  iseg = iLineSegment() 
        %  figure, axis(axis*10); iseg = iLineSegment(iPoint([4,5])); 
        %  figure, axis(axis*10); iseg = iLineSegment([iPoint([4,5]), iPoint([9,2])]); 
        %                         iseg2 = iLineSegment(iseg.cpt(2));
        %
        % See also: iPoint.
        
            cpt = iPoint.empty();
            if nargin 
                for ii=1:nargin
                    val = varargin{ii};
                    if isa(val, 'iPoint') && numel(val) <= 2
                        cpt = val;
                    elseif isa(val, 'iLineSegment')
                        cpt = val.cpt(2);
                        iseg.lineColor = val.lineColor;
                        iseg.marker = val.marker;
                        iseg.lineStyle = val.lineStyle;
                        iseg.lineWidth = val.lineWidth;
                    elseif isnumeric(val) && ismatrix(val) && size(val,2) <= 2
                        for k=1:size(val,2)
                            cpt(k) = iPoint(val(:,k)); %#ok<*AGROW>
                        end
                    elseif ischar(val)
                        [iseg.lineColor, iseg.lineStyle, iseg.lineWidth, iseg.marker] = iTool.parse_line_spec(val);
                    end
                end
            end
            
            if isempty(cpt)
                iseg.cpt = iPoint(iseg.marker);
                iseg.cpt.refCount = iseg.cpt.refCount + 1;
                addlistener(iseg.cpt, 'plotCreated', @(src,evt) iseg.ginput_end());
            elseif numel(cpt) == 1
                iseg.cpt = cpt;
                iseg.cpt.refCount = iseg.cpt.refCount + 1;
                iseg.ginput_end();
            else
                iseg.cpt = cpt;
                iseg.cpt(1).refCount = iseg.cpt(1).refCount + 1;
                iseg.cpt(2).refCount = iseg.cpt(2).refCount + 1;
                iseg.init_plot;
            end
        end
        
        function delete(iseg)
            for ii = 1:2
                iseg.cpt(ii).refCount = iseg.cpt(ii).refCount - 1;
                if iseg.cpt(ii).refCount <= 0
                    delete(iseg.cpt(ii));
                end
            end
            delete(iseg.handles.line);
            delete(iseg.handles.listeners);
        end
    end        
    
    %% Plotting
    methods
        function init_plot(iseg)
            
            if isempty(iseg.handles) || ~iseg.is_valid_handle('hfig')
                iseg.handles.hfig = gcf;
                iseg.handles.hax = gca;
            end
            % Plot the line:
            figure(iseg.handles.hfig);
            hold on
            iseg.handles.line = plot(iseg.xdata, iseg.ydata, 'LineWidth', iseg.lineWidth);
            if ~isempty(iseg.lineColor)
                set(iseg.handles.line, 'color', iseg.lineColor);
            else
                iseg.lineColor = iseg.handles.line.Color;
            end
            if ~isempty(iseg.lineStyle)
                set(iseg.handles.line, 'LineStyle', iseg.lineStyle);
            else
                iseg.lineStyle = iseg.handles.line.LineStyle;
            end
            set(iseg.cpt, 'color', iseg.lineColor);

            addlistener(iseg, 'marker',    'PostSet', @(src,evt) marker_PostSet_cb(iseg, src, evt));
            addlistener(iseg, 'lineColor', 'PostSet', @(src,evt) color_PostSet_cb(iseg, src, evt) );
            addlistener(iseg, 'lineWidth', 'PostSet', @(src,evt) width_PostSet_cb(iseg, src, evt) );
            addlistener(iseg, 'lineStyle', 'PostSet', @(src,evt) style_PostSet_cb(iseg, src, evt) );

            % Plot the control points, if not already plotted:
            for ii=1:2
                try 
                    if isempty(iseg.cpt(ii).handles.point.Parent) || isempty(iseg.cpt(ii).handles.point.Parent.Parent)
                        iseg.cpt(ii).init_plot(); 
                    end
                catch
                    iseg.cpt(ii).init_plot();
                end
                uistack(iseg.cpt(ii).handles.point, 'top');
            end
            
            % Interaction with the line segment:
            set(iseg.handles.line, 'ButtonDownFcn', @(src,evt) bdcb(iseg,src,evt));
            % Listeners:
            iseg.handles.listeners    = event.listener(iseg.cpt, 'positionChanged', @(src,evt) iseg.update_plot() );
            iseg.handles.listeners(2) = event.listener(iseg.cpt, 'positionChanged', @(src,evt) notify(iseg, 'sizeChanged'));
            
            % Context menu:
            iseg.handles.cm = uicontextmenu;
            iseg.handles.cmenu(1) = uimenu(iseg.handles.cm, 'Label', 'Delete', 'tag', 'delete', 'checked', 'off', 'callback', @(src,evt) iseg.delete());
            set(iseg.handles.line, 'UIContextMenu', iseg.handles.cm);

            % Notify others:
            notify(iseg, 'plotCreated');
        end
        
        function update_plot(iseg)
            set(iseg.handles.line, 'xdata', iseg.xdata, 'ydata', iseg.ydata);
        end
    end
    
    %% Computations
    methods
        function p = resample(iseg, dx)
            n = floor(iseg.xrng/dx);
            p = iseg.cpt(1) + dx*(1:n).*[1; iseg.slope];
        end
        
        function export_sample_points(iseg, dx, fname, writeMode)
            if nargin < 4, writeMode = 'append'; end
            p = iseg.resample(dx);
            writematrix(p', fname, 'WriteMode', writeMode);
        end
    end
    
    %% Interaction
    methods     
        function bdcb(iseg, ~, evt)
        % Line button down callback.
            if iseg.flags.debug == true
                disp('Line down');
            end
            if evt.Button ~= 1
                return;
            end
            
            iseg.cache.currentPoint = iseg.currentPoint;
            % Store old interaction callbacks:
            iseg.cache.hfig.WindowButtonMotionFcn  = get(iseg.handles.hfig, 'WindowButtonMotionFcn');
            iseg.cache.hfig.WindowButtonUpFcn      = get(iseg.handles.hfig, 'WindowButtonUpFcn');
            
            % Set new interaction callbacks:
            set(iseg.handles.hfig, 'WindowButtonMotionFcn', @(src,evt) wbmcb(iseg, src, evt),...
                                   'WindowButtonUpFcn',     @(src,evt) wbucb(iseg, src, evt));
        end
        
        function wbmcb(iseg, ~, ~)
        % Window button motion callback.
            dp = iseg.currentPoint - iseg.cache.currentPoint;
            iseg.cpt(1).p = iseg.cpt(1).p + dp;
            iseg.cpt(2).p = iseg.cpt(2).p + dp;
            iseg.cache.currentPoint = iseg.currentPoint;
        end
        
        function wbucb(iseg, ~,~)
            % Restore the old interaction callbacks:
            set(iseg.handles.hfig, 'WindowButtonMotionFcn', iseg.cache.hfig.WindowButtonMotionFcn,...
                                   'WindowButtonUpFcn',     iseg.cache.hfig.WindowButtonUpFcn);
        end 
    end   
    
    %% Auxiliary methods
    methods(Hidden)        
        function ginput_end(iseg, ~, ~)
            iseg.cpt(2) = iPoint(iseg.cpt(1).p, iseg.marker);
            iseg.cpt(2).refCount = iseg.cpt(2).refCount + 1;
            iseg.init_plot();
            iseg.cpt(2).bdcb();
            % Segment created notifier:
            iseg.handles.listeners(end+1) = event.listener(iseg.cpt(2), 'buttonUp', @(src,evt) iseg.segment_created_cb());
        end
        
        function segment_created_cb(iseg,~,~)
            delete(iseg.handles.listeners(end));
            iseg.handles.listeners(end) = [];
            notify(iseg, 'segmentCreated');
        end
        
        function marker_PostSet_cb(iseg, ~, ~)
            set(iseg.cpt, 'marker', iseg.marker);
        end
        
        function color_PostSet_cb(iseg, ~, ~)
            set(iseg.handles.line, 'color', iseg.lineColor);
        end
        
        function width_PostSet_cb(iseg, ~, ~)
            set(iseg.handles.line, 'LineWidth', iseg.lineWidth);
        end

        function style_PostSet_cb(iseg, ~, ~)
            set(iseg.handles.line, 'LineStyle', iseg.lineStyle);
        end
    end
    
    %% Setters/Getters
    methods
        function val = get.xdata(iseg)
            val = [iseg.cpt(1).p(1) iseg.cpt(2).p(1)];
        end

        function val = get.ydata(iseg)
            val = [iseg.cpt(1).p(2) iseg.cpt(2).p(2)];
        end
        
        function val = get.xrng(iseg)
            val = abs(diff(iseg.xdata));
        end
        
        function val = get.yrng(iseg)
            val = abs(diff(iseg.ydata));
        end

        function val = get.len(iseg)
            if isa(iseg, 'iRectangle')
                val = 2*( iseg.xrng + iseg.yrng );
            elseif isa(iseg, 'iLineSegment')
                val = sqrt(iseg.xrng^2 + iseg.yrng^2);
            end
        end
        
        function val = get.slope(iseg)
            val = diff(iseg.ydata)/diff(iseg.xdata);
        end        
    end
    
    %% Save & load
    methods (Access = protected)
        function iseg_ = copyElement(iseg)
            iseg_ = copyElement@matlab.mixin.Copyable(iseg);
            iseg_.cpt = copy(iseg.cpt);
            iseg_.handles.hfig = [];
            iseg_.handles.hax = [];
            iseg_.handles.line = [];
            iseg_.handles.listeners = [];
        end
    end

    methods (Static)
        function iseg = loadobj(iseg)
            arrayfun(@(p) p.add_position_listeners(), iseg.cpt);
        end
    end
end
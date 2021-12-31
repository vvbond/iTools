classdef iRectangle < iLineSegment
    methods
        function delete(irec)
            delete@iLineSegment(irec);
            if irec.is_valid_handle('himg') && isfield(irec.cache, 'himg') && isfield(irec.cache.himg, 'HitTest')
                irec.handles.himg.HitTest = irec.cache.himg.HitTest;
            end
            if irec.is_valid_handle('hax') && isfield(irec.cache, 'hax') && isfield(irec.cache.hax, 'ButtonDownFcn')
                irec.handles.hax.ButtonDownFcn = irec.cache.hax.ButtonDownFcn;
            end
        end
    end
    methods
        function init_plot(irec)
            
            % Plot the line:
            figure(irec.handles.hfig);
            hold on
            irec.handles.line = [ plot(irec.xdata([1 1]), irec.ydata, 'LineWidth', irec.lineWidth)
                                  plot(irec.xdata([2 2]), irec.ydata, 'LineWidth', irec.lineWidth)
                                  plot(irec.xdata, irec.ydata([1 1]), 'LineWidth', irec.lineWidth)
                                  plot(irec.xdata, irec.ydata([2 2]), 'LineWidth', irec.lineWidth)
                                 ];
            
            if ~isempty(irec.lineColor)
                set(irec.handles.line, 'color', irec.lineColor);
            end
            if ~isempty(irec.lineStyle)
                set(irec.handles.line, 'LineStyle', irec.lineStyle);
            end

            addlistener(irec, 'lineColor', 'PostSet', @(src,evt) color_PostSet_cb(irec, src, evt) );
            addlistener(irec, 'lineWidth', 'PostSet', @(src,evt) width_PostSet_cb(irec, src, evt) );
            addlistener(irec, 'lineStyle', 'PostSet', @(src,evt) style_PostSet_cb(irec, src, evt) );

            % Plot the control points, if not already plotted:
            for ii=1:2
                try 
                    if isempty(irec.cpt(ii).handles.point.Parent) || isempty(irec.cpt(ii).handles.point.Parent.Parent)
                        irec.cpt(ii).init_plot(); 
                    end
                catch
                    irec.cpt(ii).init_plot();
                end
                uistack(irec.cpt(ii).handles.point, 'top');
            end
            
            % Interaction with the line segment:
            set(irec.handles.line, 'ButtonDownFcn', @(src,evt) bdcb(irec,src,evt));
            irec.cache.hax.ButtonDownFcn = irec.handles.hax.ButtonDownFcn;
            set(irec.handles.hax,  'ButtonDownFcn', @(src,evt) bdcb(irec,src,evt));
            % Listeners:
            irec.handles.listeners    = event.listener(irec.cpt, 'positionChanged', @(src,evt) irec.update_plot() );
            irec.handles.listeners(2) = event.listener(irec.cpt, 'positionChanged', @(src,evt) notify(irec, 'sizeChanged'));            
                        
            % Disable HitTest for images:
            irec.handles.himg = findobj(irec.handles.hax, 'type', 'image');
            if ~isempty(irec.handles.himg)
                irec.cache.himg.HitTest = irec.handles.himg.HitTest;
                irec.handles.himg.HitTest = "off";
            end
            
            % Context menu:
            irec.handles.cm = uicontextmenu;
            irec.handles.cmenu(1) = uimenu(irec.handles.cm, 'Label', 'Delete', 'checked', 'off', 'callback', @(src,evt) irec.delete());
            set(irec.handles.line, 'UIContextMenu', irec.handles.cm);

            % Notify interested parties:
            notify(irec, 'plotCreated');
        end
        
        function update_plot(irec)
            set(irec.handles.line(1), 'xdata', irec.xdata([1 1]), 'ydata', irec.ydata);
            set(irec.handles.line(2), 'xdata', irec.xdata([2 2]), 'ydata', irec.ydata);
            set(irec.handles.line(3), 'xdata', irec.xdata, 'ydata', irec.ydata([1 1]));
            set(irec.handles.line(4), 'xdata', irec.xdata, 'ydata', irec.ydata([2 2]));
        end
        
        function bdcb(irec, src, evt)
            if evt.Button ~= 1
                return;
            end
            if isa(src, 'matlab.graphics.axis.Axes') &&...
               irec.currentPoint(1) > irec.xdata(1) && irec.currentPoint(1) < irec.xdata(2) &&...
               irec.currentPoint(2) > irec.ydata(1) && irec.currentPoint(2) < irec.ydata(2)
                irec.cache.lineIx = 0;
                bdcb@iLineSegment(irec, src, evt);
            elseif isa(src, 'matlab.graphics.chart.primitive.Line')
%                 irec.cache.lineIx = find(src == irec.handles.line);
                irec.cache.lineIx = 0;
                bdcb@iLineSegment(irec, src, evt);
            end
        end
        
        function wbmcb(irec, ~, ~)
            dp = irec.currentPoint - irec.cache.currentPoint;
            switch irec.cache.lineIx
                case 0
                    irec.cpt(1).p = irec.cpt(1).p + dp;
                    irec.cpt(2).p = irec.cpt(2).p + dp;
                case 1
                    irec.cpt(1).p(1) = irec.cpt(1).p(1) + dp(1);
                case 3
                    irec.cpt(1).p(2) = irec.cpt(1).p(2) + dp(2);
                case 2
                    irec.cpt(2).p(1) = irec.cpt(2).p(1) + dp(1);
                case 4
                    irec.cpt(2).p(2) = irec.cpt(2).p(2) + dp(2);
            end
            irec.cache.currentPoint = irec.currentPoint;
        end        
    end
    %% Setters & Getters
    methods
    end
end
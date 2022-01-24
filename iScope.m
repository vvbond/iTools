classdef iScope < iTool
    properties(SetObservable)
        data
        marker = '.'
        markerSize = 10
    end
    properties
        accessorfcn         % returns 2-by-k cell array of x-y coordinates in k channels.
                            % E.g., for k = 1 return {x; y},
                            %       for k = 2 return {x1, x2; y1, y2}. 
    end
    methods
        function scope = iScope(data, accessorFcn)
            scope.data = data;
            scope.accessorfcn = accessorFcn;
            scope.init_plot();
            scope.handles.listeners = addlistener(scope, 'data', 'PostSet', @(src,evt) scope.update());
            scope.handles.listeners.Enabled = false;
            addlistener(scope, 'marker', 'PostSet', @(src,evt) scope.init_plot());
            addlistener(scope, 'markerSize', 'PostSet', @(src,evt) scope.init_plot());
        end

        function delete(scope)
            if scope.is_valid_handle('hfig'), delete(scope.handles.hfig); end
        end

        function init_plot(scope)
            xy = scope.accessorfcn(scope.data);
            figure(scope.handles.hfig);
            scope.handles.hax = gca;
            scope.handles.hplot = plot(xy{:});
            for i = 1:length(scope.handles.hplot)
                hplot = scope.handles.hplot(i);
                set(hplot, 'Marker', scope.marker, 'MarkerFaceColor', hplot.Color, 'MarkerSize', scope.markerSize);
            end
            grid on, box on
        end

        function update(scope)
            if isempty(scope.data), return; end
            xy = scope.accessorfcn(scope.data);
            for i = 1:length(scope.handles.hplot)
                scope.handles.hplot(i).XData = xy{1,i};
                scope.handles.hplot(i).YData = xy{2,i};
            end
        end

        function listen(scope, val)
            if nargin == 1, val = true; end
            scope.handles.listeners(1).Enabled = val;
        end
    end
end
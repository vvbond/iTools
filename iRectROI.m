classdef  iRectROI < iRectangle
    properties(Dependent)
        data
        cols
        rows
    end
    %% {Con,De}structor
    methods
        function roi = iRectROI()
            roi = roi@iRectangle();
            addlistener(roi, 'plotCreated', @(src, evt) roi.init_roi() );
        end
        
        function delete(roi)
            delete@iRectangle(roi);
        end
        
        function init_roi(roi)
            if is_valid_handle(roi, 'himg')
                himg = roi.handles.himg;
                if ~all([length(himg.YData), length(himg.XData)] == size(himg.CData))
                    warning('iRectROI: cannot determine data spacing.');
                else
                    roi.cache.himg.dx = diff(himg.XData(1:2));
                    roi.cache.himg.dy = diff(himg.YData(1:2));
                    roi.cache.himg.origin_x = himg.XData(1);
                    roi.cache.himg.origin_y = himg.YData(1);
                end
                roi.cache.himg.size = size(himg.CData);
                roi.cache.himg.origin_x = himg.XData(1);
                roi.cache.himg.origin_y = himg.YData(1);                
                
                % Add a context menu:
                roi.handles.cmenu(2) = uimenu(roi.handles.cm, 'Label', 'View data', 'checked', 'off', 'callback', @(src,evt) roi.toggle_data_view());
                
                % Flags:
                roi.flags.dataview.enabled = false;
            end
        end
    end
    %% Data view
    methods
        function init_data_view(roi)
            roi.handles.datafig = figure('Name', sprintf('ROI: %s', roi.handles.hfig.Name),...
                                         'NumberTitle', 'off', ...
                                         'Position', roi.handles.hfig.Position.*[1 1 .5 .5]);
            roi.handles.dataimg = imagesc(roi.cols, roi.rows, roi.data);
            set(roi.handles.dataimg.Parent, 'Colormap', roi.handles.hax.Colormap,...
                                            'CLim', roi.handles.hax.CLim,...
                                            'YDir', roi.handles.hax.YDir);
            axis tight;
            iTool.add_tools(roi.handles.datafig);
        end
        
        function view_data(roi)
            if ~is_valid_handle(roi, 'datafig') || ~is_valid_handle(roi, 'dataimg')
                roi.init_data_view();
                return;
            end
            set(roi.handles.dataimg, 'XData', roi.cols, 'YData', roi.rows, 'CData', roi.data);
        end        
        
        function toggle_data_view(roi)
            if roi.flags.dataview.enabled
                delete(roi.handles.dataview_listener);
                roi.flags.dataview.enabled = false;
                roi.handles.cmenu(2).Checked = 'off';
            else
                roi.view_data();
                roi.handles.dataview_listener = listener(roi, 'sizeChanged', @(src,evt) roi.view_data() );
                roi.flags.dataview.enabled = true;
                roi.handles.cmenu(2).Checked = 'on';
            end
        end
    end
    %% Setters & Getters
    methods
        function val = get.cols(roi)
            lims = round( (sort(roi.xdata) - roi.cache.himg.origin_x) / roi.cache.himg.dx ) + 1;
            val = max(1,lims(1)):min(lims(2),roi.cache.himg.size(2));
        end
        
        function val = get.rows(roi)
            lims = round( (sort(roi.ydata) - roi.cache.himg.origin_y) / roi.cache.himg.dy ) + 1;
            val = max(1,lims(1)):min(lims(2),roi.cache.himg.size(1));
        end
        
        function val = get.data(roi)
            val = roi.handles.himg.CData(roi.rows, roi.cols);
        end
    end
end
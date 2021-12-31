classdef iRuler < iTool
    properties
        lseg
    end
    %% {Con,De}structor
    methods
        function rlr = iRuler(hfig)
            if nargin == 0, hfig = gcf; end
            rlr = rlr@iTool('iRulerBtn', hfig);
            
            % Quit if the button already there:
            if ~isempty(rlr.handles.hButton), return; end
            
            % Add a toolbar toggle button:
            ht = findall(rlr.handles.hfig, 'Type', 'uitoolbar');
            if isempty(ht)
                warning('iRuler: figure toolbar not found.'); 
                return;
            end
            rlrIcon = load(fullfile(fileparts(mfilename('fullpath')),'/icons/rulerIcon_triangular.mat'));
            rlr.handles.hButton = uitoggletool(ht(1),  'OnCallback', @(src,evt) ON(rlr,src,evt),...
                                            'OffCallback',@(src,evt) OFF(rlr,src,evt),...
                                            'CData', rlrIcon.cdata, ...
                                            'TooltipString', 'Interactive ruler', ...
                                            'Tag', rlr.tag,... 
                                            'Separator', 'on',...
                                            'UserData', rlr);
        end
        
        function delete(rlr)
%             rlr.OFF();
        end
          
    end
    %% Interacives
    methods
        function ON(rlr,~,~)
            rlr.interactivesOff(rlr.handles.hfig);
            rlr.lseg = iLineSegment();    
            addlistener(rlr.lseg, 'plotCreated', @(src,evt) rlr.init_plot());
        end
        
        function init_plot(rlr)
            % Add side lines:
            rlr.handles.sides(1) = plot(rlr.lseg.xdata([1 1]), rlr.lseg.ydata, '--');
            rlr.handles.sides(2) = plot(rlr.lseg.xdata(), rlr.lseg.ydata([2 2]), '--');
            % Add text:
            rlr.handles.text(1) = text(rlr.lseg.xdata(1) + diff(rlr.lseg.xdata)/2,...
                                       rlr.lseg.ydata(1) + diff(rlr.lseg.ydata)/2,...
                                       sprintf('%3.2f', rlr.lseg.len));
            rlr.handles.text(2) = text(rlr.lseg.xdata(1) + diff(rlr.lseg.xdata)/2,...
                                       rlr.lseg.ydata(2),...
                                       sprintf('%3.2f', diff(rlr.lseg.xdata) ));
            rlr.handles.text(3) = text(rlr.lseg.xdata(1),...
                                       rlr.lseg.ydata(1) + diff(rlr.lseg.ydata)/2,...
                                       sprintf('%3.2f', diff(rlr.lseg.ydata) ));
            % Bring control points on top:
            uistack(rlr.lseg.cpt(1).handles.point, 'top'); 
            uistack(rlr.lseg.cpt(2).handles.point, 'top');
            
            % Add another listeners for control points and side lines:
            addlistener(rlr.lseg.cpt, 'positionChanged', @(src,evt) pChange_cb(rlr,src,evt));
            set(rlr.handles.sides, 'ButtonDownFcn', @(src,evt) lbdcb(rlr,src,evt));
            
            % UI panel:
            panelH = 60; panelW = 300; % [px]
            hght = 20; wdth = [60 80]; 
            rlr.handles.info = rlr.create_info_panel(panelW, panelH, wdth, hght);            
        end
        
        function OFF(rlr,~,~)
            delete(rlr.lseg);
            delete(rlr.handles.sides);
            delete(rlr.handles.text);
            delete(rlr.handles.info.label);
            delete(rlr.handles.info.text);
            delete(rlr.handles.info.panel); 
        end
        
        function pChange_cb(rlr,~,~)
            % Update sides:
            set(rlr.handles.sides(1), 'xdata', rlr.lseg.xdata([1 1]), 'ydata', rlr.lseg.ydata);
            set(rlr.handles.sides(2), 'xdata', rlr.lseg.xdata, 'ydata', rlr.lseg.ydata([2 2]));
            
            % Update text:
            set(rlr.handles.text(1),... 
                'Position', [rlr.lseg.xdata(1) rlr.lseg.ydata(1) 0] + [diff(rlr.lseg.xdata)/2  diff(rlr.lseg.ydata)/2 0],...
                'String', sprintf('%3.2f', rlr.lseg.len));
            set(rlr.handles.text(2),...
                'Position', [rlr.lseg.xdata(1) + diff(rlr.lseg.xdata)/2, rlr.lseg.ydata(2), 0],...
                'String', sprintf('%3.2f', diff(rlr.lseg.xdata) ));
            set(rlr.handles.text(3),...
                'Position', [rlr.lseg.xdata(1), rlr.lseg.ydata(1) + diff(rlr.lseg.ydata)/2, 0],...
                'String', sprintf('%3.2f', diff(rlr.lseg.ydata) ));
            
            % Update info panel:
            rlr.update_info();
        end
        
        % Line button down callback.
        function lbdcb(rlr, src, ~)
            sideIx = find(rlr.handles.sides == src);
            rlr.cache.currentPoint = rlr.lseg.currentPoint;
            % Store old interaction callbacks:
            rlr.store_window_callbacks();
            
            % Set new interaction callbacks:
            set(rlr.handles.hfig, 'WindowButtonMotionFcn', @(src,evt) wbmcb(rlr, sideIx, src, evt),...
                          'WindowButtonUpFcn',     @(src,evt) rlr.restore_window_callbacks(src,evt));
        end
        
        % Window button motion callback.
        function wbmcb(rlr, dimIx, ~, ~)
            dp = rlr.lseg.currentPoint - rlr.cache.currentPoint;
            rlr.lseg.cpt(dimIx).p(dimIx) = rlr.lseg.cpt(dimIx).p(dimIx) + dp(dimIx);
            rlr.cache.currentPoint = rlr.lseg.currentPoint;
        end        
    end
    %% Helper
    methods
        function info = create_info_panel(rlr, W, H, w, h)
            
            top = [.5 .2]*H-h/2;
            left = 0 + [0 sum(w)];
            
            info.panel    = uipanel('Title', 'Ruler', 'Units', 'pixels', 'Position', [0 0 W H]);
            info.label(1) = uicontrol(info.panel, 'Style', 'text', 'Units', 'pixels', 'Position', [left(1) top(1) w(1) h], 'string', 'x-range');
            info.label(2) = uicontrol(info.panel, 'Style', 'text', 'Units', 'pixels', 'Position', [left(1) top(2) w(1) h], 'string', 'y-range');
            info.label(3) = uicontrol(info.panel, 'Style', 'text', 'Units', 'pixels', 'Position', [left(2) top(1) w(1) h], 'string', 'length');
            info.label(4) = uicontrol(info.panel, 'Style', 'text', 'Units', 'pixels', 'Position', [left(2) top(2) w(1) h], 'string', 'slope');
            
            info.text(1) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',... 
                                                'Units', 'pixels', 'Position', [left(1)+w(1) top(1) w(2) h],... 
                                                'String', sprintf('%3.2f', rlr.lseg.xrng));
            info.text(2) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',...
                                                'Units', 'pixels', 'Position', [left(1)+w(1) top(2) w(2) h],... 
                                                'String', sprintf('%3.2f', rlr.lseg.yrng));
            info.text(3) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',... 
                                                'Units', 'pixels', 'Position', [left(2)+w(1) top(1) w(2) h],... 
                                                'String', sprintf('%3.2f', rlr.lseg.len));
            info.text(4) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',...
                                                'Units', 'pixels', 'Position', [left(2)+w(1) top(2) w(2) h],... 
                                                'String', sprintf('%3.2f', rlr.lseg.slope));
        end
        
        function update_info(rlr)
            set(rlr.handles.info.text(1), 'String', sprintf('%3.2f', rlr.lseg.xrng));
            set(rlr.handles.info.text(2), 'String', sprintf('%3.2f', rlr.lseg.yrng));
            set(rlr.handles.info.text(3), 'String', sprintf('%3.2f', rlr.lseg.len));
            set(rlr.handles.info.text(4), 'String', sprintf('%3.2f', rlr.lseg.slope));                        
        end
    end
end
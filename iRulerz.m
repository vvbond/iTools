classdef iRulerz < iTool
%% Interactive tool for measuring distances along x- and/or y-axes.
    properties(SetObservable)
        xx      % 2-vector of x-coordinates for the two vertical lines.
        yy      % 2-vector of y-coordinates for the two horizontal lines. 
    end
    properties
        axis        % 'x' (or 1) for x-lines only;
                    % 'y' (or 2) for y-lines only;
                    % otherwise - both x- and y-lines are displayed.
        lColor  % lines color.
        lStyle  % lines style.
        lWidth  % lines width.
        annotationPosition  % position of the annotation box.
        annotationBgColor   % background color of the annotation box.
        bmfun = {};
    end
    
    properties(Hidden = true)
        clickPoint
        lineIx      % index of the "clikcked" (selected) line.
        hBtn        % handle of the toggle button.
        hlines      % handles of the ruler lines.
        hInfoBox    % handle of the annotation text box.
    end
    
    events
        axisChange
    end

%% Methods    
    methods
        %% Constructor
        function rlz = iRulerz(raxis, hfig)
            
            % Parse input:
            if nargin < 2, hfig = gcf; end
            if nargin < 1, raxis = 'xy'; end
            rlz = rlz@iTool('rulerzBtn', hfig);
            
            rlz.axis = raxis;
            
            % Quit if the button already there:
            if ~isempty(rlz.hBtn), return; end
            
            % Add a toolbar toggle button:
            ht = findall(rlz.handles.hfig, 'Type', 'uitoolbar');
            if isempty(ht)
                warning('Rulerz: figure toolbar not found.'); 
                return;
            end

            switch raxis
                case {1, 'x'}
                    rlzIcon = load(fullfile(fileparts(mfilename('fullpath')),'/icons/RulerzX.mat'));
                case {2, 'y'}
                    rlzIcon = load(fullfile(fileparts(mfilename('fullpath')),'/icons/RulerzY.mat'));
                otherwise
                    rlzIcon = load(fullfile(fileparts(mfilename('fullpath')),'/icons/Rulerz.mat'));
            end

            rlz.hBtn = uitoggletool(ht(1),  'OnCallback', @(src,evt) ON(rlz,src,evt),...
                                            'OffCallback',@(src,evt) OFF(rlz,src,evt),...
                                            'CData', rlzIcon.cdata, ...
                                            'TooltipString', 'X-/Y- rulers', ...
                                            'Tag', rlz.tag,... 
                                            'Separator', 'on',...
                                            'UserData', rlz);
            rlz.lColor = [.5 .5 .5];
            rlz.lStyle = '--';
            rlz.lWidth = 2;
            rlz.annotationBgColor = [.95 .95 .95];
            rlz.annotationPosition = [0 .1 .1 .1];

            % Add listeners:
            addlistener(rlz, 'axisChange', @(src, evt) axisChangeEvt(rlz,src,evt));
            addlistener(rlz, 'xx', 'PostSet', @(src, evt) xx_PostSet_cb(rlz,src,evt));
            addlistener(rlz, 'yy', 'PostSet', @(src, evt) yy_PostSet_cb(rlz,src,evt));
        end
        
        %% Destructor
        function delete(rlz)
            if ishandle(rlz.hBtn)
                set(rlz.hBtn, 'State', 'off');
                delete(rlz.hBtn);
            end
        end
    end
    
%% Setter methods
    methods 
        function set.axis(rlz, val)
        % Monitor the axis change and set the appropriate icon to the toolbar.
            rlz.axis = val;
            notify(rlz, 'axisChange');
        end
    end
%% Hidden methods handling user interactions
    methods(Hidden = true) 
        %% Rulerz ON:
        function ON(rlz, ~, ~)
        % Display ruler lines.
            
            rlz.handles.hax = gca;
            % Define x- and y- coordinates of the ruler lines:            
            xlims = get(rlz.handles.hax,'xlim')';
            ylims = get(rlz.handles.hax,'ylim')';

            dx = diff(xlims);
            dy = diff(ylims);
            if isempty(rlz.xx) || any(~within(rlz.xx, xlims))
                rlz.xx = xlims(1)+[1 2]./3*dx;
            end
            if isempty(rlz.yy) || any(~within(rlz.yy, ylims))
                rlz.yy = ylims(1)+[1 2]./3*dy; % lines position [x1 x2 y1 y2].
            end
            
            % Plot lines:
            hold on;
            switch rlz.axis
                case {1, 'x'}
                    rlz.hlines = [ixline(rlz.xx(1)); ixline(rlz.xx(2))];
                case {2, 'y'}
                    rlz.hlines = [iyline(rlz.yy(1)); iyline(rlz.yy(2))];
                otherwise
                    rlz.hlines = [iAxisLine(rlz.xx(1)) iAxisLine(rlz.yy(1),2)
                                  iAxisLine(rlz.xx(2)) iAxisLine(rlz.yy(2),2) ];
            end
            xlim(xlims);
            ylim(ylims);
            
            % Info panel:
            W = 300; H = 60; h = 20; % [px].
            w = [40 80 80 80 80]; % [label edit edit edit].
            rlz.handles.info = rlz.create_info_panel(W,H,w,h);
                        
            % Store current axis button down function:
            rlz.cache.abdcb = get(rlz.handles.hax, 'ButtonDownFcn');
                                  
            % Set lines interaction callback:
            rlz.interactivesOff(rlz.handles.hfig);
            addlistener(rlz.hlines, 'positionChanged', @(src,evt) rlz.lbmcb(src,evt));
            set(rlz.handles.hax,    'ButtonDownFcn', @(src,evt) abdcb(rlz, src, evt));
            
            % Disable hit test for images:
            himgs = findall(rlz.handles.hax, 'type', 'Image');
            for himg = himgs(:)'
                himg.HitTest = 'off';
            end
        end
        
        %% Rulerz OFF:
        function OFF(rlz, ~, ~)
            delete(rlz.hlines);
            delete(findall(gcf, 'tag', 'rulerzInfo'));
            
            % Restore callbacks:
            rlz.handles.hfig.SizeChangedFcn = rlz.cache.sizeChangedFcn;
            if ishandle(rlz.handles.hax) && isvalid(rlz.handles.hax)
                set(rlz.handles.hax, 'ButtonDownFcn', rlz.cache.abdcb);
            end
        end
        
        %% Interaction callbacks:        
        function lbmcb(rlz,src,~)
        % Line button motion callback.    
            lix = find(rlz.hlines == src);
            switch rlz.axis
                case {1,'x'}
                    rlz.xx(lix) = src.Value;
                case {2,'y'}
                    rlz.yy(lix) = src.Value;
                otherwise
                    if lix < 3
                        rlz.xx(lix) = src.Value;
                    else
                        rlz.yy(lix-2) = src.Value;
                    end
            end
        end
        
        function wbmcb(rlz, ~, ~)
        % Window button motion callback.
            if rlz.lineIx % a ruler line was clicked
                cpos = get(rlz.handles.hax, 'CurrentPoint');
                cxpos = cpos(1,1); % cursor x position.
                cypos = cpos(1,2); % cursor x position.
                
                xydata = [ get(rlz.hlines(rlz.lineIx), 'xdata')' get(rlz.hlines(rlz.lineIx), 'ydata')' ]; 
                
                switch find(diff(xydata)==0)
                    case 1
                        rlz.xx(rlz.lineIx) = cxpos;
                    case 2
                        ix = rlz.lineIx-(rlz.lineIx>2)*2;
                        rlz.yy(ix) = cypos;
                end
            else % the click was made in the area within the rulers.
                dp = rlz.currentPoint - rlz.clickPoint;
                rlz.xx = rlz.cache.xx + dp(1);
                rlz.yy = rlz.cache.yy + dp(2);
            end
            
            % Execute external mouse movement functions:
            for ii=1:length(rlz.bmfun)
                rlz.bmfun{ii}(rlz);
            end
        end

        function wbucb(rlz,~,~)
        % Window button up callback.
            rlz.lineIx = 0;
            % Restore the old interaction callbacks:
            rlz.restore_window_callbacks();
        end
        
        function abdcb(rlz, ~, ~)
            rlz.clickPoint = rlz.currentPoint;
            rlz.cache.xx = rlz.xx;
            rlz.cache.yy = rlz.yy;
            rlz.lineIx = 0;
            if within(rlz.clickPoint(1), rlz.xx) || within(rlz.clickPoint(2), rlz.yy)
                % Store old interaction callbacks:
                rlz.store_window_callbacks();
                
                % Set interaction functions:
                set(gcf, 'windowButtonMotionFcn', @(src,evt) wbmcb(rlz,src,evt),...
                         'windowButtonUpFcn',     @(src,evt) wbucb(rlz,src,evt),...
                         'pointer', 'fleur');
            end
        end        
        
        %% Info string:
        function s = infoString(rlz)
            switch rlz.axis
                case {1, 'x'}
                    s = { ['    x_1    ', '    x_2    ', '    dx    '],...
                           sprintf('%8.2f %8.2f %8.2f', rlz.xx(1), rlz.xx(2), abs(diff(rlz.xx))) };
                case {2, 'y'}
                    s = {  ['    y_1    ', '    y_2    ', '    dy    '],...
                           sprintf('%8.2f %8.2f %8.2f', rlz.yy(1), rlz.yy(2), abs(diff(rlz.yy)))};
                otherwise
                    s = { ['    x_1    ', '    x_2    ', '    dx    '],...
                           sprintf('%8.2f %8.2f %8.2f', rlz.xx(1), rlz.xx(2), abs(diff(rlz.xx))),...
                          ['    y_1    ', '    y_2    ', '    dy    '],...
                           sprintf('%8.2f %8.2f %8.2f', rlz.yy(1), rlz.yy(2), abs(diff(rlz.yy)))};
            end
        end
        
        %% Listeners
        function axisChangeEvt(rlz, ~, ~)   
            % Turn off the current ruler:
            if ishandle(rlz.hBtn)
                set(rlz.hBtn, 'state', 'off');
                % Update the icon:
                switch lower(rlz.axis)
                    case {1, 'x'}
                        rlzIcon = load(fullfile(fileparts(mfilename('fullpath')),'/icons/RulerzX.mat'));
                    case {2, 'y'}
                        rlzIcon = load(fullfile(fileparts(mfilename('fullpath')),'/icons/RulerzY.mat'));
                    otherwise
                        rlzIcon = load(fullfile(fileparts(mfilename('fullpath')),'/icons/Rulerz.mat'));
                end
                set(rlz.hBtn, 'CData', rlzIcon.cdata);
            end
        end
        
        function xx_PostSet_cb(rlz, ~, ~)
            if isempty(rlz.hlines) || strcmpi(rlz.axis, 'y'), return; end
            
            if isvalid(rlz.hlines(1)) && isvalid(rlz.hlines(2)) 
                rlz.hlines(1).Value = rlz.xx(1);
                rlz.hlines(2).Value = rlz.xx(2);
            end
            
            % Update info panel:
            rlz.update_info();
        end

        function yy_PostSet_cb(rlz, ~, ~)
            if isempty(rlz.hlines) || strcmpi(rlz.axis, 'x'), return; end
            
            if strcmpi(rlz.axis, 'y')
                lIx = 1;
            elseif numel(rlz.hlines) > 2
                lIx = 3;
            else
                lIx = 0;
            end
            
            if lIx
                for kk = 0:1
                    if isvalid(rlz.hlines(lIx+kk))
                        rlz.hlines(lIx+kk).Value = rlz.yy(kk+1);
                    end
                end
            end            
            % Update info:
            rlz.update_info();
        end
        
    end
        %% Helper
    methods
        function info = create_info_panel(rlz, W, H, w, h)
        % Create an ui panel with labels and edit field in it.
        %
        % W, H - panel width and height scalar values.
        % w, h - items width and height vectors.
        
            top = [.5 .2]*H-h/2;
            left = [0 cumsum(w)];
            
            fpos = get(rlz.handles.hfig, 'Position');
            info.panel    = uipanel('Title', 'Rulerz', 'Units', 'pixels', 'Position', [0 fpos(4)-H W H], 'Tag', 'rulerzInfo');
            rlz.cache.sizeChangedFcn = get(rlz.handles.hfig, 'SizeChangedFcn');
            rlz.handles.hfig.SizeChangedFcn = @(src,evt) set(rlz.handles.info.panel, 'Position', [0 src.Position(4)-H W H]);
            
            % First row:
            info.label(1) = uicontrol(info.panel, 'Style', 'text', 'Units', 'pixels', 'Position', [left(1) top(1) w(1) h], 'string', 'x');
            info.text(1) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',... 
                                                'Units', 'pixels', 'Position', [left(2) top(1) w(2) h],... 
                                                'String', sprintf('%3.2f', rlz.xx(1)));
            info.text(2) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',...
                                                'Units', 'pixels', 'Position', [left(3) top(1) w(3) h],... 
                                                'String', sprintf('%3.2f', rlz.xx(2)));
            info.text(3) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',...
                                                'Units', 'pixels', 'Position', [left(4) top(1) w(4) h],... 
                                                'String', sprintf('%3.2f', range(rlz.xx)));
            % Second row:                                
            info.label(2) = uicontrol(info.panel, 'Style', 'text', 'Units', 'pixels', 'Position', [left(1) top(2) w(1) h], 'string', 'y');
            info.text(4) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',... 
                                                'Units', 'pixels', 'Position', [left(2) top(2) w(2) h],... 
                                                'String', sprintf('%3.2f', rlz.yy(1)));
            info.text(5) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',...
                                                'Units', 'pixels', 'Position', [left(3) top(2) w(3) h],... 
                                                'String', sprintf('%3.2f', rlz.yy(2)));
            info.text(6) = uicontrol(info.panel, 'Style', 'edit', 'Enable', 'inactive',...
                                                'Units', 'pixels', 'Position', [left(4) top(2) w(4) h],... 
                                                'String', sprintf('%3.2f', range(rlz.yy)));            
        end
        
        function update_info(rlz)
            if isfield(rlz.handles, 'info') && isfield(rlz.handles.info, 'panel') && isvalid(rlz.handles.info.panel)
                set(rlz.handles.info.text(1), 'String', sprintf('%3.2f', rlz.xx(1)));
                set(rlz.handles.info.text(2), 'String', sprintf('%3.2f', rlz.xx(2)));
                set(rlz.handles.info.text(3), 'String', sprintf('%3.2f', range(rlz.xx)));
                set(rlz.handles.info.text(4), 'String', sprintf('%3.2f', rlz.yy(1)));
                set(rlz.handles.info.text(5), 'String', sprintf('%3.2f', rlz.yy(2)));
                set(rlz.handles.info.text(6), 'String', sprintf('%3.2f', range(rlz.yy)));
            end
        end
    end
end
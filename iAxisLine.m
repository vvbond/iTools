classdef iAxisLine < iTool
% Interactive constant line.
%
% Usage:
%  iAxisLine(val)
%  iAxisLine(val, dim)
%  iAxisLine(val, dim, key-value pairs);
%
% Examples:
%  figure, imagesc(peaks(100)); il = iAxisLine(45); % Default dim = 1.
%  figure, imagesc(peaks(100)); il = iAxisLine(45, 2);
%  figure, imagesc(peaks(100)); il = iAxisLine(45, 2, 'LineWidth', 2, 'Color', 'r');

    properties(SetObservable)
       Value
       Label
    end
    properties(Hidden)
        dim
        keyvals
        pointers = {'left', 'top'}
    end
    properties(Dependent)
        xlims
        ylims
    end
    events
        lineCreated
    end
    methods
        function ial = iAxisLine(varargin)
            ial = ial@iTool('iAxisLine', gcf);

            % Defaults:
            val = [];
            dim = 1;
            keyvals = {};

            % Parse input:
            nargix = 1;
            % optional axes handle input:
            if nargin && isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ial.handles.hax = varargin{1};
                ial.handles.hfig = ial.handles.hax.Parent;
                nargix = 2;
            end
            % value input:
            if nargin >= nargix
                val = varargin{nargix}; 
                nargix = nargix + 1;
            end
            % dimension input:
            if nargin >= nargix
                dim = varargin{nargix};
                nargix = nargix + 1;
            end
            % parse key-value pairs:
            if nargin >= nargix
                keyvals = varargin(nargix:end);
            end

            % Init:
            ial.dim = dim;
            ial.keyvals = keyvals;
            addlistener(ial, 'Value', 'PostSet', @ial.set_value_cb);

            % If val is empty, specify it interactively:
            if isempty(val)
                ial.ginput_begin();
            else
                ial.init(val);
            end
        end
        
        function delete(ial)
            if isfield(ial.handles, 'iline'), delete(ial.handles.iline); end
            if isfield(ial.handles, 'linkListener')
                delete(ial.handles.linkListener);
            end
            % Restore axes settings:
            if ishandle(ial.handles.hax) && isvalid(ial.handles.hax)
                ial.handles.hax.PickableParts = ial.cache.axesPickableParts;
            end
        end
        
        function init(ial, val)
            switch ial.dim
                case {1, 'x'}
                    ial.Value = ruler2num(val, ial.handles.hax.XAxis);
                case {2, 'y'}
                    ial.Value = ruler2num(val, ial.handles.hax.YAxis);    
                otherwise
                    error('iAxisLine: unknown axis parameter %s', ial.dim);
            end
        end

        function init_plot(ial, keyvals)
            if nargin == 1, keyvals = ial.keyvals; end
            switch ial.dim
                case {1, 'x'}
                    ial.handles.iline = xline(ial.handles.hax, ial.Value, keyvals{:}); 
                case {2, 'y'}
                    ial.handles.iline = yline(ial.handles.hax, ial.Value, keyvals{:});
                otherwise
                    error('iAxisLine: unknown axis parameter %s', ial.dim);
            end
            ial.Label = ial.value_to_string(ial.Value);

            % Activate the axis:
            ial.cache.axesPickableParts = ial.handles.hax.PickableParts;
            ial.handles.hax.PickableParts = 'visible';
            axes(ial.handles.hax);
            
            set(ial.handles.iline, 'ButtonDownFcn', @ial.bdcb, 'UserData', ial, 'Tag', ial.tag);
            addlistener(ial, 'Label', 'PostSet', @ial.set_label_cb);
            
            % Context menu:
            cm = uicontextmenu(ial.handles.hfig);
            uimenu(cm, 'Label', 'Refresh links', 'Callback', @ial.update_context_menu);
            uimenu(cm, 'Label', 'Link to', 'Enable', false);
            ial.handles.iline.UIContextMenu = cm;

            % Notification:
            notify(ial, 'plotCreated');
        end

        %% Interactivity
        function ginput_begin(ial)
            ial.cache.hfig.Pointer = ial.handles.hfig.Pointer;
            ial.cache.hax.ButtonDownFcn = ial.handles.hax.ButtonDownFcn;
            ial.handles.himg = findobj(ial.handles.hax, 'type', 'image');
            if ~isempty(ial.handles.himg)
                ial.cache.himg.HitTest = ial.handles.himg.HitTest;
                ial.handles.himg.HitTest = "off";
            end
                
            ial.handles.hfig.Pointer = "hand";
            ial.handles.hax.ButtonDownFcn = @(src,evt) ial.set('Value', ial.currentPoint(ial.dim));
            addlistener(ial, 'plotCreated', @(src, evt) ial.ginput_end());
        end
        
        function ginput_end(ial)
            % Restore everything:
            ial.handles.hfig.Pointer = ial.cache.hfig.Pointer;
            ial.handles.hax.ButtonDownFcn = ial.cache.hax.ButtonDownFcn;            
            if ~isempty(ial.handles.himg)
                ial.handles.himg.HitTest = ial.cache.himg.HitTest;
            end
            notify(ial, 'lineCreated');
        end

        function bdcb(ial, ~, evt)
        % Line button down callback.    
            if evt.Button == 1 % left click
                ial.store_window_callbacks();
                set(ial.handles.hfig, 'windowButtonMotionFcn', @ial.wbmcb,...
                                      'windowButtonUpFcn',     @ial.wbucb,...
                                      'Pointer', ial.pointers{ial.dim});
            elseif evt.Button == 3 % right click.
                 
            end
        end
        
        function wbucb(ial, ~, ~)
        % Line button up callback.
            ial.restore_window_callbacks();
            notify(ial, 'buttonUp');
        end
        
        function wbmcb(ial,~,~)
            ial.Value = ial.currentPoint(ial.dim);
        end
        
        function set_value(ial, val)
            ial.Value = val;
        end
        
        function set_value_cb(ial,~,~)
            if ial.is_valid_handle('iline')
                ial.handles.iline.Value = ial.Value;
                ial.Label = ial.value_to_string(ial.Value);
            else
                ial.init_plot();
            end
            notify(ial,'positionChanged');
        end
        
        function set_label_cb(ial,~,~)
            ial.handles.iline.Label = ial.Label;
        end
        
        function link(ial, ial2, isMutual)
        % Link the value of an other axis line to the value of this one. 
            narginchk(2,3);
            if nargin == 2, isMutual = false; end
            ial.handles.linkListener = addlistener(ial2, 'positionChanged', @(src,evt) ial.set_value(src.Value));
            if isMutual
                ial2.link(ial);
            end
        end
        
        function update_context_menu(ial,~,~)
        % Populate context menu with instances of iAxisLine objects.
            menuItems = ial.handles.iline.UIContextMenu.Children;
            delete(menuItems(1).Children);
            
            ialines = iTool.find(ial.tag, 'all');
            ialines(ialines == ial) = [];
            if isempty(ialines)
                menuItems(1).Enable = false;
            else
                for it = ialines(:)'
                    uimenu(menuItems(1), 'Label', sprintf('%d: %s', it.hfig.Number, it.hfig.Name), 'Callback', @(src,evt) ial.link(it, true));
                end
                menuItems(1).Enable = true;
            end            
        end
        
        function whoami(ial)
            class(ial)
        end

        function s = value_to_string(ial, val, precision)
            narginchk(2,3);
            if ial.dim == 1
                val = num2ruler(val, ial.handles.hax.XAxis);
            else
                val = num2ruler(val, ial.handles.hax.YAxis);
            end
            if nargin == 2 
                if isnumeric(val)
                    precision = 3; 
                elseif isdatetime(val)
                    precision = 'MM:SS';
                end
            end
            if isnumeric(val)
                s = num2str(val, precision);
            elseif isdatetime(val)
                s = datestr(val, precision);
            end    
        end

        %% Getters
        function val = get.xlims(ial)
            val = ial.handles.hax.XAxis.Limits;
        end
        
        function val = get.ylims(ial)
            val = ial.handles.hax.YAxis.Limits;
        end
    end
end
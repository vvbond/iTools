classdef iPoint < iTool
% Interactive 2D point.
%
% Features:
%  drug-and-drop
%  change programmatically: position, marker, face color.
%
% Usage:
%  figure; axis(axis*10); ipt = iPoint;

    properties(SetObservable)
        p                   % 2-vector of [x;y] coordinates.
        marker = 'o'
        size = 6
        color
        faceColor
    end
    
    properties(Dependent)
        delta
    end
    
    properties(Hidden)
        refCount = 0
    end
        
    methods
        %% {Con,De}structor
        function ipt = iPoint(varargin)
        % Create interactive point in current figure.
        %
        % Usage:
        %  ipt = iPoint;
        %  ipt = iPoint(pos);
        %  ipt = iPoint(markerSpec);
        %  ipt = iPoint(pos, markerSpec);
                              
            ipt.flags.debug = false;
            ipt.add_position_listeners();
            p = [];
            if nargin == 0
                p = [];
            else
                for ii=1:nargin
                    val = varargin{ii};
                    if isempty(val), continue; end
                    if isnumeric(val)
                        p = val;
                    elseif ischar(val)
                        [ipt.color, ~, ipt.size, ipt.marker] = iTool.parse_line_spec(val);
                    end
                end
            end
            ipt.p = p;
            ipt.cache.p = ipt.p;
            if isempty(ipt.p)
                ipt.ginput_begin();
            end
        end
        
        function delete(ipt)
            try
                delete(ipt.handles.point);
            end
        end
    end
    
    %% Operators overloading
    methods
        function d = double(ipt)
            d = ipt.p;
        end
        
        function r = plus(obj1, obj2)
            a = double(obj1);
            b = double(obj2);
            r = a + b;
        end
        
        function r = minus(obj1, obj2)
            a = double(obj1);
            b = double(obj2);
            r = a - b;
        end
        
        function r = times(obj1, obj2)
            a = double(obj1);
            b = double(obj2);
            r = a .* b;
        end
        
        function r = mtimes(obj1, obj2)
            a = double(obj1);
            b = double(obj2);
            r = a * b;
        end
    end
    
    %% Setters & Getters
    methods
        function set.p(ipt, val)
            if ~isempty(val) && (~isvector(val) || numel(val)~=2) 
                error('Value must be a 2-vector.'); 
            end
            ipt.p = val(:);
        end
        
        function set.marker(ipt, val)
            lMarkers = '\+|o|\*|\.|x|s|d|\^|>|<|v|p|h|';
            [~,~,~, theMarker] = regexp(val, lMarkers, 'once');
            if ~isempty(theMarker)
                ipt.marker = theMarker;
            end            
        end
        
        function set.color(ipt, val)
            if ~isempty(val)
                ipt.color = val;
            end            
        end

        function val = get.delta(ipt)
            val = ipt.p - ipt.cache.p;
        end
    end
    
    %% Plotting
    methods
        function init_plot(ipt)
            
            % Announce initialization of plotting:
            % TODO: why does this event exist?
            notify(ipt, 'plotInit');
            
            if isempty(ipt.handles) || ~ipt.is_valid_handle('hfig')
                ipt.handles.hfig = gcf;
                ipt.handles.hax = gca;
            end
                
            figure(ipt.handles.hfig); 
            hold on
            ipt.handles.point = plot(ipt.p(1), ipt.p(2), ipt.marker);
            hold off
            
            % Interactive callbacks:
            set(ipt.handles.point, 'ButtonDownFcn', @(src,evt) bdcb(ipt, src, evt));
            addlistener(ipt, 'marker',    'PostSet', @(src,evt) marker_PostSet_cb(ipt, src, evt) );
            addlistener(ipt, 'size',      'PostSet', @(src,evt) size_PostSet_cb(ipt, src, evt) );            
            addlistener(ipt, 'color',     'PostSet', @(src,evt) color_PostSet_cb(ipt, src, evt) );
            addlistener(ipt, 'faceColor', 'PostSet', @(src,evt) faceColor_PostSet_cb(ipt, src, evt) );
                        
            % Announce plot completion:
            notify(ipt, 'plotCreated');
        end
        
        function updatePlot(ipt)
            set(ipt.handles.point, 'XData', ipt.p(1), 'YData', ipt.p(2));
        end
    end
       
    %% Interactivity
    methods(Hidden)
        function ginput_begin(ipt)
            ipt.cache.hfig.Pointer = ipt.handles.hfig.Pointer;
            ipt.cache.hax.ButtonDownFcn = ipt.handles.hax.ButtonDownFcn;
            ipt.handles.himg = findobj(ipt.handles.hax, 'type', 'image');
            if ~isempty(ipt.handles.himg)
                ipt.cache.himg.HitTest = ipt.handles.himg.HitTest;
                ipt.handles.himg.HitTest = "off";
            end
                
            ipt.handles.hfig.Pointer = "cross";
            ipt.handles.hax.ButtonDownFcn = @(src,evt) ipt.set('p', ipt.currentPoint);
            addlistener(ipt, 'plotInit', @(src, evt) ipt.ginput_end());
        end
        
        function ginput_end(ipt)
            % Restore everything:
            ipt.handles.hfig.Pointer = ipt.cache.hfig.Pointer;
            ipt.handles.hax.ButtonDownFcn = ipt.cache.hax.ButtonDownFcn;            
            if ~isempty(ipt.handles.himg)
                ipt.handles.himg.HitTest = ipt.cache.himg.HitTest;
            end            
        end

        function bdcb(ipt, ~, evt)
        % Point's button down callback.    
        
            if ipt.flags.debug
                disp('down');
            end
            
            if nargin > 1 &&  evt.Button ~= 1
                if evt.Button == 3
                    notify(ipt, 'buttonDownRight');
                end
                return;
            end
            
            % Store current window interaction callbacks.
            % but not own callbacks:
            if ipt.is_valid_handle('hfig') &&...
               ( isempty(ipt.handles.hfig.WindowButtonMotionFcn) ||...
                 ~strcmp(func2str(ipt.handles.hfig.WindowButtonMotionFcn), '@(src,evt)wbmcb(ipt,src,evt)') )
                ipt.store_window_callbacks();
            end
            
            % Set new interaction callbacks:
            set(ipt.handles.hfig, 'WindowButtonMotionFcn', @(src,evt) wbmcb(ipt, src, evt),...
                                  'WindowButtonUpFcn',     @(src,evt) wbucb(ipt, src, evt));
            notify(ipt, 'buttonDownLeft');
        end
        
        function wbmcb(ipt, ~,~)
        % Window button motion callback.
            cpos = get(gca, 'CurrentPoint');
            ipt.p = cpos(1,1:2)';
            if ipt.flags.debug
                disp(ipt.p);
            end
        end
        
        function wbucb(ipt, ~,~)
        % Window button up callback.
            if ipt.flags.debug, disp('up'); end
            % Restore the previous window interaction callbacks:
            ipt.restore_window_callbacks();
            notify(ipt, 'buttonUp');
        end
        
        %% Listeners
        function add_position_listeners(ipt)
            addlistener(ipt, 'p', 'PreSet',  @(src,evt) p_PreSet_cb(ipt, src, evt));
            addlistener(ipt, 'p', 'PostSet', @(src,evt) p_PostSet_cb(ipt, src, evt) );
        end
        
        function p_PreSet_cb(ipt, ~, ~)
            ipt.cache.p = ipt.p;
            if ipt.flags.debug
                disp(ipt.cache.p);
            end
        end

        function p_PostSet_cb(ipt, ~, ~)
            if ipt.is_valid_handle('point')
                ipt.updatePlot;
            elseif ~isempty(ipt.p)
                ipt.init_plot();
            else
                return;
            end
            notify(ipt, 'positionChanged');
        end
        
        function marker_PostSet_cb(ipt, ~, ~)
            set(ipt.handles.point, 'marker', ipt.marker);
        end
        
        function size_PostSet_cb(ipt, ~, ~)
            set(ipt.handles.point, 'markerSize', ipt.size);
        end
        
        function color_PostSet_cb(ipt, ~, ~)
            if ~isempty(ipt.color)
                set(ipt.handles.point, 'color', ipt.color);
            end
        end
 
        function faceColor_PostSet_cb(ipt, ~, ~)
            set(ipt.handles.point, 'MarkerFaceColor', ipt.faceColor);
        end
    end
            
    %% Save & load
%     methods (Access = protected)
%         function ipt_ = copyElement(ipt)
%             ipt_ = copyElement@matlab.mixin.Copyable(ipt);
%             ipt_.handles.hfig = [];
%             ipt_.handles.hax = [];
%             ipt_.handles.point = [];
%         end
%     end
%     methods
%         function ipt_ = saveobj(ipt)
%         % Define the object to save.
%         %
%         % Save a copy omitting handles. See copyElement function. 
%             ipt_ = copy(ipt);
%         end
%     end
    methods(Static)
        function ipt = loadobj(ipt)
            ipt.add_position_listeners();
        end
    end    
end
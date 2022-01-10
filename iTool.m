classdef iTool < matlab.mixin.Copyable
    properties
        tag
        flags
        meta
    end
    properties(Transient)
        handles
        cache       % temporary storage.
    end
    properties(Dependent)
        currentPoint
    end
    properties(Hidden, Constant)
        tagTable = table({'fPoker'; 'Rulerz'; 'iRuler'; 'iyline'; 'ixline'; 'iAxisLine'; 'iROI_tool'},... 
                         {'fpokerBtn'; 'rulerzBtn'; 'iRulerBtn'; 'iyline'; 'ixline'; 'iAxisLine'; 'iROI_tool'},... 
                         'VariableNames', {'Tool', 'Tag'});
    end

    events
        plotInit
        plotCreated
        positionChanged
        buttonDownLeft
        buttonDownRight
        buttonUp
    end

    
    methods
        %% Constructor
        function it = iTool(itag, hfig)
            
            % Parse input arguments:
            if nargin < 2, hfig = gcf; end
            if nargin < 1, itag = ''; end
            
            it.tag = itag;
            it.handles.hfig = hfig;
            it.flags.verbose = false;
            it.flags.debug = false;
            
%             % Check if the iTool is alreay added:
%             haxs = findall(it.handles.hfig, 'Type', 'Axes');
%             if ~isempty(haxs)
%                 it.handles.hax = haxs(1);
%             end
            it.handles.hax = get(it.handles.hfig, 'CurrentAxes');
            if ~isempty(it.tag)
                buttonTypes = {'matlab.ui.container.toolbar.ToggleTool', 'matlab.ui.container.toolbar.PushTool'};
                it.handles.hButton = findall(it.handles.hfig, 'Tag', it.tag);
                if ~isempty(it.handles.hButton) && numel(it.handles.hButton) == 1 && any(cellfun(@(tp) isa(it.handles.hButton, tp), buttonTypes))
                    it = it.handles.hButton.UserData;
                    if isa(it.handles.hButton, 'matlab.ui.container.toolbar.ToggleTool')
                        it.handles.hButton.State = 'off';
                    end
                end
            end
        end
        %% Interactives
        function store_window_callbacks(it, ~, ~)
        % Save some figure callback functions and properties.
        
            % Store old interaction callbacks:
            it.cache.hfig.WindowButtonMotionFcn = get(it.handles.hfig, 'WindowButtonMotionFcn');
            it.cache.hfig.WindowButtonUpFcn     = get(it.handles.hfig, 'WindowButtonUpFcn');
            it.cache.hfig.SizeChangedFcn        = get(it.handles.hfig, 'SizeChangedFcn');
            it.cache.hfig.Pointer               = get(it.handles.hfig, 'Pointer');
        end
        
        function restore_window_callbacks(it,~,~)
        % Window button up callback.
        
            % Restore the old interaction callbacks:
            set(it.handles.hfig, 'WindowButtonMotionFcn', it.cache.hfig.WindowButtonMotionFcn,...
                                 'WindowButtonUpFcn',     it.cache.hfig.WindowButtonUpFcn,...
                                 'SizeChangedFcn',        it.cache.hfig.SizeChangedFcn,...
                                 'Pointer',               it.cache.hfig.Pointer);
        end      
    %% Setters & Getters
        function val = get.currentPoint(it)
            cp = get(it.handles.hax, 'currentPoint');
            val = cp(1,1:2)';
        end 
        
        function set(its, prop, val)
            if isprop(its(1), prop)
                for it = its(:)'
                    it.(prop) = val;
                end
            end
        end
    end
    %% Helpers
    methods
        function tf = is_valid_handle(it, prop)
            tf = isfield(it.handles, prop) && ~isempty(it.handles.(prop)) && all(isvalid(it.handles.(prop)));
        end
        
        function parse_keyvals(it, varargin)
            if mod(length(varargin),2), error('%s: Number of key-value arguments must be even.', class(it)); end
            props = properties(it);
            for ii=1:2:length(varargin)
                key = varargin{ii};
                val = varargin{ii+1};
                
                propIx = find(strcmpi(key, props), 1);
                if isempty(propIx)
                    error('%s: unknown property name %s', class(it), key);
                end
                it.(props{propIx}) = val;
            end
        end 
    
        function export_to_workspace(it)
            export2wsdlg({'Variable name:'}, {it.tag}, {it});
        end
    end
    %% Static
    methods(Static)
        function interactivesOff(hfig)
        % Switch off interactive tools.
            curfig = gcf;
            figure(hfig)
            plotedit off, zoom off, pan off, rotate3d off, datacursormode off, brush off
            figure(curfig)
        end
        
        function escape(hfig)
        % Emergency: clear all interaction callbacks.
            if ishandle(hfig)                
                set(hfig, 'WindowButtonMotionFcn', [], ...
                          'WindowButtonUpFcn',     [], ... 
                          'WindowButtonDownFcn',   [], ...
                          'KeyPressFcn',           [], ...
                          'KeyReleaseFcn',         [] );
            end            
        end
        
        function [fp, rlz, rlr, icb] = add_tools(hfig)
        % Add iTools to the given figure.
            if nargin == 0, hfig = gcf; end
            fp = fPoker(hfig);
            rlz = Rulerz('xy', hfig);
            rlr = iRuler(hfig);
            icb = iColorBar(hfig);
        end
        
        function htool = find(toolName, where)
        % Find the handle of an iTool instance in given figure, or all figures.
        %
        % Usage: 
        %   htool = find(toolName)
        %   htool = find(toolName, figure_handle)
        %   htool = find(toolName, 'all')
            
            % Parse input:
            % Defaults:
            if nargin < 2, where = gcf; end
            
            if ischar(where) && strcmpi(where, 'all')
                hfigs = get(0,'Children');
            elseif all(ishandle(where))
                hfigs = where;
            end
                
            h = findall(hfigs, 'Tag', iTool.tagTable.Tag{strcmpi(iTool.tagTable.Tool, toolName)});
            htool = arrayfun(@(obj) obj.UserData, h);
        end
        
        function [itColor, itStyle, itWidth, itMarker] = parse_line_spec(spec)
        % Parse obj spec string.
        
            % get line style
            lStyles = '--|:|-\.|-';
            [~,~,~, itStyle] = regexp(spec, lStyles, 'once');
%             if isempty(lStyle), lStyle = '--'; end
            % get width
            [~,~,~, itWidth] = regexp(spec, '\d+', 'once');
            if isempty(itWidth) 
                itWidth = 1; 
            else
                itWidth = str2double(itWidth);
            end
            % get color
            lColors = 'y|m|c|r|g|b|w|k';
            [~,~,~, itColor] = regexp(spec, lColors, 'once');
%             if isempty(lColor), lColor = 'k'; end
            % get marker
            lMarkers = '\+|o|\*|\.|x|s|d|\^|>|<|v|p|h|';
            [~,~,~, itMarker] = regexp(spec, lMarkers, 'once');
%             if isempty(lMarker), lMarker = 'none'; end
        end        
    end

end
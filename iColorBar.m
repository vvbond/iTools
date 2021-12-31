classdef iColorBar < iTool
% Interactive colorbar.    
%
% Usage: iColorBar
% 
% Use the mouse to adjust the upper limit of the color axis;
% alternatively hold the 'Alt' key to alter caxis' lower limit,
% or hold the 'Shift' key to shift both lower and upper limits.
%
% Example:
%  figure, imagesc(peaks(100)); iColorBar
    properties(Hidden)
        hBtn
        htbar
        hcb
        caxPos
        fpos
        caxLims
        
        ctrlMode     % upperBound   - adjust the upper bound of caxis;
                     % lowerBound (Alt key)   - alter the lower limit of caxis;
                     % shift (Shift key) - shift both lower and upper limits.
        
        old_wbmcb
        old_wbucb
        old_fkpcb
        old_fkrcb
    end
    
    %% {Con,De}structor
    methods
        function icb = iColorBar(hfig)
            % Parse input:
            if nargin == 0
                hfig = gcf;
            end
            
            icb = icb@iTool('icolorbarBtn', hfig);
            if ~isempty(icb.hBtn), return; end
            
            % Defaults:
            icb.ctrlMode = iCtrl.upperBound;
            
            % Add toggle button:          
            icon_fname = 'icolorbarIcon.mat';
            icolorbarIcon = load(fullfile(fileparts(mfilename('fullpath')),'icons', icon_fname));
            icb.htbar = findall(icb.handles.hfig, 'Tag', 'FigureToolBar');
            if isempty(icb.htbar)
                warning('iColorBar: figure toolbar not found in the figure window. Cannot create the tool button.');
                return;
            end
            icb.hBtn = uitoggletool(icb.htbar(1),  'CData', icolorbarIcon.cdata, ...
                                                   'onCallback',  @(src,evt) icb.icbON(src,evt),...
                                                   'offCallback', @(src,evt) icb.icbOFF(src,evt),...
                                                   'Separator', 'off',...
                                                   'tooltipString', 'Insert interactive colorbar',...
                                                   'Tag', 'icolorbarBtn',...
                                                   'UserData', icb);
            % Re-order buttons:
            hBtns = findall(icb.htbar(1));
            dumIx = zeros(length(hBtns), 1);
            for ii=1:length(hBtns), dumIx(ii) = strcmpi(hBtns(ii).Tag, 'Annotation.InsertColorBar'); end
            cbarIx = find(dumIx);
            set(icb.htbar, 'children', [hBtns(3:cbarIx-1); hBtns(2); hBtns(cbarIx:end)]);                                               
        end
        
        function delete(icb)
        % Destructor.
        
            % Remove button:
            if ishandle(icb.hBtn), delete(icb.hBtn); end
                
            % Restore figure callbacks:
            if ishandle(icb.handles.hfig)    
                icb.interactivesOff(icb.handles.hfig);
                set(icb.handles.hfig, 'WindowButtonMotionFcn', icb.old_wbmcb, ...
                              'WindowButtonUpFcn',     icb.old_wbucb, ... 
                              'KeyPressFcn',           icb.old_fkpcb, ...
                              'KeyReleaseFcn',         icb.old_fkrcb );
            end
        end
    end
    
    %% ON/OFF
    methods
        function icbON(icb, ~, ~)
            
            icb.handles.hax = gca;
            % Find or create a colorbar:
            cbar = findobj(icb.handles.hfig, 'type', 'colorbar');
            if isempty(cbar)
                icb.hcb = colorbar;
                icb.hcb.Position(1) = .915;
            else
                icb.hcb = cbar;
            end
            
            % Switch off interactive modes:
            icb.interactivesOff(icb.handles.hfig);
            
            % Turn on interaction:
            set(icb.hcb,  'ButtonDownFcn', @(src,evt) bdcb(icb,src,evt));
        end
        
        function icbOFF(icb, ~, ~)
            
            % Turn off interaction:
            if ishandle(icb.hcb), set(icb.hcb,  'ButtonDownFcn', []); end
            
            % Restore figure callbacks:
            icb.interactivesOff(icb.handles.hfig);
            if ishandle(icb.handles.hfig)                
                set(icb.handles.hfig, 'WindowButtonMotionFcn', icb.old_wbmcb, ...
                              'WindowButtonUpFcn',     icb.old_wbucb, ... 
                              'KeyPressFcn',           icb.old_fkpcb, ...
                              'KeyReleaseFcn',         icb.old_fkrcb );
            end
        end
    end
    
    %% Interactions
    methods
        function bdcb(icb, ~, evt)
            if evt.Button ~= 1
                return;
            end

            set(icb.hcb, 'units', 'pixels');
            icb.caxPos = get(icb.hcb, 'position');
            set(icb.hcb, 'units', 'normalized');                    
            icb.fpos = get(gcf, 'currentPoint')*[0; 1] - icb.caxPos(2); % y coordinate [px].
            icb.caxLims = caxis(icb.handles.hax);
            
            % Store old interaction callbacks:
            icb.old_wbmcb  = get(gcf, 'WindowButtonMotionFcn');
            icb.old_wbucb  = get(gcf, 'WindowButtonUpFcn');
            icb.old_fkpcb  = get(gcf, 'KeyPressFcn');
            icb.old_fkrcb  = get(gcf, 'KeyReleaseFcn');
            
            % Set new interactions:
            set(icb.handles.hfig, 'WindowButtonMotionFcn', @(src,evt) wbmcb(icb, src, evt),...
                          'WindowButtonUpFcn',     @(src,evt) wbucb(icb, src, evt));
            set(icb.handles.hfig, 'KeyPressFcn',   @(src,evt) fkpcb(icb,src,evt), ...
                          'KeyReleaseFcn', @(src,evt) fkrcb(icb,src,evt) );                                  
        end
        
        function wbmcb(icb, ~, ~)
            fpos2 = (get(icb.handles.hfig,'currentPoint')*[0;1] - icb.caxPos(2));
            switch icb.ctrlMode
                case iCtrl.lowerBound  % alt: alter caxis lower limit.
                    caxNewMin = ( icb.caxLims(1)*(icb.caxPos(4)-icb.fpos) + icb.caxLims(2)*(icb.fpos - fpos2) )/(icb.caxPos(4)-fpos2);
                    caxLims1  = [caxNewMin icb.caxLims(2)]; % update color axis lower limit.
                case iCtrl.shift  % shift: shift caxis, no rescaling. 
                    delta = (icb.fpos - fpos2)/icb.caxPos(4)*diff(icb.caxLims);
                    caxLims1 = icb.caxLims + delta;
                otherwise % alter caxis upper limit.
                    caxNewMax =  icb.caxLims(1) + icb.fpos/fpos2*diff(icb.caxLims);
                    if icb.ctrlMode == iCtrl.symmetrical
                        caxLims1 = [-1 1]*caxNewMax;
                    else
                        caxLims1  = [icb.caxLims(1) caxNewMax]; % update color axis upper limit. 
                    end
            end
            if caxLims1(2) > caxLims1(1)
                try
                    caxis(icb.handles.hax, caxLims1);
                catch ME
                    warning('iColorBar: couln''t set color axis for the limits: [%5.2f %5.2f]\n %s', caxLims1, ME.message);
                end             
            end
        end
        
        function wbucb(icb, ~, ~)
            % Restore the old interaction callbacks:
            set(icb.handles.hfig, 'WindowButtonMotionFcn', icb.old_wbmcb, ...
                          'WindowButtonUpFcn',     icb.old_wbucb );
        end
        
        function fkpcb(icb, ~, evt)
            if strcmpi(evt.Modifier, 'alt')
                icb.ctrlMode = iCtrl.lowerBound;
            elseif strcmpi(evt.Modifier, 'shift')
                icb.ctrlMode = iCtrl.shift;
            elseif strcmpi(evt.Modifier, 'control')
                icb.ctrlMode = iCtrl.symmetrical;
            end
        end
        
        function fkrcb(icb, ~, ~)
            icb.ctrlMode = iCtrl.upperBound;
        end
    end    
end
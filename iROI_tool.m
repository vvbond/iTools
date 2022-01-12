classdef iROI_tool < iTool
% Push button to add a iROI interactively to the current axes.
%
% Usage
% =====
%  iROI_tool
%
% The command adds a pushbutton to the toolbar of the current figure.
% Click the button to define a iROI interactively by click-and-dragging in the current axes.
%
% Properties
% ==========
%  rois     - an array of iROI(s) added to the current figure.
%
% Example
% =======
%  figure, plot(cumsum(rand(1000,1)*2-1)), iROI_tool
%
% See also: iROI.

% 31-Dec-2021
% (c) Vladimir Bondarenko, http://www.mathworks.co.uk/matlabcentral/fileexchange/authors/52876

    properties
        rois = iROI.empty()
    end
    methods
        function rtool = iROI_tool(hfig)
            if nargin == 0, hfig = gcf; end
            tag = 'iROI_tool';
            rtool = rtool@iTool(tag, hfig);
            % Quit if the button already there:
            if ~isempty(rtool.handles.hButton), return; end

            % Create toggle button:
            rtool.handles.tbar = findall(gcf,'Type','uitoolbar');
            roi1Icon_fname = 'roi1Icon.mat';
            roi1Icon = load(fullfile(fileparts(mfilename('fullpath')), 'icons', roi1Icon_fname));
            rtool.handles.hButton = uipushtool(rtool.handles.tbar,  'CData', roi1Icon.cdata, ...
                                                                'ClickedCallback',  @(src,evt) add_roi_cb(rtool,src,evt),...
                                                                'tooltipstring', '1-d ROI',...
                                                                'tag', rtool.tag,...
                                                                'UserData', rtool,...
                                                                'Separator', 'on');
        end

        function delete(rtool)
            rtool.delete_roi();
            delete(rtool.handles.hButton);
        end

        function add_roi_cb(rtool, ~, ~)
            rtool.add_roi();
        end

        function add_roi(rtool, roi)
            if nargin == 1, roi = iROI; end
            rtool.rois(end+1) = roi;
            addlistener(rtool.rois(end), 'roiDeleted', @(src,evt) rtool.cleanup());
        end
    
        function cleanup(rtool)
            rtool.rois = arrayfilter(@isvalid, rtool.rois);
            if isempty(rtool.rois)
                rtool.rois = iROI.empty();
            end
        end
    
        function delete_roi(rtool, ix)
            if nargin == 1, ix = 1:length(rtool.rois); end
            delete(rtool.rois(ix));
            rtool.cleanup();
        end
    end
end
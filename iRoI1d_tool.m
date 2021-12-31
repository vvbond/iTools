classdef iRoI1d_tool < iTool
% Push button to add a iRoI1d interactively to the current axes.
%
% Usage
% =====
%  iRoI1d_tool
%
% The command adds a pushbutton to the toolbar of the current figure.
% Click the button to define a iRoI1d interactively by click-and-dragging in the current axes.
%
% Properties
% ==========
%  rois     - an array of iRoI1d added to the current figure.
%
% Example
% =======
%  figure, plot(cumsum(rand(1000,1)*2-1)), iRoI1d_tool
%
% See also: iRoI1d.

% 31-Dec-2021
% (c) Vladimir Bondarenko, http://www.mathworks.co.uk/matlabcentral/fileexchange/authors/52876

    properties
        rois = iRoI1d.empty()
    end
    methods
        function rtool = iRoI1d_tool()
            % Create toggle button:
            rtool.handles.tbar = findall(gcf,'Type','uitoolbar');
            roi1Icon_fname = 'roi1Icon.mat';
            roi1Icon = load(fullfile(fileparts(mfilename('fullpath')), 'icons', roi1Icon_fname));
            rtool.handles.btn = uipushtool(rtool.handles.tbar,  'CData', roi1Icon.cdata, ...
                                                    'ClickedCallback',  @(src,evt) add_roi(rtool,src,evt),...
                                                    'tooltipstring', 'RoI 1D',...
                                                    'Separator', 'on');
        end

        function add_roi(rtool,~,~)
            rtool.rois(end+1) = iRoI1d;
        end
    end
end
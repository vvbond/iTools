classdef ixline < iAxisLine
    methods
        function ixl = ixline(varargin)                 
            if nargin == 0 
                varargin{1} = [];
                jj = 1;
            else
                jj = ifthel(isa(varargin{1}, 'matlab.graphics.axis.Axes'), 2, 1);
            end
            ixl = ixl@iAxisLine(varargin{1:jj}, 1, varargin{jj+1:end});
            ixl.tag = 'ixline';
            ixl.handles.al.Tag = ixl.tag;
        end
    end 
end
classdef iyline < iAxisLine
    methods
        function iyl = iyline(varargin)
            if nargin == 0 
                varargin{1} = [];
                jj = 1;
            else
                jj = ifthel(isa(varargin{1}, 'matlab.graphics.axis.Axes'), 2, 1);
            end
            iyl = iyl@iAxisLine(varargin{1:jj}, 2, varargin{jj+1:end});
            iyl.tag = 'iyline';
            iyl.handles.al.Tag = iyl.tag;
        end        
    end
end
function keypressfcn(~, evt, keymodfcn)
% A function multiplexer generator to execute a function given a key-{press, release} event.
%
% Usage:
%  @(src,evt) keypressfcn(src, evt, keymodfcn)
% To be used as a KeyPress or KeyRelease callbacks: set(gcf, 'KeyPressFcn', @(src,evt) keypressfcn
%
% Input:
%  src       - not used and hence omitted, 
%  evt       - event structure passed by keypress or keyrelease events,
%  keymodfcn - cell array a raw of which specifies the combination of 
%              'key', 'modifier', and the 0-argument function.
%
% Output:
%  anonymous multiplexer function of (src, evt). 
%
% Example:
%  figure, set(gcf, 'KeyPressFcn', @(src,evt) keypressfcn(src, evt, {'a', [], @()disp('Voila a!'); 'b', 'control', @()disp('Control b')}));
%
% See also:

% (c) Vladimir Bondarenko, 2022. http://www.mathworks.co.uk/matlabcentral/fileexchange/authors/52876

    for i=1:size(keymodfcn, 1)
        key = keymodfcn{i,1};
        mod = keymodfcn{i,2};
        fcn = keymodfcn{i,3};
        if ~isempty(mod) && ( isempty(evt.Modifier) || ~strcmpi(evt.Modifier, mod) ), continue; end
        if isempty(mod) && ~isempty(evt.Modifier), continue; end
        if ~strcmpi(evt.Key, key), continue; end
        fcn();
    end
end
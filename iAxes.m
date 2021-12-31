classdef iAxes
    properties
    end
    methods(Static)        
        function set_xlim_duration(d)
            xlim_old = xlim;
            xlim_new = [xlim_old(1), xlim_old(1) + d];
            xlim(xlim_new);
        end
        
        function set_xlim_resized(hax, frac)
            iAxes.set_axis_limits_changed(hax, 'x', frac, @interval_resize);
        end
        
        function set_xlim_shifted(hax, frac)
            iAxes.set_axis_limits_changed(hax, 'x', frac, @interval_shift);
        end

        function set_ylim_resized(hax, frac)
            iAxes.set_axis_limits_changed(hax, 'y', frac, @interval_resize);
        end
        
        function set_ylim_shifted(hax, frac)
            iAxes.set_axis_limits_changed(hax, 'y', frac, @interval_shift);
        end
        
        function set_axis_limits_changed(hax, dim, frac, fcn)
            switch dim
                case {1, 'x'}
                    lims_label = 'XLim';
                case {2, 'y'}
                    lims_label = 'YLim';
                case {3, 'z'}
                    lims_label = 'ZLim';
            end
            axlims = get(hax, lims_label);
            axlims = fcn(axlims, frac);
            set(hax, lims_label, axlims);
        end

        function set_keyboard_shortcuts(hfig)
            if nargin == 0, hfig = gcf; end
            set(hfig, 'KeyPressFcn', @(src, evt) keypressfcn(src,evt,{'j', [], @()iAxes.set_xlim_resized(gca, .9);
                                                                      'k', [], @()iAxes.set_xlim_resized(gca, 1.1);
                                                                      'h', [], @()iAxes.set_xlim_shifted(gca, -.1);
                                                                      'l', [], @()iAxes.set_xlim_shifted(gca, .1);
                                                                      'j', 'alt', @()iAxes.set_ylim_resized(gca, .9);
                                                                      'k', 'alt', @()iAxes.set_ylim_resized(gca, 1.1);
                                                                      'h', 'alt', @()iAxes.set_ylim_shifted(gca, -.1);
                                                                      'l', 'alt', @()iAxes.set_ylim_shifted(gca, .1);
                                                                      'h', 'control', @()iAxes.set_xlim_shifted(gca, -.01);
                                                                      'l', 'control', @()iAxes.set_xlim_shifted(gca, .01);                                                                      
                                                                      'a', 'control', @()axis(gca, 'tight');
                                                                      'x', [], @()set(gca, 'Interactions', zoomInteraction('Dimensions', 'x'));
                                                                      'y', [], @()set(gca, 'Interactions', zoomInteraction('Dimensions', 'y'))
                                                                      }));

        end
    end
end
classdef iPeaksFinder < iTool
    properties
        peaks
        data
        x
        minheight
        minprominence
    end
    properties
        height_factor = .6
        prominence_factor = .0;
    end
    methods
        function pkf = iPeaksFinder(data, x)
            narginchk(1,2);
            if nargin == 1
                x = 1:length(data);
            end
            pkf.data = data;
            pkf.x = x;
            pkf.minheight = max(data)*pkf.height_factor;
            pkf.minprominence = range(data)*pkf.prominence_factor;
            pkf.find_peaks();
            pkf.init_plot();
        end

        %% Compute
        function find_peaks(pkf)
            [pks, locs, wdth, prom] = findpeaks(pkf.data, pkf.x, ...
                                    'MinPeakHeight', pkf.minheight, ...
                                    'MinPeakProminence', pkf.minprominence);
            pkf.peaks = struct('value', pks, 'location', locs, 'width', wdth, 'prominence', prom);
        end

        function delete_peak(pkf, ix)
            pkf.peaks.location(ix) = [];
            pkf.peaks.width(ix) = [];
            pkf.peaks.prominence(ix) = [];
            pkf.peaks.value(ix) = [];
        end

        %% Plot
        function init_plot(pkf)
            pkf.handles.hfig = figure;
            pkf.handles.hax_prom = subplot(1, 30, 1);
            pkf.handles.hax = subplot(1, 30, 3:30);
            % Setup prominence "gauge" axes:
            set(pkf.handles.hax_prom, 'YLim', [0 range(pkf.data)], 'YLimMode', 'manual', ...
                                                                   'YGrid', 'on', ...
                                                                   'Box', 'off', ...
                                                                   'Color', get(gcf, 'Color'));
            pkf.handles.hax_prom.XAxis.Visible = 'off';
            ylabel(pkf.handles.hax_prom, 'MinProminence', 'FontSize', 14);
            % Plot:
            axes(pkf.handles.hax);
            pkf.handles.dataplot = plot(pkf.x, pkf.data);
            hold on
            pkf.handles.peaksplot = stem(pkf.peaks.location, pkf.peaks.value, 'r.');
            hold off
            box on, grid on;

            % Interactivity:
            pkf.handles.peaksplot.ButtonDownFcn = @(src,evt) pkf.peak_bdcb(src,evt);
            pkf.handles.height_line = iyline(pkf.handles.hax, pkf.minheight);
            pkf.handles.prominence_line = iyline(pkf.handles.hax_prom, pkf.minprominence, 'LineWidth', 3);
            addlistener(pkf.handles.height_line, 'positionChanged', @(src,evt) pkf.set('minheight', pkf.handles.height_line.Value));
            addlistener(pkf.handles.height_line, 'buttonUp', @(src,evt) pkf.update());
            addlistener(pkf.handles.prominence_line, 'positionChanged', @(src,evt) pkf.set('minprominence', pkf.handles.prominence_line.Value));
            addlistener(pkf.handles.prominence_line, 'buttonUp', @(src,evt) pkf.update());
            iAxes.set_keyboard_shortcuts(pkf.handles.hfig);
        end

        function update(pkf, recompute)
            if nargin == 1, recompute = true; end
            if recompute, pkf.find_peaks(); end
            set(pkf.handles.peaksplot, 'XData', pkf.peaks.location, 'YData', pkf.peaks.value);
        end
    end
    methods
        function peak_bdcb(pkf, ~, evt)
            if evt.Button ~= 3, return; end
            p = evt.IntersectionPoint;
            location_num = ruler2num(pkf.peaks.location, pkf.handles.hax.XAxis);
            ix = find(abs(location_num - p(1)) < 1e-8);
            pkf.delete_peak(ix);
            pkf.update(false);
        end
    end
    events
    end
end
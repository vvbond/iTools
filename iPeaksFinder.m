classdef iPeaksFinder < iTool
    properties
        peaks
        data
        x
        minheight
        minprominence
        mindistance
    end
    properties
        height_factor = .6
        prominence_factor = .5;
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
            pkf.init_params();
            pkf.find_peaks();
            pkf.init_plot();
        end

        %% Compute
        function init_params(pkf)
            [pks, locs, wdth, prom] = findpeaks(pkf.data, pkf.x);
            pkf.minheight = pkf.height_factor * median(pks);
            pkf.minprominence = pkf.prominence_factor * median(prom);
            pkf.mindistance = median(diff(locs));
        end

        function find_peaks(pkf)
            [pks, locs, wdth, prom] = findpeaks(pkf.data, pkf.x, ...
                                    'MinPeakHeight', pkf.minheight, ...
                                    'MinPeakProminence', pkf.minprominence, ...
                                    'MinPeakDistance',pkf.mindistance);
            pkf.peaks = struct('value', pks, 'location', locs, 'width', wdth, 'prominence', prom);
        end

        function delete_peak(pkf, ix)
            pkf.peaks.location(ix) = [];
            pkf.peaks.width(ix) = [];
            pkf.peaks.prominence(ix) = [];
            pkf.peaks.value(ix) = [];
        end

        %% Plot
        function create_main_menu(pkf)
            pkf.handles.menu = uimenu(pkf.handles.hfig, 'Text', 'Peaks Finder');
            pkf.handles.menu_params = uimenu(pkf.handles.menu, 'Text', 'Params', 'MenuSelectedFcn', @(src,evt) pkf.menu_params_cb());
        end

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
            pkf.handles.dataplot    = plot(pkf.x, pkf.data);
            hold on
            pkf.handles.peaksplot   = stem(pkf.peaks.location, pkf.peaks.value, 'r.');
            hold off
            box on, grid on;


            % Interactivity:
            pkf.handles.peaksplot.ButtonDownFcn = @(src,evt) pkf.peak_bdcb(src,evt);
            pkf.handles.height_line = iyline(pkf.handles.hax, pkf.minheight, 'LineWidth', 2);
            pkf.handles.prominence_line = iyline(pkf.handles.hax_prom, pkf.minprominence, 'LineWidth', 3);
            addlistener(pkf.handles.height_line, 'positionChanged', @(src,evt) pkf.set('minheight', pkf.handles.height_line.Value));
            addlistener(pkf.handles.height_line, 'buttonUp', @(src,evt) pkf.update());
            addlistener(pkf.handles.prominence_line, 'positionChanged', @(src,evt) pkf.set('minprominence', pkf.handles.prominence_line.Value));
            addlistener(pkf.handles.prominence_line, 'buttonUp', @(src,evt) pkf.update());
            iAxes.set_keyboard_shortcuts(pkf.handles.hfig);

            % Menus:
            pkf.create_main_menu();
        end

        function update(pkf, recompute)
            if nargin == 1, recompute = true; end
            if recompute, pkf.find_peaks(); end
            set(pkf.handles.peaksplot, 'XData', pkf.peaks.location, 'YData', pkf.peaks.value);
        end
    end

    %% Callbacks
    methods
        function peak_bdcb(pkf, ~, evt)
            if evt.Button ~= 3, return; end
            p = evt.IntersectionPoint;
            location_num = ruler2num(pkf.peaks.location, pkf.handles.hax.XAxis);
            ix = find(abs(location_num - p(1)) < 1e-8);
            pkf.delete_peak(ix);
            pkf.update(false);
        end

        function menu_params_cb(pkf)
            prompt = {'Minimum peak height', 'Minimum peak prominence', 'Minimum peak distance [s]'};
            dlgttl = 'Peak parameters';
            dims = [1, 20];
            definput = {num2str(pkf.minheight, '%5.1f'), num2str(pkf.minprominence, '%5.1f')};
            if isa(pkf.mindistance, 'duration')
                definput{end+1} = datestr(pkf.mindistance, 'SS');
            elseif isnumeric(pkf.mindistance)
                definput{end+1} = num2str(pkf.mindistance);
            end
            params = inputdlg(prompt(1:length(definput)), dlgttl, dims, definput);
            if isempty(params), return; end
            pkf.minheight = str2double(params{1});
            pkf.minprominence = str2double(params{2});
            if length(params) > 2
                mdistance = str2double(params{3});
                if isa(pkf.mindistance, 'duration')
                    pkf.mindistance = seconds(str2double(params{3}));
                elseif isnumeric(pkf.mindistance)
                    pkf.mindistance = mdistance;
                end
            end
            pkf.update();
        end
    end
    events
    end
end
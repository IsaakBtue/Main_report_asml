% plot_H22_accel.m  -  Load COMSOL H22_accel.txt and plot Bode (magnitude + unwrapped phase)
%
% Sensor: MEMS accelerometer (IMU). H22 = a_z / Va  [m/s^2 / V]
%
% File format expected (COMSOL export, expression = solid.accZ):
%   freq_Hz <tab> real+imag*i

clear; close all;

cd(fileparts(mfilename('fullpath')));
fprintf('Working directory: %s\n', pwd);

%% --- Load file -----------------------------------------------------------
filename = 'H22_accel.txt';
fid = fopen(filename, 'r');
if fid == -1
    error('Cannot open %s - make sure it is in the same folder as this script.', filename);
end

freq    = [];
H22_acc = [];

while ~feof(fid)
    line = strtrim(fgetl(fid));
    if ~ischar(line) || isempty(line), continue; end
    if line(1) == '%' || line(1) == '#', continue; end

    parts = regexp(line, '\t', 'split');
    if numel(parts) < 2, continue; end

    f_val = str2double(parts{1});
    h_val = str2num(parts{2});   %#ok<ST2NM>

    if ~isempty(f_val) && ~isempty(h_val) && isfinite(f_val)
        freq(end+1, 1)    = f_val; %#ok<SAGROW>
        H22_acc(end+1, 1) = h_val; %#ok<SAGROW>
    end
end
fclose(fid);

if isempty(freq)
    error('No data read from %s - check file format.', filename);
end

[freq, ia] = unique(freq, 'stable');
H22_acc    = H22_acc(ia);

fprintf('Loaded %d frequency points: %.1f – %.1f Hz\n', numel(freq), freq(1), freq(end));

%% --- Derived quantities --------------------------------------------------
omega      = 2 * pi * freq;
mag_dB     = 20 * log10(abs(H22_acc));
phase_deg  = unwrap(angle(H22_acc)) * (180 / pi);

[~, i_peak] = max(abs(H22_acc));
f_peak      = freq(i_peak);
fprintf('Peak |H22_acc| at %.1f Hz  →  %.2f dB,  phase = %.1f deg\n', ...
        f_peak, mag_dB(i_peak), phase_deg(i_peak));

%% --- H22 Bode: full frequency range -------------------------------------
figure('Name', 'H22 Acceleration Transfer Function', 'NumberTitle', 'off', ...
       'Position', [100 100 900 600]);

ax1 = subplot(2,1,1);
plot(freq, mag_dB, 'b', 'LineWidth', 1.5);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB re m/s^2/V)');
title(sprintf('H_{22} = a_z / V_a  [m/s^2/V]  -  peak at %.1f Hz', f_peak));
grid on;
xlim([freq(1) freq(end)]);
xline(f_peak, 'k--', sprintf(' %.1f Hz', f_peak), 'LabelVerticalAlignment', 'bottom', 'FontSize', 8);

ax2 = subplot(2,1,2);
plot(freq, phase_deg, 'r', 'LineWidth', 1.5);
xlabel('Frequency (Hz)');
ylabel('Phase (deg)');
title('H_{22} phase');
grid on;
xlim([freq(1) freq(end)]);
xline(f_peak, 'k--', 'LabelVerticalAlignment', 'bottom', 'FontSize', 8);
linkaxes([ax1 ax2], 'x');

%% --- Equivalent displacement H22_disp = H22_acc / (-omega^2) -----------
H22_disp   = H22_acc ./ (-omega.^2);
phase_disp = unwrap(angle(H22_disp)) * (180/pi);

figure('Name', 'H22 equivalent displacement (from acc / -omega^2)', 'NumberTitle', 'off', ...
       'Position', [100 750 900 400]);

ax3 = subplot(2,1,1);
plot(freq, 20*log10(abs(H22_disp)), 'm', 'LineWidth', 1.5);
ylabel('Magnitude (dB re m/V)');
title('H_{22,disp} = H_{22,acc} / (-\omega^2)');
grid on;
xlim([freq(1) freq(end)]);

ax4 = subplot(2,1,2);
plot(freq, phase_disp, 'm', 'LineWidth', 1.5);
ylabel('Phase (deg)');
xlabel('Frequency (Hz)');
grid on;
xlim([freq(1) freq(end)]);
linkaxes([ax3 ax4], 'x');

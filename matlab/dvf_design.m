%% DVF Controller Design - IMU Accelerometer Feedback
% Direct Velocity Feedback (DVF) using an accelerometer as sensor.
%
% Reference: Falangas, Dworak & Koshigoe (1994), IEEE Control Systems Magazine 14(4):34-41
%   Flat rectangular plate + PZT patches + collocated accelerometers + rate feedback.
%   Achieves ~10.5 dB at first mode with rate feedback. Figure 7 = closed-loop FRF baseline.
%
% Physics:
%   H22_acc = solid.accZ / Va  [m/s^2 / V]  from COMSOL (expression: solid.accZ)
%   COMSOL convention: solid.accZ = +w^2 * solid.w  (positive, same phase as displacement)
%   Phase at resonance: ~-90 deg  (0 deg below resonance, -180 deg above)
%
% Control strategy - DVF (rate feedback):
%   Sensor:     accelerometer -> a [m/s^2]
%   Filter:     v ~ S/(s+S) * a   -> approximate velocity [m/s]  (first-order lag, Falangas)
%   Feedback:   Va = -g * v       -> negative velocity feedback
%   Net K(s):   K(s) = -g * S/(s+S)    (avoids DC drift from pure integrator)
%   Falangas (1994) used S = 5 rad/s (cutoff at S/(2*pi) ~ 0.8 Hz).
%
% STABILITY - CONDITIONAL, NOT UNCONDITIONAL:
%   Patch applies distributed bending moment, not a point force -> conditionally stable.
%   Maximum stable gain exists. Check Nyquist before hardware. (Gatti et al. 2007)
%
% NOT recommended: IRC (Integral Resonant Control).
%   IRC stability proof requires collocated piezo VOLTAGE sensor (strain/charge output).
%   With an acceleration sensor the proof breaks down entirely. (Aphale 2007)
%
% Files required:
%   H22_accel.txt  - always required  (COMSOL Study 1: solid.accZ / Va)
%   H11_accel.txt  - MIMO sections    (COMSOL Study 2: solid.accZ / base_acc, IMU corner)
%   H12_accel.txt  - MIMO sections    (COMSOL Study 1: solid.accZ / Va, IMU corner)
%   H21_accel.txt  - MIMO sections    (COMSOL Study 2: solid.accZ / base_acc, IMU corner)

clear; close all; clc;

cd(fileparts(mfilename('fullpath')));
fprintf('Working directory: %s\n', pwd);

%% ======== USER SETTINGS ========
g  = 1e-3;   % DVF gain [V/(m/s)] - tune for desired damping vs stability
S  = 5;      % first-order lag pole [rad/s] ~ 0.8 Hz cutoff (Falangas 1994 value)
%% ================================

%% 1. Check and load files
files    = {'H22_accel.txt', 'H11_accel.txt', 'H12_accel.txt', 'H21_accel.txt'};
have     = false(1,4);
for k = 1:4
    have(k) = isfile(files{k});
    if have(k), fprintf('Found:     %s\n', files{k});
    else,        fprintf('NOT FOUND: %s\n', files{k}); end
end

if ~have(1)
    error('H22_accel.txt is required. Export solid.accZ from COMSOL Study 1 first.');
end

[H22_complex, freq] = load_tf('H22_accel.txt');
omega_data = 2*pi*freq;

have_mimo = all(have(2:4));
if ~have_mimo
    fprintf('\n  H11/H12/H21 missing - MIMO closed-loop sections will be skipped.\n');
    fprintf('  Export these from COMSOL Study 2 (base excitation) to unlock them.\n\n');
end

%% 2. H22 phase at resonance
[~, i_peak] = max(abs(H22_complex));
f1          = freq(i_peak);
omega_n     = 2*pi*f1;

phase_at_res = angle(H22_complex(i_peak)) * 180/pi;
fprintf('f1          = %.2f Hz (peak of |H22_acc|)\n', f1);
fprintf('H22 phase   = %.1f deg at f1  (expect ~ -90 deg, COMSOL convention)\n', phase_at_res);

%% 3. DVF controller K(s) = -g * S/(s+S)
s     = tf('s');
K_dvf = -g * S / (s + S);
K_dvf.InputName  = {'A_imu'};
K_dvf.OutputName = {'Va'};
fprintf('K_dvf       = -%.3e * %.1f / (s + %.1f)\n', g, S, S);
fprintf('Cutoff      = %.3f Hz\n\n', S/(2*pi));

opts = bodeoptions('cstprefs');
opts.FreqUnits     = 'Hz';
opts.Grid          = 'on';
opts.PhaseWrapping = 'on';

%% 4. Nyquist stability check - MUST verify before hardware
% DVF is CONDITIONALLY stable. Loop must NOT encircle (-1, 0).
jw         = 1j * omega_data;
lag_filter = S ./ (jw + S);
H22_vel    = H22_complex .* lag_filter ./ jw;
L_resp     = g * H22_vel;

figure(1);
plot(real(L_resp), imag(L_resp), 'b', 'LineWidth', 1.5);
hold on;
plot(real(L_resp), -imag(L_resp), 'b--', 'LineWidth', 0.8);   % mirror (negative freq)
plot(-1, 0, 'rx', 'MarkerSize', 14, 'LineWidth', 2.5);
xlabel('Real'); ylabel('Imaginary');
title('Nyquist: g x H22_{vel} (DVF loop gain) - must NOT encircle -1');
legend('Positive freq', 'Negative freq (mirror)', '-1 point');
grid on; axis equal;
fprintf('Nyquist plotted. Verify locus does not encircle (-1, 0).\n');
fprintf('If it does: reduce g or add phase-lag compensator.\n\n');

%% 5. Bode of H22 and controller
figure(2);
bode(frd(H22_complex, omega_data), K_dvf, opts);
legend('H22_{acc} [m/s^2/V]', 'K_{DVF}(s)');
title('H22 acceleration and DVF controller');
grid on;

%% 6. MIMO sections (require H11, H12, H21)
if have_mimo
    [H11_complex, ~] = load_tf('H11_accel.txt');
    [H12_complex, ~] = load_tf('H12_accel.txt');
    [H21_complex, ~] = load_tf('H21_accel.txt');

    Hrespc        = zeros(2, 2, length(freq));
    Hrespc(1,1,:) = H11_complex;
    Hrespc(1,2,:) = H12_complex;
    Hrespc(2,1,:) = H21_complex;
    Hrespc(2,2,:) = H22_complex;

    HOLc = frd(Hrespc, omega_data);
    HOLc.InputName  = {'A_base', 'Va'};
    HOLc.OutputName = {'A_tip',  'A_imu'};

    figure(3);
    bode(HOLc, opts);
    title('Open loop MIMO FRF (acceleration channels)');

    % Closed-loop
    T = feedback(HOLc, K_dvf, 2, 2, -1);

    figure(4);
    bode(HOLc(2,2), T(2,2), opts);
    legend('H22_{acc} DVF off', 'H22_{acc} DVF on');
    title('H22_{acc}: A_{imu}/V_a - DVF off vs on');
    grid on;

    figure(5);
    bode(HOLc(1,1), T(1,1), opts);
    legend('H11_{acc} DVF off', 'H11_{acc} DVF on');
    title('H11_{acc}: Transmissibility A_{tip}/A_{base} - DVF off vs on');
    grid on;

    figure(6);
    bode(HOLc(1,1), T(1,1), opts, {2*pi*(f1*0.5), 2*pi*(f1*1.5)});
    legend('H11_{acc} DVF off', 'H11_{acc} DVF on');
    title(sprintf('H11_{acc} zoom %.0f Hz', f1));
    grid on;

    % Multiple gains
    g_values = g * [0.25, 0.5, 1.0, 2.0];
    T_gains  = cell(length(g_values), 1);
    for i = 1:length(g_values)
        K_i = -g_values(i) * S / (s + S);
        K_i.InputName = {'A_imu'}; K_i.OutputName = {'Va'};
        T_gains{i} = feedback(HOLc, K_i, 2, 2, -1);
    end
    figure(7);
    bode(HOLc(1,1), T_gains{1}(1,1), T_gains{2}(1,1), T_gains{3}(1,1), T_gains{4}(1,1), opts);
    legend('DVF off', sprintf('g=%.1e', g_values(1)), sprintf('g=%.1e', g_values(2)), ...
           sprintf('g=%.1e', g_values(3)), sprintf('g=%.1e', g_values(4)));
    title('H11_{acc} transmissibility - multiple DVF gains');
    grid on;

    % Suppression at f1
    [~, i_f1] = min(abs(freq - f1));
    T11_f1    = freqresp(T(1,1), omega_data(i_f1));
    H11_f1    = H11_complex(i_f1);
    supp_tip  = 20*log10(abs(T11_f1) / abs(H11_f1));
    fprintf('--- Suppression at f1 = %.2f Hz ---\n', f1);
    fprintf('H11 suppression: %.1f dB  (target: -10 to -17 dB, Falangas 1994)\n\n', supp_tip);
end

%% 7. Discretize for hardware (Tustin 10 kHz)
Kd = c2d(K_dvf, 1e-4, 'tustin');
[num, den] = tfdata(Kd, 'v');
fprintf('Discrete DVF (Ts=1e-4 s, Tustin):\n  num = [');
fprintf(' %.6f', num); fprintf(' ]\n  den = [');
fprintf(' %.6f', den); fprintf(' ]\n');

%% Local functions
function [H_cplx, freq] = load_tf(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        H_cplx = []; freq = []; return;
    end
    C      = textscan(fid, '%f %s');
    fclose(fid);
    freq   = C{1};
    H_cplx = cellfun(@str2num, C{2});
    [freq, ia] = unique(freq, 'stable');
    H_cplx     = H_cplx(ia);
end

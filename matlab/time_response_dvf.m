%% Time Response DVF - IMU Accelerometer Feedback (plate version)
% Analogous to time_response_ppf.m but for DVF controller with acceleration sensor.
%
% H11: Y_tip / A_base  [m / (m/s^2)]
% H12: Y_tip / Va      [m / V]
% H21: A_imu / A_base  [dimensionless]
% H22: A_imu / Va      [m/s^2 / V]
% Controller: K(s) = -g/s  (integrates acc -> velocity, applies negative gain)

clc; clear all; close all; %#ok<CLALL>

cd(fileparts(mfilename('fullpath')));
fprintf('Working directory: %s\n', pwd);

%% ======== USER SETTINGS ========
g  = 1e4;    % DVF gain [V/(m/s)] - tuned for ~50% loop gain at 138 Hz resonance
%% ================================

%% 1. Load transfer functions
[H11_cplx, freq] = load_tf('H11_accel.txt');   % Y_tip  / A_base  [m/(m/s^2)]
[H12_cplx, ~   ] = load_tf('H12_accel.txt');   % Y_tip  / Va      [m/V]
[H21_cplx, ~   ] = load_tf('H21_accel.txt');   % A_imu  / A_base  [dimensionless]
[H22_cplx, ~   ] = load_tf('H22_accel.txt');   % A_imu  / Va      [m/s^2/V]

w = freq * 2*pi;

%% 1b. Data quality check
H21_dc = abs(H21_cplx(1));
if H21_dc < 0.1
    warning(['H21 at %.0f Hz = %.2e  (expected ~1 for rigid body).\n' ...
             '  -> Re-export H21 from Study 2 (base excitation), not Study 1.\n' ...
             '  Without correct H21, T11 = H11 and the DVF effect will be invisible.'], ...
             freq(1), H21_dc);
end

%% 2. Assemble MIMO FRD
Hrespc        = zeros(2, 2, length(freq));
Hrespc(1,1,:) = H11_cplx;
Hrespc(1,2,:) = H12_cplx;
Hrespc(2,1,:) = H21_cplx;
Hrespc(2,2,:) = H22_cplx;

HOLc = frd(Hrespc, w);
HOLc.InputName  = {'A_base', 'Va'};
HOLc.OutputName = {'Y_tip',  'A_imu'};

opts = bodeoptions('cstprefs');
opts.FreqUnits = 'Hz';
opts.Grid      = 'on';

figure()
bode(HOLc, opts)
title('Open loop MIMO FRF (acceleration channels)')

%% 3. DVF controller
[~, i_peak] = max(abs(H22_cplx));
f1          = freq(i_peak);
fprintf('f1 = %.2f Hz (largest H22_acc peak)\n', f1);
omega_n = 2*pi*f1;

s   = tf('s');
DVF = -g / s;   % integrator × negative gain

figure()
bode(frd(H22_cplx, w), DVF, opts)
legend('H22_{acc}', 'DVF K(s)')
title('H22 acceleration and DVF controller')

%% 4. Closed-loop transmissibility T(1,1) = A_tip/A_base with DVF
DVF_resp  = squeeze(freqresp(DVF, w));
H22_cplx_col = H22_cplx;

% DVF closed-loop uses same positive-feedback convention as PPF (Baken eq. 10):
% T11 = H11 + H12 * (K/(1 - H22*K)) * H21    K = DVF = -g/s
% The negative sign is already in K, so denominator is (1 - H22*K).
CL_denom = 1 - H22_cplx .* DVF_resp;
T11_cplx = H11_cplx + H12_cplx .* (DVF_resp ./ CL_denom) .* H21_cplx;

T11_frd  = frd(T11_cplx, w);

%% 5. Convert to LTI state-space via ssest
% Use idfrd and limit to resonance region to avoid rigid-body 1/w^2 at low freq.
opt = ssestOptions;
opt.InitializeMethod = 'auto';
opt.EnforceStability = true;
nx = 12;

mask = freq >= 50 & freq <= 200;

fprintf('Fitting state-space model to H11 (OL)...\n');
LTI_HOLc11 = ssest(idfrd(H11_cplx(mask), w(mask), 0), nx, opt);
fprintf('Fitting state-space model to T11 (CL)...\n');
LTI_T11    = ssest(idfrd(T11_cplx(mask), w(mask), 0), nx, opt);

% OL vs CL Bode - plot after ssest so both LTI models are available
figure()
bode(LTI_HOLc11, LTI_T11, opts)
legend('OL H11', 'CL T11')
title('Tip displacement OL vs CL (DVF)')

figure()
bode(LTI_HOLc11, HOLc(1,1), opts)
legend('ssest fit','COMSOL data')
title('H11 OL ssest verification')
grid on

figure()
bode(LTI_T11, T11_frd, opts)
legend('ssest fit CL','CL T11')
title('T11 CL ssest verification')
grid on

%% 6. Impulse response
% Pass both systems in one call - hold-on after impulse() is unreliable for ss objects
figure()
impulse(LTI_HOLc11 * 1e3, LTI_T11 * 1e3)
grid on
legend('DVF-off','DVF-on')
ylabel('Tip displacement [mm]')
title('Impulse response')

%% 7. Time response: sine excitation at f1, switched off at t=6s
dt    = 1e-4;
t_end = 12;
t     = (0:dt:t_end)';

dist = sin(2*pi*f1*t);

ramp     = max(0, min(1, (6.05 - t) / 0.1));
dist_off = dist .* ramp;

[y_dvf_off, ~] = lsim(LTI_HOLc11, dist_off, t, zeros(order(LTI_HOLc11),1));
[y_dvf_on,  ~] = lsim(LTI_T11,    dist_off, t, zeros(order(LTI_T11),1));

if any(~isfinite(y_dvf_off))
    warning('y_dvf_off has NaN/Inf -- OL ssest model is unstable. Check H11 data quality.');
    y_dvf_off = zeros(size(t));
end

figure()
plot(t, y_dvf_off * 1e3)
hold on
plot(t, y_dvf_on * 1e3)
grid on
ylabel('Tip displacement [mm]')
title(sprintf('Time response at f1 = %.1f Hz - disturbance off at t=6s', f1))
legend('DVF-off','DVF-on')

%% 8. Fig 12a equivalent: disturbance on, DVF switched on at t=6s
% OL for the full window to get steady-state before switch.
[y_off_full, ~] = lsim(LTI_HOLc11, dist, t, zeros(order(LTI_HOLc11),1));
if any(~isfinite(y_off_full))
    warning('y_off_full has NaN/Inf -- see warning above. Zeroing OL portion.');
    y_off_full = zeros(size(t));
end

% CL starts from zero IC at the moment DVF is switched on (t=6s).
% This shows the CL transient building up from zero, reaching CL steady state,
% while the OL portion before t=6s shows the higher-amplitude steady state.
idx_sw = find(t >= 6, 1);
t_tail = t(idx_sw:end) - t(idx_sw);
[y_cl_tail, ~] = lsim(LTI_T11, dist(idx_sw:end), t_tail, zeros(order(LTI_T11),1));
y_12a  = [y_off_full(1:idx_sw-1); y_cl_tail];

figure()
plot(t, y_12a * 1e3)
hold on
xline(6, 'LineWidth', 2, 'color', 'k')
grid on
ylabel('Tip displacement [mm]')
title('DVF switched on at t=6s')
legend('response','')

%% local function
function [H_cplx, freq] = load_tf(filename)
    % Supports two export formats from COMSOL:
    %   3-column: freq  real  imag        (export real() and imag() separately)
    %   2-column: freq  real+imagi        (COMSOL complex string, e.g. H22)
    fid = fopen(filename, 'r');
    first = fgetl(fid);
    fclose(fid);
    if numel(strsplit(strtrim(first))) >= 3
        % three numeric columns
        data   = load(filename);
        freq   = data(:,1);
        H_cplx = data(:,2) + 1i * data(:,3);
    else
        % two-column string format (a+bi)
        fid    = fopen(filename, 'r');
        C      = textscan(fid, '%f %s');
        fclose(fid);
        freq   = C{1};
        H_cplx = cellfun(@str2num, C{2});
    end
    [freq, ia] = unique(freq, 'stable');
    H_cplx     = H_cplx(ia);
end

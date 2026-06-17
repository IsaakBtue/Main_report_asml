%% DVF Main - Design + Nyquist + Time Response (Combined)
% H11: A_corner / A_base  [dimensionless]  - IMU corner, base excitation (Study 2)
% H12: A_corner / Va      [m/s^2 / V]     - IMU corner, actuator excitation (Study 1)
% H21: A_imu   / A_base  [dimensionless]  - IMU corner, base excitation (Study 2)
% H22: A_imu   / Va      [m/s^2 / V]     - IMU corner, actuator excitation (Study 1)
% NOTE: H11 and H21 are evaluated at the SAME corner (IMU location, NOT plate center).
%       H12 and H22 likewise. After correct re-export H11=H21 and H12=H22.
% Controller: K(s) = +g * S/(s+S)  (Falangas 1994 lag-integrator, sign flipped for
%             solid.accZ's +w^2 convention - see note at controller definition below)
%
% Primary suppression metric: T21 = H21/(1-H22*K)  (IMU corner, always valid)
% Secondary metric:           T11 = H11 + H12*K*H21/(1-H22*K)  (IMU corner, needs correct H11)

clc; clear; close all;
cd(fileparts(mfilename('fullpath')));
fprintf('Working directory: %s\n', pwd);

%% ======== USER SETTINGS ========
mode_select = 3;     % <-- CHANGE THIS to retarget: 1, 2, 3, or 4 (see target_modes below)
                      %     Everything downstream (f1, controller, Nyquist, suppression,
                      %     ssest fit window, figure titles) updates automatically.
target_modes = [86.411, 127.57, 160.53, 225.41];  % nominal eigenfrequencies [Hz] from the
                      % COMSOL eigenfrequency study. UPDATE this list whenever density/BC
                      % changes shift the eigenfrequencies (re-run the eigenfrequency study).
search_halfwidth = 10; % Hz, window around target_modes(mode_select) to locate the actual
                      % |H22| peak in the exported data (COMSOL peak may sit a bit off the
                      % idealized eigenfrequency)

g_frac     = 0.30;  % operating gain as fraction of g_max  <-- tune this one number
S          = 5;     % lag pole [rad/s] ~ 0.8 Hz cutoff (Falangas 1994)
V_max      = 400;   % actuator voltage limit [V]  (P-876.A12 max: +400 V)
a_base_rms = 0.01;  % expected floor disturbance RMS [m/s^2]
%% ================================

%% 1. Load transfer functions
[H11_cplx, freq] = load_tf('H11_accel.txt');
[H12_cplx, ~   ] = load_tf('H12_accel.txt');
[H21_cplx, ~   ] = load_tf('H21_accel.txt');
[H22_cplx, ~   ] = load_tf('H22_accel.txt');
w = freq * 2*pi;

%% 1b. Data quality checks
% H21 check: must be ~1 at DC (base excitation transmissibility)
H21_dc = abs(H21_cplx(1));
if H21_dc < 0.1
    warning('H21 at %.0f Hz = %.2e (expected ~1). Re-export from Study 2.', freq(1), H21_dc);
end

% H11 check: must be ~1-2 at DC for spring-mounted plate (spring transmissibility = fn^2/(fn^2-f^2))
% Values ~1e-6 mean it was exported from Study 1 (actuator) not Study 2 (base excitation).
H11_dc    = abs(H11_cplx(1));
H11_valid = H11_dc > 0.5;
if ~H11_valid
    fprintf(['\n  *** H11 INVALID - auto-derived as H11=H21 ***\n' ...
             '  H11 at %.0f Hz = %.2e  (expected ~1 to 2 for spring-mounted plate).\n' ...
             '  H11 and H21 are defined at the IDENTICAL point (IMU corner, Study 2), so they\n' ...
             '  must be equal. Using H11=H21 directly instead of the bad export.\n' ...
             '  To get an independently-verified H11, re-export in COMSOL:\n' ...
             '    Results > Export > Data, Dataset: Study 2 / Solution 2,\n' ...
             '    Expressions: real/imag(solid.accZ / 1[m/s^2]), at the SAME Point feature as H21\n' ...
             '    (select the existing IMU geometry point, do not retype coordinates).\n\n'], ...
            freq(1), H11_dc);
    H11_cplx  = H21_cplx;
    H11_valid = true;
end

% f1 = actual |H22| peak found near the SELECTED target mode (not the global max)
f_target    = target_modes(mode_select);
search_mask = freq >= (f_target - search_halfwidth) & freq <= (f_target + search_halfwidth);
if ~any(search_mask)
    error('No data points within %.0f Hz of target mode %d (%.2f Hz). Widen search_halfwidth.', ...
          search_halfwidth, mode_select, f_target);
end
freq_in_window           = freq(search_mask);
[H22_peak, i_local]      = max(abs(H22_cplx(search_mask)));
f1                       = freq_in_window(i_local);
[H12_peak, ~]            = max(abs(H12_cplx(search_mask)));

fprintf('\n=== Targeting mode %d: nominal %.2f Hz -> actual peak f1 = %.2f Hz ===\n', ...
        mode_select, f_target, f1);
fprintf('f1 = %.2f Hz (|H22| peak = %.4g m/s^2/V)\n', f1, H22_peak);
fprintf('|H12| peak = %.4g m/s^2/V\n', H12_peak);

% Phase check at f1: the DVF sign (+g, see controller section) was derived assuming
% H22 phase = -90 deg at the target resonance (clean, isolated mode, COMSOL convention).
% If feedthrough from nearby/poorly-isolated modes distorts the phase away from -90 deg,
% the sign assumption breaks down and "suppression" can flip to amplification even with
% the correct sign convention in general. This check catches that BEFORE the controller
% design, for whichever mode_select is currently chosen.
H22_phase_f1 = angle(H22_cplx(freq == f1)) * 180/pi;
phase_error  = abs(mod(H22_phase_f1 + 90 + 180, 360) - 180);  % deviation from -90 deg, wrapped
fprintf('H22 phase at f1 = %.1f deg  (ideal: -90 deg, deviation: %.1f deg)\n', H22_phase_f1, phase_error);
if phase_error > 30
    fprintf(['  WARNING: phase is far from -90 deg - this mode is NOT a clean, isolated\n' ...
             '  resonance (likely feedthrough/overlap from nearby modes, same phenomenon as\n' ...
             '  the quasi-static feedthrough documented in H22_physics_explanation.md for the\n' ...
             '  PPF/piezo model). The controller sign (+g) was derived assuming -90 deg phase;\n' ...
             '  with %.0f deg actual phase, suppression at f1 may come out as AMPLIFICATION\n' ...
             '  even though the sign convention itself is correct. Re-export finer-resolution\n' ...
             '  COMSOL data (e.g. 0.1 Hz steps) near %.1f Hz to locate the true -90 deg crossing,\n' ...
             '  or expect this mode to be poorly controlled by simple DVF.\n\n'], H22_phase_f1, f1);
end
if H12_peak < H22_peak * 0.05
    fprintf(['  WARNING: H12 << H22 (ratio %.2f%%) at f1 = %.0f Hz - auto-derived as H12=H22.\n' ...
             '  H12 and H22 are defined at the IDENTICAL point (IMU corner, Study 1), so they\n' ...
             '  must be equal. A flat, featureless H12 with no resonance peaks anywhere (while\n' ...
             '  H22 swings by orders of magnitude) means the export point is still wrong -\n' ...
             '  not a damping/stiffness effect, since both come from the same Study 1 solve.\n' ...
             '  To get an independently-verified H12, re-export at the SAME Point feature as\n' ...
             '  H22 (select the existing IMU geometry point in COMSOL, do not retype coordinates).\n\n'], ...
             H12_peak/H22_peak*100, f1);
    H12_cplx = H22_cplx;
end

%% 2. MIMO FRD
Hrespc        = zeros(2, 2, length(freq));
Hrespc(1,1,:) = H11_cplx;
Hrespc(1,2,:) = H12_cplx;
Hrespc(2,1,:) = H21_cplx;
Hrespc(2,2,:) = H22_cplx;
HOLc = frd(Hrespc, w);
HOLc.InputName  = {'A_base', 'Va'};
HOLc.OutputName = {'A_tip',  'A_imu'};

opts = bodeoptions('cstprefs');
opts.FreqUnits = 'Hz';
opts.Grid      = 'on';

figure(1); bode(HOLc, opts); title('Open-loop MIMO FRF')

%% 3. g_max from data, then set g = g_frac * g_max
% L_norm = H22 * S/(jw+S) is the loop gain shape per unit g.
% g_max is the gain where the Nyquist locus first touches -1.
jw_data  = 1j * w;
lag_norm = S ./ (jw_data + S);
L_norm   = H22_cplx .* lag_norm;     % H22 * S/(jw+S), positive at low freq
g_max    = 1 / max(-real(L_norm));   % critical gain: locus reaches -1 when g*max(-Re) = 1

g = g_frac * g_max;
fprintf('g_max = %.0f V/(m/s)\n', g_max);
fprintf('g     = %.0f%% x g_max = %.0f V/(m/s)\n\n', g_frac*100, g);

%% Controller K(s) = +g * S/(s+S)
% SIGN NOTE: Falangas (1994) writes K(s) = -g*S/(s+S) assuming PHYSICAL acceleration
% feedback (a = -w^2*x). COMSOL's solid.accZ uses the OPPOSITE convention (a = +w^2*x,
% see CLAUDE.md section 3). Feeding solid.accZ directly into the literature's negative
% gain flips negative (damping) feedback into positive (anti-damping) feedback. The sign
% is flipped here (+g instead of -g) to compensate, restoring genuine velocity damping.
s   = tf('s');
DVF = g * S / (s + S);
DVF.InputName  = {'A_imu'};
DVF.OutputName = {'Va'};

K_resp = squeeze(freqresp(DVF, w));   % = +g * lag_norm

fprintf('Controller: K(s) = +%.3g * %.1f/(s+%.1f)\n', g, S, S);
fprintf('Cutoff: %.3f Hz\n', S/(2*pi));

[~, if1] = min(abs(freq - f1));
L_f1 = abs(H22_cplx(if1) * K_resp(if1));
fprintf('Loop gain |H22*K| at f1 = %.3f (%.0f%% of 1)\n\n', L_f1, L_f1*100);

figure(2); bode(frd(H22_cplx, w), DVF, opts)
legend('H22 [m/s^2/V]', 'K(s)'); title('H22 and DVF controller')

%% 4. Nyquist stability check
% L_nyq = H22 * g * S/(jw+S) = -H22 * K_resp  (positive loop gain for plotting)
% Standard negative-feedback convention: stable iff locus does NOT encircle -1 CW.
L_nyq = -H22_cplx .* K_resp;   % positive at low freq

[max_proj, i_gm] = max(-real(L_nyq));
if max_proj > 0
    GM_factor = 1 / max_proj;
    g_max_nyq = g * GM_factor;
    fprintf('Gain margin:  %.2fx  (= %.1f dB)  at %.1f Hz\n', ...
            GM_factor, 20*log10(GM_factor), freq(i_gm));
    fprintf('g_max       = %.0f V/(m/s)  (instability boundary)\n', g_max_nyq);
    fprintf('Current g   = %.0f V/(m/s)  (%.0f%% of g_max)\n\n', g, g/g_max_nyq*100);
    g_max = g_max_nyq;
else
    fprintf('Locus never reaches negative-real axis - unconditionally stable.\n\n');
    g_max = Inf;
    GM_factor = Inf;
end

% Actuator voltage saturation check
K_norm_f1     = S / sqrt((2*pi*f1)^2 + S^2);
H21_mag_f1    = abs(H21_cplx(if1));
Va_per_unit_g = K_norm_f1 * H21_mag_f1 * sqrt(2) * a_base_rms;
g_max_voltage = V_max / Va_per_unit_g;

fprintf('--- Actuator voltage check ---\n');
fprintf('g_max from stability:  %.0f V/(m/s)\n', g_max);
fprintf('g_max from 400V limit: %.0f V/(m/s)  (at a_rms = %.3g m/s^2)\n', ...
        g_max_voltage, a_base_rms);
if g_max_voltage < g_max
    fprintf('  >> Voltage limit is tighter. Using g_max = %.0f.\n', g_max_voltage);
    g_max  = g_max_voltage;
    g      = g_frac * g_max;
    fprintf('  >> g updated to %.0f V/(m/s)  (%.0f%% of voltage-limited g_max)\n', g, g_frac*100);
    DVF    = g * S / (s + S);
    DVF.InputName  = {'A_imu'};
    DVF.OutputName = {'Va'};
    K_resp = squeeze(freqresp(DVF, w));
else
    fprintf('  >> Stability limit is tighter. g = %.0f V/(m/s) is safe.\n', g);
end
Va_peak = g * Va_per_unit_g;
fprintf('Peak Va at operating g: %.2f V  (limit %.0f V)\n\n', Va_peak, V_max);

figure(3)
plot(real(L_nyq), imag(L_nyq), 'b', 'LineWidth', 1.5); hold on
plot(-1, 0, 'rx', 'MarkerSize', 14, 'LineWidth', 2.5)
xlabel('Real'); ylabel('Imaginary')
title('Nyquist: L = H_{22} \cdot g \cdot S/(s+S)  --  critical point -1')
legend('L(j\omega)', '-1 critical point')
grid on; axis equal

dist_to_minus1 = min(abs(L_nyq + 1));
fprintf('Distance of Nyquist locus to (-1,0): %.4f\n\n', dist_to_minus1);
if dist_to_minus1 < 0.2
    warning('Nyquist locus within 0.2 of (-1,0). Consider reducing g.');
end

%% 5. Closed-loop transfer functions
% Common denominator: (1 - H22*K)
CL_denom = 1 - H22_cplx .* K_resp;

% T21 = A_imu/A_base (closed-loop) - ALWAYS VALID (only needs H21, H22)
T21_cplx = H21_cplx ./ CL_denom;
T21_frd  = frd(T21_cplx, w);

% T11 = A_tip/A_base (closed-loop) - ONLY VALID when H11 and H12 are correct
T11_cplx = H11_cplx + H12_cplx .* (K_resp ./ CL_denom) .* H21_cplx;
T11_frd  = frd(T11_cplx, w);

%% 6. Peak suppression at resonance
fprintf('--- Suppression at mode %d, f1 = %.2f Hz (negative dB = suppression, positive = amplification) ---\n', mode_select, f1);

% T21: primary metric (IMU location, always valid)
H21_f1_dB = 20*log10(abs(H21_cplx(if1)));
T21_f1_dB = 20*log10(abs(T21_cplx(if1)));
supp_T21  = T21_f1_dB - H21_f1_dB;
fprintf('IMU location (T21 = A_imu/A_base):\n');
fprintf('  OL H21 : %7.2f dB\n', H21_f1_dB);
fprintf('  CL T21 : %7.2f dB\n', T21_f1_dB);
fprintf('  Delta  : %+.2f dB  (Falangas 1994 achieves ~10.5 dB with rate feedback)\n\n', supp_T21);

% T11: secondary metric (IMU corner, only if H11 is from Study 2)
if H11_valid
    H11_f1_dB = 20*log10(abs(H11_cplx(if1)));
    T11_f1_dB = 20*log10(abs(T11_cplx(if1)));
    supp_T11  = T11_f1_dB - H11_f1_dB;
    fprintf('IMU corner (T11 = A_corner/A_base):\n');
    fprintf('  OL H11 : %7.2f dB\n', H11_f1_dB);
    fprintf('  CL T11 : %7.2f dB\n', T11_f1_dB);
    fprintf('  Delta  : %+.2f dB\n\n', supp_T11);
else
    fprintf('IMU corner (T11): INVALID - re-export H11 from COMSOL Study 2.\n');
    fprintf('  See warning printed at startup for exact steps.\n\n');
end

%% 7. OL vs CL Bode plots
figure(4)
if H11_valid
    bode(frd(H21_cplx, w), T21_frd, frd(H11_cplx, w), T11_frd, opts)
    legend('OL H21 - IMU (DVF off)', 'CL T21 - IMU (DVF on)', ...
           'OL H11 - centre (DVF off)', 'CL T11 - centre (DVF on)')
    title(sprintf('Transmissibility: DVF off vs on - mode %d (%.1f Hz)', mode_select, f1))
else
    bode(frd(H21_cplx, w), T21_frd, opts)
    legend('OL H21 - IMU corner (DVF off)', 'CL T21 - IMU corner (DVF on)')
    title(sprintf('A_{imu}/A_{base}: DVF off vs on - mode %d (%.1f Hz) [H11 invalid]', mode_select, f1))
end

%% 8. Gain sweep (fractions of g_max)
fracs  = unique([0.10, 0.20, g_frac, 0.50, 0.70, 0.80]);
g_vals = fracs * g_max;

fprintf('--- Gain sweep ---\n');
if H11_valid
    fprintf('  %6s  %6s  |  T21 supp  |  T11 supp\n', 'g', '% gmax');
else
    fprintf('  %6s  %6s  |  T21 supp  (T11 invalid)\n', 'g', '% gmax');
end

legend_str = {'DVF off (H21)'};
sys_list   = {frd(H21_cplx, w)};

for k = 1:length(g_vals)
    K_k      = g_vals(k) * S / (s + S);
    K_resp_k = squeeze(freqresp(K_k, w));
    CL_den_k = 1 - H22_cplx .* K_resp_k;
    T21_k    = H21_cplx ./ CL_den_k;
    sys_list{end+1} = frd(T21_k, w); %#ok<SAGROW>

    [~, if1k] = min(abs(freq - f1));
    supp_T21_k = 20*log10(abs(T21_k(if1k))) - 20*log10(abs(H21_cplx(if1k)));

    if H11_valid
        T11_k      = H11_cplx + H12_cplx .* (K_resp_k ./ CL_den_k) .* H21_cplx;
        supp_T11_k = 20*log10(abs(T11_k(if1k))) - 20*log10(abs(H11_cplx(if1k)));
        fprintf('  g = %6.0f  (%3.0f%%)  |  %+6.1f dB  |  %+6.1f dB\n', ...
                g_vals(k), fracs(k)*100, supp_T21_k, supp_T11_k);
    else
        fprintf('  g = %6.0f  (%3.0f%%)  |  %+6.1f dB\n', ...
                g_vals(k), fracs(k)*100, supp_T21_k);
    end

    if isfinite(g_max)
        legend_str{end+1} = sprintf('T21 g=%.0f (%.0f%% gmax)', g_vals(k), fracs(k)*100); %#ok<SAGROW>
    else
        legend_str{end+1} = sprintf('T21 g=%.0e', g_vals(k)); %#ok<SAGROW>
    end
end

figure(5)
bode(sys_list{:}, opts)
legend(legend_str{:})
title(sprintf('A_{imu}/A_{base} gain sweep toward g_{max} - mode %d (%.1f Hz)', mode_select, f1))

%% 9. ssest state-space fit (window around f1 only)
% NOTE: a wide band (e.g. +-40 Hz) can be dominated by the spring-isolation
% background in H21 (smoothly decaying floor-transmissibility ~(f_mount/f)^2),
% which has many more data points than the narrow resonance peak (half-power
% bandwidth ~ f1*eta ~ 160*0.02 = 3.2 Hz). ssest minimizes total squared
% error and fits the dominant background instead of the resonance.
% Fix: use a narrow +-10 Hz window so the resonance bump is the dominant
% feature. No other plate mode falls within +-10 Hz of mode 3 (160 Hz).
opt_ss = ssestOptions;
opt_ss.InitializeMethod = 'auto';
opt_ss.EnforceStability = true;
% nx=2 = ONE complex pole pair, the minimum needed for a single resonance, no room
% left for ssest to add a second, unphysical pole pair.
nx = 2;

f_lo = max(freq(1),   f1 - 10);
f_hi = min(freq(end), f1 + 10);
mask = freq >= f_lo & freq <= f_hi;
fprintf('\nssest fit window: %.0f - %.0f Hz (%d points) around f1 = %.2f Hz\n', ...
        f_lo, f_hi, sum(mask), f1);
fprintf('NOTE: Figures 6-7 plot the fit against data over the FULL spectrum.\n');
fprintf('Mismatch OUTSIDE %.0f-%.0f Hz is expected - the model is only fit there.\n\n', f_lo, f_hi);

% Always fit H21 and T21 (both valid)
fprintf('Fitting H21 (OL)...\n');
LTI_OL = ssest(idfrd(H21_cplx(mask), w(mask), 0), nx, opt_ss);
fprintf('Fitting T21 (CL)...\n');
LTI_CL = ssest(idfrd(T21_cplx(mask), w(mask), 0), nx, opt_ss);

% Pole diagnostic: verify the fit is physically plausible BEFORE trusting the time
% response. Expect natural frequency near f1 and damping ratio near eta/2 ~ 0.01
% (for the COMSOL structural loss factor eta=0.02). A pole with much smaller zeta
% (under-damped/fast) or far-off frequency means the fit is not physical.
[wn_OL, zeta_OL] = damp(LTI_OL);
[wn_CL, zeta_CL] = damp(LTI_CL);
fprintf('LTI_OL poles: fn = %s Hz, zeta = %s\n', ...
        mat2str(wn_OL/(2*pi), 4), mat2str(zeta_OL, 4));
fprintf('LTI_CL poles: fn = %s Hz, zeta = %s\n', ...
        mat2str(wn_CL/(2*pi), 4), mat2str(zeta_CL, 4));
fprintf('Expect: fn close to %.1f Hz, zeta around 0.01 (eta/2 for eta=0.02 loss factor)\n\n', f1);

figure(6); bode(LTI_OL, frd(H21_cplx, w), opts)
legend('ssest OL fit', 'H21 data')
title(sprintf('H21 ssest fit - mode %d (%.1f Hz), valid only in %.0f-%.0f Hz', mode_select, f1, f_lo, f_hi)); grid on

figure(7); bode(LTI_CL, T21_frd, opts)
legend('ssest CL fit', 'T21 data')
title(sprintf('T21 ssest fit - mode %d (%.1f Hz), valid only in %.0f-%.0f Hz', mode_select, f1, f_lo, f_hi)); grid on

%% 10. Impulse response
figure(8)
impulse(LTI_OL * 1e3, LTI_CL * 1e3)
grid on; legend('DVF off (H21)', 'DVF on (T21)')
ylabel('A_{imu} [mm/s^2 per unit impulse]')
title(sprintf('Impulse response at IMU - mode %d (%.1f Hz)', mode_select, f1))

%% 11. Time response: sine at f1, disturbance off at t=6s
dt = 1e-4; t_end = 12; t = (0:dt:t_end)';
dist = sin(2*pi*f1*t);
ramp     = max(0, min(1, (6.05 - t) / 0.1));
dist_off = dist .* ramp;

[y_off, ~] = lsim(LTI_OL, dist_off, t, zeros(order(LTI_OL), 1));
[y_on,  ~] = lsim(LTI_CL, dist_off, t, zeros(order(LTI_CL), 1));

if any(~isfinite(y_off))
    warning('OL lsim has NaN/Inf - ssest model unstable. Check H21 data quality.');
    y_off = zeros(size(t));
end

figure(9)
plot(t, y_off * 1e3); hold on; plot(t, y_on * 1e3)
grid on; ylabel('A_{imu} [mm/s^2 per m/s^2 base]')
title(sprintf('Mode %d (%.1f Hz): sine disturbance off at t=6s, IMU location', mode_select, f1))
legend('DVF off', 'DVF on')

% Terminal output: peak amplitude in figure 9
i_ss = t >= 4 & t < 5.9;   % steady-state window before ramp-off starts
p_OL = max(abs(y_off(i_ss))) * 1e3;
p_CL = max(abs(y_on(i_ss))) * 1e3;
fprintf('\n--- Fig 9 peak amplitude (steady-state before disturbance off) ---\n');
fprintf('DVF off: %.4g mm/s^2 per m/s^2 base\n', p_OL);
fprintf('DVF on:  %.4g mm/s^2 per m/s^2 base\n', p_CL);
if p_OL > 0 && p_CL > 0
    reduction_dB  = 20 * log10(p_CL / p_OL);
    reduction_pct = (1 - p_CL / p_OL) * 100;
    fprintf('Reduction: %.1f dB  (%.1f%% amplitude reduction)\n', reduction_dB, reduction_pct);
end

%% 12. DVF switched on at t=6s
[y_off_full, ~] = lsim(LTI_OL, dist, t, zeros(order(LTI_OL), 1));
if any(~isfinite(y_off_full)), y_off_full = zeros(size(t)); end

idx_sw = find(t >= 6, 1);
t_tail = t(idx_sw:end) - t(idx_sw);
[y_cl_tail, ~] = lsim(LTI_CL, dist(idx_sw:end), t_tail, zeros(order(LTI_CL), 1));
y_switch = [y_off_full(1:idx_sw-1); y_cl_tail];

figure(10)
plot(t, y_switch * 1e3); hold on
xline(6, 'k', 'LineWidth', 2)
grid on; ylabel('A_{imu} [scaled]')
title(sprintf('Mode %d (%.1f Hz): DVF switched on at t=6s, IMU location', mode_select, f1))

%% 13. Discrete controller coefficients (Tustin, 10 kHz)
Kd = c2d(DVF, 1e-4, 'tustin');
[num_d, den_d] = tfdata(Kd, 'v');
fprintf('\nDiscrete K (Ts=1e-4 s, Tustin):\n  b = [');
fprintf(' %.6f', num_d); fprintf(' ]\n  a = [');
fprintf(' %.6f', den_d); fprintf(' ]\n');

%% Local function
function [H_cplx, freq] = load_tf(filename)
    fid = fopen(filename, 'r');
    first = fgetl(fid); fclose(fid);
    if numel(strsplit(strtrim(first))) >= 3
        data   = load(filename);
        freq   = data(:,1);
        H_cplx = data(:,2) + 1i * data(:,3);
    else
        fid    = fopen(filename, 'r');
        C      = textscan(fid, '%f %s'); fclose(fid);
        freq   = C{1};
        H_cplx = cellfun(@str2num, C{2});
    end
    [freq, ia] = unique(freq, 'stable');
    H_cplx     = H_cplx(ia);
end

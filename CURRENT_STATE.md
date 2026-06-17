# ImuActuator - Current Project State
**Last updated:** 2026-06-15  
**Author:** Isaak Bouwmeester, ASML internship

---

## What This Project Is

Active Vibration Control (AVC) of the ASML measurement plate (~1x1 m aluminum, ~100 mm thick) using:
- **Actuator:** PI Ceramic P-876.A12 DuraAct patch (Patch 2) driven at voltage Va
- **Sensor:** MEMS accelerometer (IMU) at a plate corner, measuring z-acceleration
- **Controller:** DVF (Direct Velocity Feedback), K(s) = -g * S/(s+S), S=5 rad/s
- **Target mode:** Main bending mode, currently at ~156 Hz in the COMSOL model

This is the **IMU/DVF variant**. The earlier PPF/piezo-sensor variant is documented separately in `piezo_patch_mimo.mph` and the PPF session logs.

---

## Model File

`TransferFunctionrealplateIMU.mph` - COMSOL 6.4 model containing:
- Plate geometry: DummyPlateOwn.stl (aluminum, density tuned toward 200 Hz target)
- Boundary condition: **Domain Spring Foundation** on plate domain, kz_vol = 2.7e6 N/m^3 (~5 Hz mount resonance), NO fixed constraint
- Actuator: Patch 2 (3 layers: bottom polymer / PIC255 ceramic / top polymer)
- Sensor: IMU modelled as Point geometry at plate corner (x_antinode1+65, y_antinode1, z_top)
- Study 1: Frequency domain, Va = 1 V input -> extracts H22 and H12
- Study 2: Frequency domain, Base excitation 1 m/s^2 -> extracts H21 and H11

---

## Physical Geometry Facts

| Parameter | Value | Notes |
|-----------|-------|-------|
| Plate footprint | ~1000x1000 mm | from STL |
| Plate thickness | ~100 mm | from STL |
| z_top | measured from STL | zmax of bounding box |
| Actuator position | x_antinode1, y_antinode1, z_top | from strain heatmap Step 15 |
| IMU position | x_antinode1+65, y_antinode1, z_top | plate CORNER - NOT plate center |
| Resonance f1 (latest run) | 161 Hz | |H22| peak - dominant actuator-to-IMU coupling |
| Target resonance | ~200 Hz | density not yet tuned in this model |
| Spring mount resonance | ~1.66-1.68 Hz | 6 rigid-body modes, eigenfrequency study |
| Actuator placed at | strain antinode of 86.51 Hz mode | user's deliberate choice 2026-06-16 |

**Eigenfrequency table (latest run):** 6 spring modes ~1.66-1.68 Hz, then flexible modes at
86.51, 127.78, 160.90, 225.56 Hz.

**Modal coupling observation [2026-06-16]:** The actuator (Patch 2) is placed at the strain
antinode of the 86.51 Hz mode, but H22 = solid.accZ(IMU)/Va peaks at 160.90 Hz, not 86.51 Hz.
This is not a bug - H22 depends on the PRODUCT of (actuator coupling into a mode) and
(IMU coupling out of that same mode). The actuator may couple strongly into 86.51 Hz, but if
the IMU corner sits near a NODE of that mode and near an ANTINODE of the 161 Hz mode, the net
H22 will still be dominated by 161 Hz. Check the 86.51 Hz mode shape at the IMU corner location
if targeting the lowest flexible mode specifically is the goal.

**[CONFIRMED 2026-06-16] 86.51 Hz mode has feedthrough-distorted phase, unlike 161 Hz.**
Measured H22 phase near each mode (from H22_accel.txt):
```
160 Hz: -63.9 deg   161 Hz: -97.9 deg   <- crosses -90 deg cleanly at the magnitude peak
85 Hz: +140.7 deg   86 Hz: +110.9 deg   87 Hz: +51.6 deg   88 Hz: +23.1 deg
                                        <- never reaches -90 deg anywhere near the peak
```
161 Hz is a clean, well-isolated resonance (textbook -90 deg at the peak). 86.51 Hz is
contaminated by feedthrough from nearby/other modes (same phenomenon as the quasi-static
feedthrough in `H22_physics_explanation.md` for the PPF/piezo model, just now hitting the
accelerometer H22 instead of the piezo-voltage H22). Consequence: a DVF controller whose
sign was derived assuming -90 deg phase at f1 will show AMPLIFICATION instead of suppression
when targeting 86.51 Hz with the naive magnitude-peak f1, even though the sign convention
(+g, see DVF Controller section) is correct in general. `dvf_main.m` now prints a phase
check at f1 and warns when deviation from -90 deg exceeds 30 deg.

**Practical implication:** simple single-sign DVF reliably suppresses 161 Hz (clean mode) but
is NOT expected to reliably suppress 86.51 Hz with the current actuator/IMU placement, because
the local phase relationship is unfavorable across most of that mode's neighborhood, not just
at one bad frequency point. Options if 86.51 Hz must be targeted (it has the largest H21,
i.e. is most excited by floor disturbance, making it the practically important mode):
1. Re-export finer-resolution COMSOL data (e.g. 0.1 Hz steps, 80-95 Hz) to pin down exactly
   where (if anywhere) the true -90 deg crossing occurs, then target that exact frequency.
2. Investigate actuator repositioning for better, cleaner coupling into 86.51 Hz specifically
   (see modal coupling observation above - the strain heatmap may have been run under the
   wrong BC, see CLAUDE.md common errors table).
3. Accept that simple DVF only reliably controls 161 Hz with this hardware configuration.

---

## COMSOL Expression Summary

All expressions below use solid.accZ (COMSOL +w^2 convention, phase 0 deg at DC).

| Quantity | Expression | Study | Notes |
|----------|-----------|-------|-------|
| H22 magnitude | `20*log10(abs(solid.accZ))` | Study 1 | at IMU corner |
| H22 phase | `arg(solid.accZ)*180/pi` | Study 1 | -90 deg at resonance |
| H22 export (complex) | `real(solid.accZ)` + `imag(solid.accZ)` | Study 1 | at IMU corner |
| H12 magnitude | `20*log10(abs(solid.accZ))` | Study 1 | at IMU corner (same as H22 point) |
| H12 export (complex) | `real(solid.accZ)` + `imag(solid.accZ)` | Study 1 | at IMU corner |
| H21 export (complex) | `real(solid.accZ/1[m/s^2])` + `imag(solid.accZ/1[m/s^2])` | Study 2 | at IMU corner |
| H11 export (complex) | `real(solid.accZ/1[m/s^2])` + `imag(solid.accZ/1[m/s^2])` | Study 2 | at IMU corner |
| Phase at resonance | -90 deg | either study | COMSOL +w^2 convention |
| Eigenfrequency | from Results > Derived Values > Eigenfrequency | Eigenfreq study | 6 spring modes at ~1.66 Hz expected |

**Critical COMSOL notes:**
- Use `arg()` not `atan2()` for phase (COMSOL passes only real part to atan2)
- Use `solid.accZ` not `solid.wtt` (solid.wtt does not exist in frequency domain)
- H11 and H12 must be evaluated at IMU corner, NOT plate center

---

## Data File Status

| File | Study | Point | Status | Expected DC value |
|------|-------|-------|--------|-------------------|
| H22_accel.txt | Study 1, Va=1V | IMU corner | CORRECT | ~1e-7 (tiny at DC) |
| H21_accel.txt | Study 2, base | IMU corner | CORRECT | ~1.0 (transmissibility) |
| H12_accel.txt | Study 1, Va=1V | IMU corner | WRONG - was at plate center | should be ~same as H22 |
| H11_accel.txt | Study 2, base | IMU corner | WRONG - was from Study 1 | should be ~1.5-1.7 at 1 Hz |

**[FIXED 2026-06-16] dvf_main.m now auto-heals this.** H11 and H21 are defined at the
identical point (IMU corner, Study 2) and must be mathematically equal; same for H12/H22
(Study 1). The script now detects a bad H11/H12 export and substitutes H11=H21, H12=H22
automatically, with a printed note. No COMSOL re-export is required to get correct results.

**Evidence H12_accel.txt's export point was still wrong (2026-06-16):** H12 stayed flat at
~1e-6 across the ENTIRE spectrum (no resonance behavior at all), while H22 - same Study 1
solve, same actuator excitation - swings 5 orders of magnitude and tracks every mode (86,
161, 225 Hz). Since H12 and H22 must be identical if evaluated at the same point in the same
solve, this proves the point used for H12 was not the IMU corner (likely still the original
plate-center point or a mistyped coordinate). Spring stiffness/damping is a global solve
property and cannot differentially suppress only H12 while leaving H22 intact - ruled out.

**If an independently-verified H12/H11 is still wanted (optional, not required):**
In COMSOL, select the EXISTING IMU Point geometry feature for the H12/H11 point graphs
rather than retyping coordinates - this guarantees the same mesh node is used for both.

---

## MATLAB Script Status

| Script | Status | Notes |
|--------|--------|-------|
| dvf_main.m | WORKING (T21 path) | T21 = H21/(1-H22*K) computed correctly. T11 skipped until H11 re-exported. |
| dvf_design.m | OLD/OUTDATED | Older version, superseded by dvf_main.m |
| plot_H22_accel.m | WORKING | Bode plot of H22, use to verify phase = -90 deg at resonance |
| time_response_dvf.m | NEEDS H11 | Requires correct H11 (Study 2) for ssest fitting |

**[2026-06-16] ssest order reduced to nx=2.** Even on the clean 161 Hz mode (phase confirmed
-97.9 deg, only 7.9 deg off ideal), Figure 9 showed the response jumping to near-full
amplitude within ~1 ms of the sine turning on. A real resonance with eta=0.02 (Q~50) needs
~16 cycles (~100 ms at 161 Hz) to build up - 100x slower than what was shown. This means
nx=4 was giving ssest a spare pole pair it used to fit a fast/non-physical mode rather than
the true resonance. Reduced to nx=2 (one complex pole pair, no spare capacity). Added a
`damp()` diagnostic printed after each fit (fn and zeta) to directly verify physical
plausibility (expect fn near f1, zeta near eta/2=0.01) instead of inferring it from the
time-domain shape.

**Primary result available now (with current data):**
- T21 = H21/(1-H22*K): suppression at IMU corner location
- Nyquist stability check: correct
- DVF gain design: correct
- Discrete controller coefficients: correct

**Not yet available (needs H11/H12 re-export):**
- T11 = H11 + H12*K/(1-H22*K)*H21: suppression at same point (= T21 after correct re-export)

---

## Mode Selection [ADDED 2026-06-16]

`dvf_main.m` now targets a specific mode via one variable instead of always grabbing the
global |H22| peak:

```matlab
mode_select = 1;     % 1, 2, 3, or 4
target_modes = [86.51, 127.78, 160.90, 225.56];  % nominal eigenfrequencies [Hz]
search_halfwidth = 10;  % Hz, window to locate the actual peak near target_modes(mode_select)
```

f1 is found as the actual `|H22|` peak within `target_modes(mode_select) +/- search_halfwidth`,
not the global maximum. Everything downstream (controller design, Nyquist, suppression report,
ssest fit window, all figure titles) reads from this f1 automatically - no other code changes
needed to switch modes. `target_modes` must be updated whenever density/BC changes shift the
eigenfrequencies (re-run the eigenfrequency study and update the list).

## DVF Controller

```matlab
K(s) = +g * S / (s + S)     % NOTE: +g, NOT -g (see sign convention below)
S = 5 rad/s  (= 0.8 Hz lag pole, Falangas 1994)
g = g_frac * g_max  (tune g_frac between 0 and 1, default 0.30)
```

**[CRITICAL - FIXED 2026-06-16] Sign convention:** Falangas (1994) writes K(s) = -g*S/(s+S)
for PHYSICAL acceleration (a = -w^2*x). solid.accZ uses the OPPOSITE convention (a = +w^2*x).
Using the literature's -g directly with solid.accZ data turns damping feedback into
anti-damping feedback - the closed loop AMPLIFIES at resonance instead of suppressing it.
**Use +g instead of -g when feeding solid.accZ-derived H21/H22 into the controller.**

Symptom this bug produces: suppression dB is POSITIVE and grows with gain (e.g. +3 dB at
30% g_max -> +13 dB at 80% g_max), and the Nyquist gain-margin search lands exactly on f1
(should never happen for a correctly-signed loop - the gain limit should come from a
different, non-collocated mode per Gatti 2007).

**g_max** is computed from the Nyquist criterion: `g_max = 1 / max(-real(H22 * S/(jw+S)))`

**Stability:** DVF with patch actuator + point accelerometer is CONDITIONALLY stable (Gatti 2007). Nyquist check is mandatory before hardware.

**Closed-loop T21:**
```
T21 = H21 / (1 - H22 * K)        with K(s) = +g*S/(s+S)
```
At resonance H22(jw1) ~ -jM (COMSOL -90 deg convention) and K(jw1) ~ -jgL (lag filter also
near -90 deg at w>>S), so H22*K ~ -MgL (negative real) -> denominator = 1-(-MgL) = 1+MgL > 1
-> T21 < H21 (genuine suppression).

**Expected performance:** ~10-15 dB suppression at f1 (Falangas 1994 benchmark: 10.5 dB)

---

## Key Physics Facts (Verified)

| Fact | Value | How confirmed |
|------|-------|---------------|
| solid.accZ convention | +w^2 * solid.w (COMSOL, not physical -w^2) | H22 at 1 Hz is positive real |
| Phase at resonance (COMSOL) | -90 deg | H22_accel.txt data at 157 Hz |
| Phase below resonance (COMSOL) | 0 deg | H22_accel.txt at 1 Hz |
| Phase above resonance (COMSOL) | -180 deg | H22_accel.txt at 250 Hz |
| PPF applicable? | NO - phase borderline -90 deg, not safe | -90 deg is boundary of PPF stability region |
| IRC applicable? | NO - requires piezo voltage sensor, not accelerometer | Aphale 2007 |
| DVF applicable? | YES - conditionally stable | Gatti 2007 |
| Spring transmissibility at 1 Hz | ~1.57 (for 1.66 Hz spring mode) | H21 at 1 Hz = 0.99996 |
| 6 rigid body modes at 1.66 Hz | Expected from isotropic Domain SF | Eigenfrequency study output |
| IMU location | Plate CORNER (NOT center) | User confirmed 2026-06-15 |

---

## PIC255 Material Overrides (CRITICAL)

COMSOL defaults for PIC255 are wrong. Always override these 3 values:

| Parameter | COMSOL default | Correct value | Source |
|-----------|---------------|---------------|--------|
| d31 = d32 | -18.5e-11 C/N | **-26.0e-11 C/N** | PI datasheet for P-876.A12 |
| epsilonrT33 | 1832 | **1355** | C=90nF, A=1500mm^2, t=200um |
| Ceramic thickness | - | 0.20 mm | PI P-876.A12 |

---

## Boundary Conditions Summary

| BC | Used in | Effect |
|----|---------|--------|
| Domain Spring Foundation, kz=2.7e6 N/m^3 | Study 1 AND Study 2 | Realistic foam bed mounting, 6 rigid body modes at ~1.66 Hz |
| Electric Potential Va=1V on PIC255 top face | Study 1 only | Actuator excitation for H22, H12 |
| Ground on PIC255 bottom face | Study 1 only | Actuator ground |
| Base Excitation, az=1 m/s^2 | Study 2 only | Floor vibration for H11, H21 |
| NO Fixed Constraint | - | Physical setup uses foam bed |
| NO Boundary Spring Foundation | - | Cannot be driven by Base Excitation node |
| NO Prescribed Acceleration | - | Relative formulation breaks solid.accZ |

---

## Remaining Work (Priority Order)

1. **Re-export H11 and H12** from COMSOL at IMU corner (see steps above)
2. **Run dvf_main.m** - verify T11 = T21 (they should match after correct re-export)
3. **Tune density** - run eigenfrequency study, use rho = rho_current*(f_current/f_target)^2 to hit 200 Hz
4. **Verify Nyquist** - check gain margin, set g_frac appropriately
5. **Run time_response_dvf.m** - impulse and sine time domain simulation
6. **Optional:** H-infinity controller (Falangas 1994: ~17 dB vs 10.5 dB for rate feedback)

---

## Reference Papers (in papers/ folder)

| Paper | Key finding for this project |
|-------|------------------------------|
| Falangas 1994 | Rate feedback: 10.5 dB. K(s) = -g*S/(s+S), S=5 rad/s. CLOSEST to this setup. |
| Gatti 2007 | DVF conditionally stable for patch actuator + point accelerometer. Max stable gain exists. |
| Gonzalez Diaz 2008 | Proof-mass actuator - NOT applicable to PZT patches |
| Qiu 2009 | Full workflow reference (wrong material/frequency range) |
| Aphale 2007 | IRC - NOT applicable to accelerometer sensors |

---

## Common Errors Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| H11 at 1 Hz ~ 1e-6 | Exported from Study 1 not Study 2 | Re-export: Dataset = Study 2, expression = solid.accZ/1[m/s^2] |
| H12 << H22 (0.13% ratio) | H12 exported at plate center (node) | Re-export H12 at IMU corner |
| T11 shows +50 dB "suppression" | H11 wrong (Study 1 data, not Study 2) | Fix H11 re-export |
| H11 flat, no resonance | Boundary SF + Base Excitation (wrong combination) | Use Domain SF + Base Excitation |
| arg() returns 0 everywhere | COMSOL passes only real part to atan2 | Use arg(V)*180/pi not atan2 |
| solid.wtt not found | Expression does not exist in frequency domain | Use solid.accZ |
| 6 modes at 1.66 Hz | Normal - spring rigid body modes | Expected behavior, not an error |
| H11 at 1 Hz ~ 1.57 | Spring transmissibility (correct!) | No fix needed |
| Phase at resonance = -168 deg | Old incorrect value from previous session context | Correct value is -90 deg |

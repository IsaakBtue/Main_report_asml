# ImuActuator - ASML Plate Active Vibration Control
**Owner:** Isaak Bouwmeester, ASML internship
**Last updated:** 2026-06-17
**Git repo (all files):** https://github.com/IsaakBtue/Main_report_asml (branch: main)
**Overleaf (report.tex only):** https://git.overleaf.com/6a32f60bf95cb3e0d3eeb351

---

## Formatting Rule - No Em Dashes

Never use em dashes anywhere in this project: MATLAB plot titles, axis labels, legend
entries, code comments, fprintf/error messages, markdown, or LaTeX prose. Use a
regular hyphen (-) instead, or restructure the sentence. Applies to all files.

---

## Project Summary

Active Vibration Control (AVC) of the ASML measurement plate (~1x1 m aluminium,
~100 mm thick). Two phases:

- **Phase I (PPF):** PI Ceramic P-876.A12 DuraAct patch as actuator (Patch 2) +
  second DuraAct patch as open-circuit voltage sensor (Patch 3). PPF controller.
  COMSOL model: `TransferFunctionrealplate.mph` (in LatestFiles root).
  MATLAB folder: `LatestFiles/Matlab/`

- **Phase II (DVF/IMU):** Same actuator patch. Sensor replaced by MEMS
  accelerometer (IMU) modelled as a Point geometry in COMSOL. DVF controller.
  COMSOL model: `TransferFunctionrealplateIMUV3.mph` (in this folder, NOT in git).
  MATLAB folder: `ImuActuator/matlab/`

---

## Full File Map

### This folder: ImuActuator/

```
ImuActuator/
  CLAUDE.md                    this file - read first when resuming
  CURRENT_STATE.md             detailed physics/model state, eigenfrequencies,
                               data file status, common errors - READ THIS NEXT
  .gitignore                   excludes *.mph, *.pdf, *.pptx, LaTeX artifacts

  report.tex                   MAIN LaTeX report (23 pages, compiles cleanly)
                               - Part I: PPF with dual patches (theory, TikZ block
                                 diagram, closed-loop derivation, results)
                               - Part II: DVF with IMU (phase convention, controller
                                 selection, DVF theory, TikZ block diagram, sign fix)
                               - Appendix A: PPF literature (Luleci, Baken, Abdelmoeti)
                               - Appendix B: d33 Piezo-TMD alternative actuator concept
                               - Appendix C: figure comparison guide (which paper
                                 figures to compare COMSOL results against)
                               - Section: Conclusions + gridplate template
  report.pdf                   compiled output (not in git, compile locally)

  make_presentation.py         Python script to regenerate presentation.pptx
                               Run: python make_presentation.py
                               Requires: python-pptx (pip install python-pptx)
  presentation_new.pptx        16-slide academic presentation (left=bullets, right=
                               image placeholder). Rename to presentation.pptx
                               after closing the old one.

  TransferFunctionrealplateIMUV3.mph        CURRENT COMSOL model (not in git - large)
  TransferFunctionrealplateIMUV3 - Copy.mph backup copy
  TransferFunctionrealplateIMUV3 - Copy - Copy.mph  older backup

  matlab/
    dvf_main.m                 PRIMARY script - DVF design, Nyquist, gain sweep,
                               ssest fit, time-domain, discrete coefficients.
                               USE THIS, not dvf_design.m.
    dvf_design.m               OLDER version, superseded by dvf_main.m
    plot_H22_accel.m           Bode plot of H22_accel.txt (verify phase = -90 deg
                               at resonance before running dvf_main.m)
    time_response_dvf.m        time-domain simulation (needs all 4 data files)
    build_freq_range.m         generates freq range input files for COMSOL
    build_int_tables.m         integration table helper
    freq_range_imu.txt         frequency sweep range used for COMSOL export
    start.txt / step.txt / stop.txt   COMSOL frequency range parameters
    eig_data.txt               eigenfrequency study output

    H22_accel.txt              COMSOL export: solid.accZ at IMU corner / Va [m/s2/V]
                               Study 1, 1-250 Hz, format: freq  Re+Im*i
                               STATUS: CORRECT
    H21_accel.txt              COMSOL export: solid.accZ/1[m/s2] at IMU corner
                               Study 2 (base excitation), dimensionless
                               STATUS: CORRECT (H21 at 1 Hz ~ 1.0 confirming Study 2)
    H12_accel.txt              COMSOL export: solid.accZ at IMU corner / Va
                               Study 1 - SAME point as H22
                               STATUS: WRONG - was exported at plate center (not IMU
                               corner). dvf_main.m auto-substitutes H12=H22 as fix.
                               TODO: re-export in COMSOL at the IMU Point geometry.
    H11_accel.txt              COMSOL export: solid.accZ/1[m/s2] at IMU corner
                               Study 2 - SAME point as H21
                               STATUS: WRONG - was exported from Study 1 not Study 2.
                               dvf_main.m auto-substitutes H11=H21 as fix.
                               TODO: re-export from Study 2 at the IMU Point geometry.

  papers/
    Controlling_Plate_Vibrations_Using_Piezoelectric_A.pdf
                               Falangas, Dworak, Koshigoe (1994). IEEE Control Syst.
                               Mag. 14(4):34-41. CLOSEST to this setup. Flat Al plate
                               + PZT patches + accelerometers + rate feedback (DVF).
                               KEY FIGURES: Fig 3 (H22 open-loop), Fig 7 (open vs
                               closed-loop, ~10.5 dB suppression). Compare T21 here.

    Active damping of a beam using a physically collocated accelerometer and
    piezoelectric patch actuator.pdf
                               Gatti, Brennan, Gardonio (2007). JSV 303:798-813.
                               DVF stability reference for patch actuator + point
                               accelerometer. Confirms conditional stability.
                               KEY FIGURE: Fig 8(a) - H22_accel Bode shape.

    Smart panel with active damping units. Implementation of.pdf
                               Gonzalez Diaz, Paulitsch, Gardonio (2008). JASA
                               124(2):898-910. Proof-mass actuators (NOT PZT patches).
                               Limited direct relevance.

    Acceleration sensors based modal identification and active vibration control.pdf
                               Qiu, Wu, Ye (2009). Aerospace Sci. Tech. 13(6):306-314.
                               Fiberglass plate, very low frequencies. Workflow ref.

    Integral resonant control of collocated smart structures.pdf
                               Aphale, Fleming, Moheimani (2007). Smart Mater. Struct.
                               16(2):439-446. IRC - NOT applicable here (needs piezo
                               voltage sensor). KEY FIGURES: Figs 3-4 show collocated
                               H22 Bode for PPF comparison (phase 0 to -180 deg).
```

### PPF Phase I folder: LatestFiles/Matlab/

```
Matlab/
  ppf_design.m                 PPF controller design (loads H11-H22.txt from same folder)
  plot_H22.m                   Bode plot of H22 (PPF/piezo sensor version)
  time_response_ppf.m          PPF time-domain simulation
  EMCC_tutorial.md             Tutorial for EMCC computation (not needed for AVC)

  H11.txt / H12.txt / H21.txt / H22.txt
                               COMSOL exports from piezo patch dual model
                               (TransferFunctionrealplate.mph)
                               Format: freq  Re+Im*i
                               Frequency range: 10-1000 Hz

  V1_data/                     Older export set (version 1 of the PPF model)
  V2_data/                     Older export set (version 2 of the PPF model)
```

### Raw papers: G:/Other computers/My computer/Asml/ASML/raw/papers/

These are text-extractable versions (.txt) and PDFs of background literature.
Text files are faster to read than PDFs.

```
bakensandwhich.pdf             Baken, Gupta, Jansen, HosseinNia (2025).
                               arXiv:2506.21713v1. Sandwich beam + d15 shear
                               transducers + PPF. Defines EXACTLY the H11/H12/H21/H22
                               MIMO notation used in this project (Eq. 6 and 10).
                               PPF controller: Eq. 9. Closed-loop tip: Eq. 10.
                               This is the canonical reference for the MATLAB scripts.

ppfftplatestudyluleci.pdf      Luleci (2013). MSc thesis METU.
ACTIVEVIBRATIONCONTROL_BeamPlates.txt   text extract of the above
Luleci.txt                     second text extract
                               Al plate 700x400x1.5 mm, DuraAct P-876.A12 patches
                               (SAME PATCH TYPE as this project). PPFFT controller.
                               Suppression: 24/23/18 dB for modes 1-3.
                               Most directly comparable published simulation.

Abdelmoeti.pdf                 Abdelmoeti, Jansen, de Vries (2017). MSc TU Delft.
ABDELMOETI_MA_EEMCS.txt        text extract of the above
                               ASML cantilever beam (219x32x2.5 mm, f1=42 Hz).
                               Compares PPF, DVF, passive RL shunt. ASML context.
                               DVF: ~70 dBm/Hz PSD attenuation. PPF comparable.

Optimization_in_Active_Vibration_Control_Virtual_Experimentation_Using_COMSOL_
Multiphysics_-_MATLAB_Integration.pdf
                               COMSOL-MATLAB integration tutorial for AVC.
                               Useful for understanding the COMSOL-to-MATLAB workflow.

DESCRIPTION_LABVIEW_Francesco_Coatto_MSc_Thesis_FINAL.pdf
                               LabVIEW FPGA implementation guide (for real-time
                               controller hardware, not simulation).

sloa033a.pdf / tl074-ep.pdf    Op-amp datasheets (for synthetic inductor / gyrator
                               circuit relevant to d33 Piezo-TMD design).

3f14baad-9e52-4bd0-8916-2db390f0a795.pdf
                               Unknown paper (UUID filename, check content if needed).
```

### d33 research folder: G:/Other computers/My computer/Asml/d33/

Separate research thread: d33-mode piezoelectric tuned mass damper (Piezo-TMD).
NOT related to the d31 patch AVC. Documented in Appendix B of report.tex.

```
d33-context.md                 FULL design context, assembly details, equations,
                               adaptation procedure for ASML structure. READ THIS
                               if picking up the d33 thread.
d33-active-vibration-actuator.drawio     block diagram / schematic

A low-cost and efficient d33-mode.pdf
                               Lai, Kim, Yang, Chung (2021). JIMS&S 32:678-696.
                               PRIMARY d33 reference. Piezo-TMD: PZT stack +
                               series spring + proof mass + RLC shunt. Footbridge.
                               n=62 stacks, kd=5.87e4 N/m, R=77.1 Ohm, L=26.9 H.

Nonlinear modeling of d33-mode piezoelectric actuators using.pdf
                               Nonlinear d33 actuator modelling reference.

An embedded piezoelectric actuator for active.pdf
                               Embedded d33 actuator concept.

A six-axis single-stage active vibration isolator based.pdf
                               Multi-axis isolator with piezo stacks.

Active vibration control of high-stiffness heavy.pdf
                               AVC of heavy/stiff structures with PZT.

Modellingandcharacterizationofpiezocermicinertial.pdf
                               Piezo inertial actuator modelling.

The damping of a truss structure with a piezoelectric transducer.pdf
                               Truss + piezo shunt damping.

micromachines.pdf              MEMS/micromachined piezo actuators (background).
```

### Other LatestFiles root documents

```
LatestFiles/
  ppf_theory.tex               Standalone LaTeX document with full PPF theory
                               derivation (second-order model, time domain,
                               closed-loop derivation, Nyquist, tuning).
                               Content absorbed into report.tex Appendix A.

  ControllerExplenation.md     Plain-language explanation of PPF (swing analogy,
                               why controller gain vs closed-loop gain differ).
                               Good reading for intuition before diving into math.

  session_log_2026-05-25_matlab_ppf.md
                               Log of the session where PPF was first implemented
                               in MATLAB (dvf_design.m prototype, H22 export).

  session_log_2026-05-25_timedomain.md
                               Log of the time-domain PPF simulation session.

  Nextsteps.txt                Earlier next-steps notes (mostly completed now).

  TransferFunctionrealplate.mph        PPF COMSOL model (dual patch, fixed constraint)
  TransferFunctionBaseExcitation.mph   Base excitation study (older, superseded by V3)

  dummyPlate1.stl / dummyPlate1_1.stl  Plate geometry STL files (both variants)
```

---

## COMSOL Model: TransferFunctionrealplateIMUV3.mph

**Location:** `ImuActuator/TransferFunctionrealplateIMUV3.mph`
**Not in git** (too large). Keep a local backup copy.

### Study setup

| Study | Input | Output | COMSOL expression | Data file |
|-------|-------|--------|-------------------|-----------|
| Study 1 | Va = 1 V | solid.accZ at IMU corner | real/imag(solid.accZ) | H22_accel.txt, H12_accel.txt |
| Study 2 | base az = 1 m/s2 | solid.accZ/1[m/s2] at IMU corner | real/imag(solid.accZ/1[m/s2]) | H21_accel.txt, H11_accel.txt |

**CRITICAL:** H12 and H11 must be evaluated at the IMU Point geometry feature,
NOT at manually typed coordinates. Select the existing IMU Point in the COMSOL
Results dialog to guarantee the same mesh node as H22/H21.

### Boundary conditions

- **Domain Spring Foundation** on plate domain only (NOT patches, NOT boundary)
  - kz_vol = 2.7e6 N/m3
  - Gives ~1.66-1.68 Hz rigid-body modes (6 modes expected - this is correct)
  - Same node active in BOTH Study 1 and Study 2
- **Base Excitation** on plate domain, az = 1 m/s2
  - Disabled globally, enabled only in Study 2 via Physics and Variables Selection
- NO Fixed Constraint, NO Boundary Spring Foundation, NO Rigid Motion Suppression

### PIC255 material overrides (mandatory every time)

| Parameter | COMSOL default | Correct value |
|-----------|---------------|---------------|
| d31 = d32 | -18.5e-11 C/N | -26.0e-11 C/N |
| epsilonrT33 | 1832 | 1355 |
| Ceramic thickness | - | 0.20 mm |

### Eigenfrequencies (current model, kz_vol = 2.7e6 N/m3)

| Mode | Frequency [Hz] | Notes |
|------|---------------|-------|
| Spring rigid-body x6 | 1.66-1.68 | Normal - spring mount modes |
| Flexible 1 | 86.51 | Actuator placed at strain antinode |
| Flexible 2 | 127.78 | |
| Flexible 3 | 160.90 | DVF target (clean -90 deg phase) |
| Flexible 4 | 225.56 | |

Target was 200 Hz but resonance landed at ~161 Hz. Density was not re-tuned.
To re-tune: rho_new = rho_current * (f_current/f_target)^2.

### COMSOL expressions quick reference

| Quantity | Expression | Study | Evaluation point |
|----------|-----------|-------|-----------------|
| H22 magnitude dB | 20*log10(abs(solid.accZ)) | Study 1 | IMU Point |
| H22 phase deg | arg(solid.accZ)*180/pi | Study 1 | IMU Point |
| H22 export (complex) | real(solid.accZ), imag(solid.accZ) | Study 1 | IMU Point |
| H12 export (complex) | real(solid.accZ), imag(solid.accZ) | Study 1 | IMU Point (SAME as H22) |
| H21 export (complex) | real(solid.accZ/1[m/s2]), imag(...) | Study 2 | IMU Point |
| H11 export (complex) | real(solid.accZ/1[m/s2]), imag(...) | Study 2 | IMU Point (SAME as H21) |
| DOES NOT EXIST | solid.wtt | - | use solid.accZ instead |
| Use arg() not atan2() | - | - | atan2 gets only real part in COMSOL |

---

## MATLAB: dvf_main.m

**Location:** `ImuActuator/matlab/dvf_main.m`
**This is the primary script.** dvf_design.m is an older version.

### Key user settings (top of file)

```matlab
mode_select = 3;   % 1=86.51, 2=127.78, 3=160.90, 4=225.56 Hz
                   % Mode 3 is the reliable DVF target
target_modes = [86.51, 127.78, 160.90, 225.56];  % update if eigenfreqs change
g_frac = 0.30;     % operating gain = 30% of g_max (10 dB stability margin)
S = 5;             % lag pole [rad/s] = 0.8 Hz, Falangas 1994 value
V_max = 400;       % P-876.A12 max voltage [V]
a_base_rms = 0.01; % expected floor disturbance [m/s2]
```

### Controller formula

```matlab
K(s) = +g * S / (s + S)   % NOTE: +g not -g
```

**Why +g:** Falangas (1994) writes -g assuming physical acceleration (a = -w^2*x).
COMSOL solid.accZ uses +w^2*x (opposite sign). Using -g with solid.accZ data
flips damping into anti-damping. Always use +g when inputs come from solid.accZ.

**Symptom of wrong sign:** suppression dB is POSITIVE and grows with gain
(amplification, not damping). Nyquist gain margin lands exactly on f1.

### Auto-healing for bad data files

If H11 or H12 were exported at the wrong point, dvf_main.m detects this and
prints a warning, then substitutes H11=H21 and H12=H22. This gives correct T21
(IMU transmissibility) but T11 (tip transmissibility) needs proper re-export.

### Output figures

| Figure | Content |
|--------|---------|
| 1 | Open-loop MIMO FRF (all 4 channels) |
| 2 | H22 and K_DVF Bode |
| 3 | Nyquist plot (must not encircle -1) |
| 4 | T21 and T11 open vs closed loop |
| 5 | Gain sweep toward g_max |
| 6 | ssest OL fit vs H21 data |
| 7 | ssest CL fit vs T21 data |
| 8 | Impulse response |
| 9 | Sine disturbance off at t=6s |
| 10 | DVF switched on at t=6s |

---

## Phase Convention: solid.accZ

This is a common source of confusion. Memorise this:

- Physical accelerometer: a = -w^2 * x (phase = +180 deg vs displacement)
- COMSOL solid.accZ: a = +w^2 * w (phase = 0 deg below resonance)
- Difference: 180 deg offset - COMSOL and physical convention have opposite signs

H22_accel.txt confirms COMSOL convention:
- At 1 Hz: H22 is positive real (0 deg phase) - confirms +w^2 convention
- At 157 Hz (resonance): phase crosses -90 deg
- Above 160 Hz: phase approaches -180 deg

Papers using real accelerometers (Falangas 1994) show the opposite convention.
When comparing plots: magnitude is identical, phase differs by 180 deg.

---

## Report: report.tex

**Location:** `ImuActuator/report.tex`
**Compiles with:** pdflatex (MiKTeX or TeX Live). Requires tikz library.
**Compile command:** `pdflatex -interaction=nonstopmode report.tex` (run twice for TOC)

**Packages needed:** amsmath, amssymb, geometry, booktabs, graphicx, hyperref,
xcolor, enumitem, bm, tikz (with libraries: positioning, arrows.meta, calc)

**siunitx is intentionally excluded** (causes errors on older MiKTeX, not used).

### Structure

| Section | Content |
|---------|---------|
| 1 | Introduction and two-phase overview |
| 2 | Physical setup: plate, actuator, MIMO matrix |
| 3 | COMSOL model: boundary conditions, phase convention, eigenfrequency table |
| Part I divider | |
| 4 | Phase I hardware: dual patch setup, 7-domain model |
| 5 | PPF controller: theory, TikZ block diagram, closed-loop derivation, stability, tuning |
| Part II divider | |
| 6 | Phase II hardware: IMU setup, 4-domain model |
| 7 | Controller selection: PPF/IRC/DVF comparison table |
| 8 | DVF controller: TikZ block diagram, theory, sign fix, Nyquist, closed-loop |
| 9 | MATLAB implementation: ssest explanation, mode selection, workflow |
| 10 | COMSOL expressions reference table |
| 11 | Summary: key design decisions table |
| 12 | Conclusions + ASML gridplate template section (TODOs for next step) |
| Appendix A | PPF literature summary (Luleci, Baken, Abdelmoeti) |
| Appendix B | d33 Piezo-TMD alternative actuator concept |
| Appendix C | Figure comparison guide: which paper figures to compare results against |
| References | 13 entries |

### Key figures to compare COMSOL results against

For **PPF H22 (Vs/Va) Bode shape:**
- Aphale 2007 (in ImuActuator/papers/), Figures 3 and 4

For **DVF H22_accel open-loop Bode shape:**
- Gatti 2007 (in ImuActuator/papers/), Figure 8(a)

For **DVF closed-loop suppression (T21, open vs closed):**
- Falangas 1994 (in ImuActuator/papers/), Figure 7
  Target: ~10.5 dB suppression at first symmetric mode

---

## Git Remotes

```
origin   https://github.com/IsaakBtue/Main_report_asml.git  (all files, branch: main)
overleaf https://git.overleaf.com/6a32f60bf95cb3e0d3eeb351  (report.tex only, branch: main)
```

**To push updates to Overleaf after editing report.tex:**
```bash
git checkout overleaf
git checkout main -- report.tex
git commit -m "Update report"
git remote set-url overleaf "https://git:YOUR_OVERLEAF_TOKEN@git.overleaf.com/6a32f60bf95cb3e0d3eeb351"
git push overleaf overleaf:main
git remote set-url overleaf "https://git.overleaf.com/6a32f60bf95cb3e0d3eeb351"
git checkout main
```

Overleaf git token: generate at overleaf.com/user/settings under "Git Integration".
GitHub token: generate at github.com/settings/tokens. Previous token was
ghp_V7RE... (likely expired - generate a fresh one).

---

## Remaining Work (Priority Order)

1. **Re-export H12_accel.txt from COMSOL (Study 1, IMU corner)**
   - In COMSOL: Results > Export > Data
   - Dataset: Study 1 / Solution 1
   - Expression: real(solid.accZ), imag(solid.accZ)
   - Evaluation point: select the existing IMU Point geometry (do NOT type coordinates)
   - This fixes the auto-substituted H12=H22 in dvf_main.m

2. **Re-export H11_accel.txt from COMSOL (Study 2, IMU corner)**
   - Dataset: Study 2 / Solution 2
   - Expression: real(solid.accZ/1[m/s2]), imag(solid.accZ/1[m/s2])
   - Evaluation point: same IMU Point geometry as H12
   - Expected: H11 at 1 Hz ~ 1.0-1.7 (spring transmissibility)
   - This fixes the auto-substituted H11=H21 and enables T11 calculation

3. **Verify T11 = T21 after re-export**
   - Both are evaluated at the same point (IMU corner) so they must be identical
   - If they differ, the evaluation point was wrong

4. **Tune density to 200 Hz target**
   - Run eigenfrequency study, read f1
   - rho_new = rho_current * (f_current / 200)^2
   - Re-run both studies after density change
   - Re-export all 4 data files

5. **Check Nyquist and report suppression**
   - Run dvf_main.m with mode_select=3
   - Verify locus does not encircle (-1, 0)
   - Record exact suppression dB from console output
   - Fill in the TODO placeholders in report.tex conclusions section

6. **Gridplate section in report**
   - Obtain actual ASML gridplate dimensions and material from ASML documentation
   - Replace TODO items in Section 12.2 of report.tex with actual numbers
   - Re-run eigenfrequency study with gridplate geometry to predict modal frequencies

7. **Optional: run time_response_dvf.m**
   - Needs all 4 data files to be correct first (steps 1-3)

---

## Key Decisions (Do Not Revisit)

| Decision | Reason |
|----------|--------|
| DVF not PPF for Phase II | PPF phase is -90 deg with accelerometer (on boundary, not safe) |
| DVF not IRC for Phase II | IRC stability proof requires piezo voltage sensor, not accelerometer |
| K(s) = +g*S/(s+S) | solid.accZ uses +w^2 convention; literature -g assumes -w^2 |
| Domain Spring Foundation | Only BC consistent between Study 1 and Study 2 AND driveable by Base Excitation |
| Mode 3 at 161 Hz as DVF target | Mode 1 at 87 Hz has feedthrough-distorted phase, not controllable with simple DVF |
| nx=2 for ssest | One complex pole pair per resonance; wider fits produce unphysical modes |
| ssest window: f1 +/- 40 Hz | Prevents fitting multiple resonances simultaneously |
| No Rigid Motion Suppression | Different eigenmodes from spring foundation = inconsistent MIMO matrix |
| Overleaf gets only report.tex | Other files (MATLAB, Python, PPTX) clutter the Overleaf file tree |

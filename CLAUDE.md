# ImuActuator - ASML Plate Active Vibration Control
**Owner:** Isaak Bouwmeester, ASML internship  
**Last updated:** 2026-06-16  

## Formatting Rule - No Em Dashes

Never use em dashes (—) anywhere in this project: MATLAB plot titles, axis labels, legend
entries, code comments, fprintf/error messages, or markdown. Use a regular hyphen (-) instead,
or restructure the sentence. Applies to all .m and .md files in this folder.

**Folder structure:**
```
ImuActuator/
  CLAUDE.md                             this file
  TransferFunctionrealplateIMU.mph      COMSOL model (IMU variant)
  matlab/
    plot_H22_accel.m                    Bode plot of H22_accel.txt
    dvf_design.m                        DVF controller design + Nyquist
    time_response_dvf.m                 Time-domain simulation
    H22_accel.txt                       COMSOL export: IMU acc / Va
    H11.txt                             (old export, magnitude only)
    H12.txt                             (old export, magnitude only)
  papers/
    Controlling_Plate_Vibrations_Using_Piezoelectric_A.pdf   (Falangas 1994)
    Active damping of a beam...pdf                            (Gatti 2007)
    Smart panel with active damping units...pdf               (Gonzalez Diaz 2008)
    Acceleration sensors based modal...pdf                    (Qiu 2009)
    Integral resonant control...pdf                           (Aphale 2007)
```

---

## 1. Project Overview

The ASML measurement plate (~1x1 m aluminum, ~100 mm thick) experiences floor vibrations during
lithography that drive its first bending mode (~156 Hz from measured COMSOL data, tuned to ~200 Hz
by adjusting density). Goal: suppress this mode with active vibration control (AVC).

**Two phases:**
- **PPF approach** (original): PI Ceramic P-876.A12 DuraAct patch as actuator (Patch 2) + second
  DuraAct patch as open-circuit voltage sensor (Patch 3). PPF controller. Model: `piezo_patch_mimo.mph`.
- **ImuActuator approach** (this folder): Same actuator patch, sensor replaced by MEMS accelerometer
  (IMU) at a point on the plate surface. DVF controller. Model: `TransferFunctionrealplateIMU.mph`.

---

## 2. Physical Setup

### Plate
- Material: Aluminum (density tuned to hit target resonance frequency)
- Geometry: ~1000x1000 mm footprint, ~100 mm thick, from `DummyPlateOwn.stl`
- Boundary condition: **Domain Spring Foundation on plate domain** (NOT boundary Spring Foundation, NOT Fixed Constraint on edges)
  - kz isotropic spring constant per reference volume: ~2.7e6 N/m^3 (gives mount resonance ~5 Hz for rho=2700)
  - Formula: kz_vol = (2*pi*f_mount)^2 * rho [N/m^3] - tune f_mount to match real isolator frequency
  - Typical ASML isolator range: f_mount = 2-10 Hz -> kz_vol = 4e5 to 1.1e7 N/m^3
  - **[CORRECTED 2026-06-15] Fixed Constraint on edge lines is for the PPF model only. IMU model uses Domain Spring Foundation.**

### Actuator: PI Ceramic P-876.A12 DuraAct
| Layer | Footprint | Thickness | Material |
|-------|-----------|-----------|----------|
| Bottom polymer | 61x35 mm | 0.15 mm | DuraAct Polymer (E=5 GPa, nu=0.35, rho=1350) |
| PIC255 ceramic | 50x30 mm | 0.20 mm | PIC255 (active layer) |
| Top polymer | 61x35 mm | 0.15 mm | DuraAct Polymer |

- Coupling mode: d31 (bending) - poling through thickness = z-axis = COMSOL Global coordinates, NO rotation needed
- d31 = -260 pm/V (override from datasheet), epsilonrT33 = 1355 (override)
- COMSOL defaults for PIC255 are wrong - must override these 3 values every time
- Va applied to top face of PIC255 (at z = z_top + 0.35 mm), Ground on bottom face (z = z_top + 0.15 mm)

### IMU Sensor (ImuActuator variant)
- MEMS accelerometer glued to plate top surface
- Modelled as a single **Point** geometry in COMSOL (0D - no mass, no stiffness added)
- Position: x_antinode1 + 65 mm, y_antinode1, z_top (plate corner - NOT plate center)
- COMSOL expression: `solid.accZ` [m/s^2/V when Va = 1V]
- **`solid.wtt` does not exist in COMSOL frequency domain - use `solid.accZ` [CORRECTED 2026-06-07]**

---

## 3. Phase Conventions - Critical

This section explains why your H22_accel results look different from papers like Falangas (1994).

### The math

For harmonic motion x(t) = X * e^{jwt}, differentiating twice:

```
a(t) = (jw)^2 * X * e^{jwt} = -w^2 * X * e^{jwt}
```

The factor `-w^2` has **magnitude** = w^2, **phase** = 180 deg (because -1 sits at 180 deg on the
complex plane). So physical acceleration phasor = displacement phasor **shifted by +180 deg**.

### Two conventions

| Convention | Formula | Who uses it |
|------------|---------|-------------|
| Physical | a_phasor = (jw)^2 * x = **-w^2** * x | Real accelerometers, Falangas lab |
| COMSOL `solid.accZ` | a_phasor = **+w^2** * x | COMSOL FEM solver |

COMSOL uses the positive convention because its equation of motion is `(K - w^2*M + jwC)*U = F`,
where `w^2*M*U` is the inertia term written with positive w^2. `solid.accZ` is derived from
this term, not from a time derivative. This is a solver convention, not an error.

### Result: what you actually see

| Frequency range | Your COMSOL `solid.accZ` phase | Falangas physical accelerometer |
|----------------|-------------------------------|----------------------------------|
| Below resonance (DC) | 0 deg | 180 deg (= -180 deg) |
| At resonance | -90 deg | -270 deg (= +90 deg) |
| Above resonance | -180 deg | -360 deg (= 0 deg) |

**Same physics. Same amplitude. 180 deg sign convention difference.**

### What the old tutorials said (INCORRECT - do not follow)

Old SESSION_CONTEXT.md and comsol_imu_delta_tutorial.md stated:
- "H22_accel phase at resonance: ~-168 deg"
- "The factor -w^2 adds +180 deg phase vs piezo sensor"

These were written assuming COMSOL uses the physical convention. This is WRONG.
With `solid.accZ` using +w^2:
- Phase at resonance is **-90 deg** (not -168 deg)
- Phase below resonance is **0 deg** (not 180 deg)

### Actual H22_accel.txt measurement results

From the real COMSOL data exported (1-250 Hz):
- Resonance 1: ~84 Hz (small, possibly near a node)
- Resonance 2 (main): ~156-157 Hz (main bending mode)
- Phase at 1 Hz: 0 deg (confirmed positive real)
- Phase crosses -90 deg around 157 Hz (main resonance)
- Phase approaches -180 deg above ~160 Hz

The model was tuned for 200 Hz but the actual resonance landed at ~156 Hz. Either the density
was not tuned, or the STL geometry gives a different stiffness than expected.

---

## 4. COMSOL Tutorial Part 1 - Plate FRF Model (frf.mph)

**Goal:** Find eigenfrequency f1 and strain antinodes for patch placement.
**Output:** f1 in Hz, strain heatmap showing where to bond patches.

### Phase 1: Create New Model

**Step 1: Open COMSOL and Start Model Wizard**

Path: File > New > Model Wizard
- Space Dimension: 3D > click Next
- Add Physics: Structural Mechanics > Solid Mechanics (solid) > click Add > click Next
- Select Study: General Studies > Eigenfrequency > click Done

### Phase 2: Import Plate Geometry

**Step 2: Save Model File**

Path: File > Save As  
Filename: (your path)/frf.mph

**Step 3: Import DummyPlateOwn.stl**

Path: Component 1 > Geometry 1 > Geometry toolbar > Import  
Settings:
- File: DummyPlateOwn.stl
- Length unit: m (meters)

Click Import > Build All Objects (F8).  
Verify: plate appears in Graphics window.

**Step 4: Measure Bounding Box**

Path: Right-click Geometry 1 > Measure (or Tools > Measure)

Record:
| Coordinate | Min | Max | Center/Top |
|------------|-----|-----|------------|
| x | xmin | xmax | x_center = (xmin+xmax)/2 |
| y | ymin | ymax | y_center = (ymin+ymax)/2 |
| z | zmin (bottom) | z_top = zmax | - |

Expected: ~1000x1000 mm footprint, ~100 mm thick.

### Phase 3: Material and Physics Setup

**Step 5: Add Aluminum Material**

Path: Materials node > right-click > Add Material from Library  
Navigate to: Built-in > Metals > Al - Aluminum  
Click Add to Component > Close

Verify: E = 70 GPa, rho = 2700 kg/m^3, nu = 0.33, all domains selected.

**Step 6: Fixed Constraint on Bottom Edge Lines [CRITICAL]**

Path: Right-click Solid Mechanics (solid) > Add > Fixed Constraint

In Settings panel:
- Geometric entity level: change from "Boundary" to **"Edge"**

In Graphics window, select the 4 edge lines at z = zmin (bottom perimeter).
Hold Ctrl to multi-select.

Verify: 4 edges highlighted yellow.

Why edge lines (not face, not corners):
- Face constraint: every bottom node locked, plate cannot flex -> f1 ~ 6500 Hz (wrong)
- Corner springs: fills all eigenfrequency slots with near-zero rigid body modes
- Edge lines: correct clamped-perimeter boundary -> f1 ~ 200 Hz range

**Step 7: Add Boundary Load**

Path: Right-click Solid Mechanics (solid) > Add > Boundary Load  
Settings:
- Geometric entity level: Boundary
- Select: top face of plate (z = z_top)
- Load type: Force per unit area
- Fz component: -1 N/m^2

### Phase 4: Mesh

**Step 8-9: Create and Build Free Tetrahedral Mesh**

Path: Mesh 1 > Mesh toolbar > Free Tetrahedral  
Settings: Element size preset: Fine  
Path: Right-click Mesh 1 > Build All (F8)

Expected: 20,000-80,000 elements. Status bar: "Mesh was built successfully."

### Phase 5: Eigenfrequency Study

**Step 10: Configure and Run Eigenfrequency Study**

Path: Study 1 > Step 1: Eigenfrequency  
- Desired eigenfrequencies: 10  
Path: Home toolbar > Compute (or right-click Study 1 > Compute)

**Step 11: Check Eigenfrequencies and Tune Density**

Path: Results > Derived Values > right-click > Eigenfrequency

If f1 is not the target frequency, tune density:
```
rho_new = rho_current * (f_current / f_target)^2
```

| Observed f1 | Formula | New rho (kg/m^3) |
|-------------|---------|-----------------|
| 300 Hz | 2700 * (300/200)^2 | 6075 |
| 400 Hz | 2700 * (400/200)^2 | 10800 |
| 150 Hz | 2700 * (150/200)^2 | 1519 |

Repeat until f1 ~ target (+-5 Hz acceptable).  
Record: f1 = _____ Hz, rho_final = _____ kg/m^3

### Phase 6: Frequency Domain Study (FRF)

**Step 12: Add Structural Damping**

Path: Solid Mechanics > Linear Elastic Material > right-click > Add > Damping and Loss  
Settings:
- Damping type: Structural loss factor
- Loss factor eta: 0.02

**Step 13: Add and Run Frequency Domain Study**

Path: Home toolbar > Add Study > General Studies > Frequency Domain > Add Study  
Path: Study 2 > Step 1: Frequency Domain  
- Frequencies: range(1, 1, 500)  
Path: Right-click Study 2 > Compute

Expected solve time: 5-15 minutes.

### Phase 7: Post-Processing

**Step 14: Strain Heatmap**

Path: Results > right-click > 3D Plot Group > right-click > Surface  
Settings:
- Dataset: Study 1/Eigenfrequency (Mode 1)
- Expression: `solid.eXX + solid.eYY` (in-plane strain sum - correct for patch placement)
- Selection: top face of plate (z = z_top)
- Color table: Thermal

View from above: Camera > View Direction > +z  
Export: Right-click > Export > Image

Why `solid.eXX + solid.eYY` and NOT `solid.mises`:
- `solid.mises` is Von Mises stress in Pa - shows load capacity, not deformation
- `solid.eXX + solid.eYY` is dimensionless strain - shows where plate deforms most

**Step 15: Read Antinode Coordinates**

Hover over peak red/yellow regions. Coordinates show in status bar.

Record:
- Patch 1 (exciter, NOT in COMSOL model): x1 = _____ mm, y1 = _____ mm
- Patch 2 (actuator): x_antinode1 = _____ mm, y_antinode1 = _____ mm

**Step 16: Bode Magnitude Plot**

Path: Results > right-click > 1D Plot Group > right-click > Point Graph  
Settings:
- Dataset: Study 2/Frequency Domain
- Expression: `20*log10(abs(solid.w))`
- Point: plate center (x_center, y_center, z_top)

**Step 17: Bode Phase Plot**

New 1D Plot Group > Point Graph  
Settings:
- Expression: `arg(solid.w) * 180/pi`  (use arg() NOT atan2 - COMSOL passes only real part to atan2)

Expected: Phase starts near 0 deg, crosses -90 deg at f1, ends near -180 deg.

### Phase 8: Save and Document

**Step 18-19: 3D Mode Shape (optional) and Save**

Mode shape: Results > 3D Plot Group > Surface, Dataset = Study 1/Eigenfrequency Mode 1,
Expression = solid.w. Add Deformation node with scale 1e4.

---

## 5. COMSOL Tutorial Part 2 - PPF Model with Piezo Sensor (piezo_patch_mimo.mph)

**Goal:** Compute H22 = Vs/Va (sensor voltage / actuator voltage).  
**Hardware:** Patch 2 (actuator) + Patch 3 (sensor), both P-876.A12 DuraAct.

### Step 21: Create New Model

Path: File > New > Model Wizard > 3D  
Physics: Structural Mechanics > Electromagnetics-Structure Interaction > Piezoelectricity > Piezoelectricity, Solid  
Study: General Studies > Frequency Domain  
Save as: piezo_patch_mimo.mph

### Step 22: Import Plate Geometry

First set model length unit to mm:  
Path: Component 1 > Geometry 1 > Settings panel: Length unit = mm

Path: Geometry 1 > Import  
File: DummyPlateOwn.stl  
Settings: Source length unit: m (COMSOL converts to mm)  
Click Import then Build All Objects.

Verify dimensions (all in mm): footprint ~1000x1000, thickness ~100. Record z_top = zmax.

### Step 23: Add Six Blocks (Two Patches, 3 Layers Each)

Use x_antinode1, y_antinode1 from Step 15. z_top from Step 22.

**Layer stack (P-876.A12, confirmed from PI datasheet):**
| Layer | Footprint | Thickness | z position |
|-------|-----------|-----------|------------|
| Top polymer | 61x35 mm | 0.15 mm | z_top+0.35 to z_top+0.50 |
| PIC255 ceramic | 50x30 mm | 0.20 mm | z_top+0.15 to z_top+0.35 |
| Bottom polymer | 61x35 mm | 0.15 mm | z_top to z_top+0.15 |

The ceramic (50x30 mm) is smaller than polymer (61x35 mm). Ceramic is centred within polymer.

**Patch 2 (actuator at x_antinode1, y_antinode1):**

Bottom polymer: Width=61, Depth=35, Height=0.15, x=(x_antinode1-30.5), y=(y_antinode1-17.5), z=z_top  
PIC255 ceramic: Width=50, Depth=30, Height=0.20, x=(x_antinode1-25.0), y=(y_antinode1-15.0), z=z_top+0.15  
Top polymer: Width=61, Depth=35, Height=0.15, x=(x_antinode1-30.5), y=(y_antinode1-17.5), z=z_top+0.35

**Patch 3 (sensor, offset 65 mm in x):**

Same three blocks with x offsets: replace (x_antinode1-30.5) with (x_antinode1-30.5+65),
and (x_antinode1-25.0) with (x_antinode1-25.0+65).

Click Build All Objects. Verify total patch height = 0.15+0.20+0.15 = 0.50 mm.

### Step 24: Union - Bond Patches to Plate

Path: Geometry toolbar > Boolean and Partitions > Union  
Select: plate body + all 6 patch blocks.  
Settings: **Keep interior boundaries = ON** (critical - preserves layer boundaries)  
Click Build All Objects.

Verify: 7 domains exist (1 plate + 2 patches x 3 layers).

### Step 25: Assign Materials

**Aluminum - plate domain:**  
Path: Materials toolbar > Add Material > MEMS > Metals > Al - Aluminum  
Select plate domain only.

**DuraAct Polymer - 4 polymer domains (top + bottom of each patch):**  
Path: Materials > right-click > Blank Material, label "DuraAct Polymer Encapsulation"  
Select 4 polymer domains.

| Property | Variable | Value | Unit |
|----------|----------|-------|------|
| Young's modulus | E | 5e9 | Pa |
| Poisson's ratio | nu | 0.35 | 1 |
| Density | rho | 1350 | kg/m^3 |

E = 5 GPa back-calculated from PI official assembly E = 23.3 GPa for P-876.A12. GFRP (25 GPa) ruled out.

### Step 26: Assign PIC255 to Ceramic Domains [CORRECTED 2026-05-17]

Path: Materials toolbar > Add Material > search "PIC255" > Piezoelectric > PIC255  
Select 2 PIC255 ceramic domains only (NOT polymer layers).

**Override these 3 values from P-876.A12 datasheet:**
| Parameter | COMSOL default | Set to | Derivation |
|-----------|---------------|--------|------------|
| dET31 = dET32 | -18.5e-11 C/N | **-26.0e-11 C/N** | 1.3e-6 m/m/V x 200e-6 m = 260 pm/V |
| epsilonrT33 | 1832 | **1355** | C=90nF, A=1500mm^2, t=200um |
| Block height | - | 0.20 mm | already done in Step 23 |

How to override: In Materials > PIC255 > Piezoelectric coupling matrix d > click d31 cell > type -26.0e-11 > Enter. Same for d32. Find Relative permittivity > epsilonrT 33 component > set 1355.

### Step 27: Add Piezoelectric Material Coupling Node

Path: Solid Mechanics (solid) > right-click > Piezoelectric Material  
Settings:
- Domain Selection: PIC255 ceramic domains only
- Coordinate System: **Global coordinate system** (no rotation needed for d31 patches)

### Step 28: Fixed Constraint on Bottom Edge Lines

Same as Step 6 (4 bottom edge lines, Geometric entity level = Edge).

### Step 29: Apply Voltage to Patch 2 (Actuator) [CORRECTED 2026-05-17]

**CRITICAL:** Electric Potential is in Electrostatics (es), not Solid Mechanics toolbar.

Path: Click **Electrostatics (es)** in Model Builder > Physics toolbar > Boundaries > Electric Potential  
- Select: top face of PIC255 Patch 2 (z = z_top + 0.35 mm)
- V0 = 1 [V], Label: V_actuator

Path: Electrostatics (es) > Physics toolbar > Boundaries > Ground  
- Select: bottom face of PIC255 Patch 2 (z = z_top + 0.15 mm)
- Label: Ground_actuator

### Step 30: Apply Floating Potential to Patch 3 (Sensor) [CORRECTED 2026-05-17]

**COMMON MISTAKE:** Do NOT add Ground to Patch 3 bottom. Ground forces V=0, corrupting sensor voltage.
Both top AND bottom ceramic faces of Patch 3 go into ONE Floating Potential node, nothing else.

Path: Click Electrostatics (es) > Physics toolbar > Boundaries > Floating Potential  
- Select: top face AND bottom face of PIC255 Patch 3 (both in one node)
- Label: Floating_sensor

To read Vs after solving:  
Path: Results > Derived Values > right-click > Average > Surface Average  
- Expression: `V` (NOT es.V)
- Selection: top face of Patch 3

### Step 31: Create Mesh

Path: Mesh toolbar > Free Tetrahedral  
- Domain Selection: All domains, Element Size: Fine

Add refinement:  
Right-click Mesh 1 > Free Tetrahedral (second)  
- Domain Selection: patch domains only, Element Size: Finer

Build All. Expected: 20,000-60,000 elements.

### Step 32: Configure and Run Frequency Domain Study

Path: Study 1 > Frequency Domain  
Frequencies: `range(1, 1, 500)` Hz  
Click Compute. Expected: 5-20 minutes.

### Step 33: Extract H22 = Vs/Va (PPF Design Transfer Function)

**H22 magnitude:**
Path: Results > right-click > 1D Plot Group > right-click > Point Graph  
- Dataset: Study 1/Frequency Domain
- Expression: `20*log10(abs(V))` (use V not es.V)
- Selection: point on top face of Patch 3

**H22 phase:**  
- Expression: `arg(V) * 180/pi` (use arg() not atan2 - COMSOL passes only real part to atan2)

PPF stability check: phase must cross -90 deg at f1.  
If phase stays near +12 deg and never crosses -90 deg: check Floating Potential BC on Patch 3.

### Phase 10: Base Excitation Study (H11, H21)

**Step 34: Add Base Excitation Node [CORRECTED 2026-05-20]**

Path: Click Solid Mechanics (solid) > Physics toolbar > Domains > More > Base Excitation  
Settings:
- Geometric entity level: Edge
- Selection: same 4 bottom perimeter edges as Fixed Constraint
- Base excitation type: Acceleration
- z-component: 1[m/s^2], x=0, y=0

Right-click Base Excitation > Disable (will enable only for Study 2).

**Step 35: Add Study 2**

Path: Home toolbar > Add Study > General Studies > Frequency Domain  
Frequencies: range(1, 1, 500) Hz

In Study 2 > Step 1 > Physics and Variables Selection:
| Node | Action in Study 2 |
|------|------------------|
| V_actuator (Electric Potential) | Disable |
| Ground_actuator | Disable |
| Floating_sensor | Keep enabled |
| Base Excitation (bex1) | Enable (override global disable) |
| Fixed Constraint (fix1) | Keep enabled |

To enable a globally-disabled node: check "Override physics node activity" > find Base Excitation > set Active.

**Step 36: Compute Study 2**

Path: Right-click Study 2 > Compute (NOT Compute All - that re-runs Study 1).

**Step 37: Extract H11**

- Dataset: Study 2/Solution 2
- Expression: `20*log10(abs(solid.w / 1[m/s^2]))` (displacement transmissibility)
- Point: plate center
- Export to: H11_data.txt

**Step 38: Extract H21**

- Expression: `20*log10(abs(V / 1[m/s^2]))` at top face of Patch 3
- Export to: H21_data.txt

**Step 39: Export Numerical Data for MATLAB**

Path: Results > Export > Data  
Format: Spreadsheet (txt), include header, frequency as first column.

Export expressions as: `real(V)`, `imag(V)` for H22.  
Export expressions as: `real(solid.w/1[m/s^2])`, `imag(solid.w/1[m/s^2])` for H11 and H21.

**Step 40: MATLAB - PPF Closed-Loop**

```matlab
% PPF controller (Baken Eq. 9)
K_ppf = 1/H0 * g * tf(omega_f^2, [1  2*zeta_f*omega_f  omega_f^2]);

% Closed-loop (Baken eq. 10)
T = feedback(HOLc, K_ppf, 2, 2, +1);
```

---

## 6. COMSOL Tutorial Part 3 - IMU Accelerometer Variant

**Model file:** `TransferFunctionrealplateIMU.mph`  
**Key difference:** Patch 3 removed, IMU point added, extract `solid.accZ` instead of `V`.  
**H22:** a_z / Va [m/s^2/V]

### Differences from PPF tutorial (Phases 9-10)

| Step | PPF tutorial | IMU tutorial |
|------|-------------|--------------|
| Step 23 | 6 blocks (2 x 3 layers) | **3 blocks only (Patch 2 actuator)** |
| Step 23b | - | **Add IMU Point geometry** |
| Step 24 | Union 7 objects -> 7 domains | **Union 4 objects -> 4 domains** |
| Step 30 | Floating Potential on Patch 3 | **REMOVED - no Patch 3** |
| Step 33 | `V` on Patch 3 face -> V/V | **`solid.accZ` at IMU point -> m/s^2/V** |
| Step 33b | - | **H12_accel at IMU corner** |
| Step 37-38 | `solid.w / 1[m/s^2]` | **`solid.accZ / 1[m/s^2]`** |
| Step 40 | PPF, ppf_design.m | **DVF, dvf_design.m** |

### Step 23 [CHANGED]: Add Only Three Blocks (Patch 2 Only)

Do NOT add Patch 3 blocks. Only add the 3 layers for Patch 2:
| Layer | Size | Position |
|-------|------|----------|
| Bottom polymer | 61x35x0.15 mm | x=x_antinode1-30.5, y=y_antinode1-17.5, z=z_top |
| PIC255 ceramic | 50x30x0.20 mm | x=x_antinode1-25.0, y=y_antinode1-15.0, z=z_top+0.15 |
| Top polymer | 61x35x0.15 mm | x=x_antinode1-30.5, y=y_antinode1-17.5, z=z_top+0.35 |

Total: 3 blocks + 1 plate = 4 objects.

### Step 23b [NEW]: Add IMU Point Geometry

Path: Geometry toolbar > More Primitives > Point  
Settings:
- x: `x_antinode1 + 65`
- y: `y_antinode1`
- z: `z_top` (plate top surface where accelerometer is glued)

Click Build All Objects.

This point is NOT part of the Union - keep it as a separate geometry feature.
COMSOL preserves it through the Union. Use it only for result extraction.

### Step 24 [CHANGED]: Union 4 Objects

Select: plate body + 3 patch blocks (NOT the IMU point).  
Keep interior boundaries = ON.  
Verify 4 domains exist:
1. Plate (aluminum)
2. Bottom polymer (Patch 2)
3. PIC255 ceramic (Patch 2)
4. Top polymer (Patch 2)

### Step 30 [REMOVED]: No Floating Potential

Do NOT add Floating Potential. There is no Patch 3 electrode.

### Step 33 [CHANGED]: Extract H22_accel = a_z / Va

**H22_accel magnitude:**
Path: Results > right-click > 1D Plot Group > right-click > Point Graph  
- Expression: `20*log10(abs(solid.accZ))`
- Selection: IMU point from Step 23b
- Label: H22_accel magnitude [m/s^2/V]

**H22_accel phase:**
New 1D Plot Group > Point Graph:
- Expression: `arg(solid.accZ) * 180/pi`
- Same IMU point

**Export numerical data for MATLAB:**
Path: Results > Export > Data, filename: H22_accel.txt  
Format: Spreadsheet, include header.  
Expression columns: `real(solid.accZ)`, `imag(solid.accZ)`  
First column: frequency in Hz.

**Expected phase curve (COMSOL convention):**
- At 1 Hz: phase ~ 0 deg (positive real, magnitude near zero)
- At resonance: phase ~ -90 deg
- Above resonance: phase approaches -180 deg

This is the correct result for COMSOL's `solid.accZ` with the +w^2 convention.
It is NOT -168 deg as old tutorials stated - that was based on wrong assumption.

### Step 33b [NEW]: Export H12_accel = a_z_corner / Va

New Point Graph in same or new 1D Plot Group:
- Expression: `solid.accZ` at IMU corner (x_antinode1+65, y_antinode1, z_top) - same point as H22, NOT plate center
- Export to: H12_accel.txt

### Steps 34-38 [CORRECTED 2026-06-15]: Base Excitation with Domain Spring Foundation

**CRITICAL: Use Domain Spring Foundation, NOT Boundary Spring Foundation.**

The Base Excitation node only works correctly when paired with either:
- A Fixed Constraint on a boundary/edge, OR
- A **Domain** Spring Foundation (which has a built-in base displacement field)

Boundary Spring Foundation has NO base displacement field in COMSOL 6.4 and cannot be driven
by the Base Excitation node. Using Boundary Spring Foundation gives a flat, non-physical H11.

**Step 34: Add Domain Spring Foundation [CORRECTED 2026-06-15]**

Path: Solid Mechanics (solid) > Physics toolbar > **Domains** > Spring Foundation
Settings:
- Geometric entity level: **Domain**
- Selection: **plate domain only** (NOT patch domains)
- Spring type: Isotropic
- kz per reference volume: `2.7e6 [N/m^3]` (starting value for ~5 Hz mount resonance)
  Formula: kz = (2*pi*f_mount)^2 * rho_plate, tune f_mount to match real isolators

**Step 35: Add Base Excitation Node**

Path: Solid Mechanics (solid) > Physics toolbar > Domains > More > Base Excitation
Settings:
- Geometric entity level: Domain
- Selection: same plate domain as Spring Foundation
- Base excitation type: Acceleration
- z-component: `1[m/s^2]`, x=0, y=0

Right-click Base Excitation > Disable globally (enable only in Study 2 via Physics and Variables Selection).

**Step 36: Study 2 Physics and Variables Selection**

| Node | Action in Study 2 |
|------|------------------|
| V_actuator | Disable |
| Ground_actuator | Disable |
| Base Excitation | **Enable** (override global disable) |
| Domain Spring Foundation | Keep enabled |

**H11_accel = a_z_corner / a_base (transmissibility) [CORRECTED 2026-06-15]:**
- Expression: `20*log10(abs(solid.accZ / 1[m/s^2]))`
- Phase: `arg(solid.accZ / 1[m/s^2]) * 180/pi`
- Point: IMU corner (x_antinode1+65, y_antinode1, z_top) - same corner as IMU, NOT plate center
- Export to: H11_accel.txt as `freq | real(solid.accZ/1[m/s^2]) | imag(solid.accZ/1[m/s^2])`

**NOTE:** With Domain Spring Foundation + Base Excitation, `solid.accZ` returns absolute
acceleration directly. Do NOT add +1[m/s^2] - that correction was for Prescribed Acceleration
with relative formulation, which is the WRONG approach for this model.

**H21_accel = a_z_IMU / a_base (transmissibility) [CORRECTED 2026-06-15]:**
- Expression: `solid.accZ / 1[m/s^2]` at IMU point
- Export to: H21_accel.txt

---

## 7. H22_accel.txt - Measured Data

File: `matlab/H22_accel.txt`  
Format: `freq_Hz <tab> real+imag*i`  
Frequency range: 1-250 Hz (250 data points, non-uniform spacing)

**Key features:**
| Feature | Frequency | Notes |
|---------|-----------|-------|
| Small resonance | ~84 Hz | IMU may be near a node for this mode |
| Main resonance | ~156-157 Hz | Primary target for DVF control |
| Phase crosses -90 deg | ~157 Hz | (confirms main resonance location) |
| Above resonance | 160-250 Hz | Phase approaching -180 deg |
| Second bump | ~215-220 Hz | Another mode visible |

**Note:** Model was tuned for ~200 Hz but resonance landed at ~156 Hz.
Either density was not tuned in this model, or the STL gives different stiffness.
Verify eigenfrequency and re-tune density if needed.

**Data format example:**
```
1.0000    1.8938E-7-3.5348E-9i
11.000    2.3025E-5-4.3210E-7i
...
156.00    6.4583E-2-1.4549E-1i
157.00   -3.2766E-2-1.6718E-1i
...
```

---

## 8. MATLAB Scripts (in matlab/ subfolder)

### plot_H22_accel.m

Loads H22_accel.txt, plots Bode (magnitude + unwrapped phase), full frequency range.
Also shows equivalent displacement H22_disp = H22_accel / (-w^2).

Run from the `matlab/` folder (cd(fileparts(mfilename('fullpath'))) handles this automatically).

### dvf_design.m

Full DVF controller design workflow:
1. Loads all 4 MIMO transfer functions (H11, H12, H21, H22)
2. Assembles MIMO FRD object
3. Reports H22 phase at resonance
4. Designs K(s) = -g * S/(s+S), g=1e-3, S=5 rad/s
5. **Nyquist stability check** (MUST verify before hardware)
6. Bode plots of H22 and controller
7. Closed-loop via `feedback(HOLc, K_dvf, 2, 2, -1)`
8. Multiple gain sweep
9. Discretisation (Tustin, 10 kHz)

**Currently only H22_accel.txt exists. H11, H12, H21 files need COMSOL export.**

### time_response_dvf.m

Time-domain simulation (requires all 4 data files):
- Fits state-space model via `ssest`
- Impulse response (DVF off vs on)
- Sine excitation at f1, disturbance switched off at t=6s
- DVF switched on at t=6s equivalent

---

## 9. DVF Controller Design

### Why DVF (not PPF, not IRC)

| Strategy | Phase requirement | Your H22_accZ phase at resonance | Applicable? |
|----------|-------------------|----------------------------------|-------------|
| PPF | -90 deg to +90 deg | -90 deg (borderline) | No - unstable |
| IRC | 0 deg to -180 deg | -90 deg... but proof requires piezo voltage sensor | No |
| **DVF** | Works with acceleration, conditionally stable | -90 deg | **Yes** |

**PPF:** Phase of H22_accZ at resonance is -90 deg with COMSOL convention. PPF requires phase
between -90 and +90 deg to guarantee stability. This is right at the boundary - not safe.

**IRC:** IRC stability proof (Aphale 2007) requires a collocated piezo VOLTAGE sensor (charge/strain
output). The negative imaginary property assumed by IRC holds for displacement-output systems.
With an acceleration sensor, the proof does not apply regardless of phase values.

**DVF:** Integrate accelerometer -> velocity, apply negative gain. Theoretically unconditional for
point-force actuator + point-velocity sensor (Balas 1979). For patch actuator + point accelerometer:
**conditionally stable** (Gatti 2007) - patch applies distributed bending moment, not a point force,
so control collocation is not achieved. Maximum stable gain exists. Nyquist check is mandatory.

### DVF Controller

```matlab
g = 1e-3;    % gain [V/(m/s)] - tune this, start small
S = 5;       % first-order lag pole [rad/s] ~ 0.8 Hz cutoff (Falangas 1994)
s = tf('s');
K_dvf = g * S / (s + S);    % NOTE: +g, not -g - see sign convention note below
```

The first-order lag (S/(s+S)) avoids DC drift from a pure integrator while approximating 1/s
for frequencies >> S. S = 5 rad/s (Falangas value) places the cutoff well below resonance.

Pure integrator alternative: `K_dvf_pure = g / s` (cleaner math, amplifies low-freq noise).

**[CRITICAL SIGN CONVENTION - CONFIRMED 2026-06-16]** Falangas (1994) writes K(s) = -g*S/(s+S)
assuming PHYSICAL acceleration feedback (a = -w^2*x, see section 3 above). COMSOL's solid.accZ
uses the OPPOSITE convention (a = +w^2*x). Feeding solid.accZ directly into the literature's
negative-gain formula flips intended negative (damping) feedback into positive (anti-damping)
feedback - the closed loop AMPLIFIES at resonance instead of suppressing it.

**Symptom of the wrong sign:** suppression dB shows POSITIVE values that GROW with gain
(e.g. +3 dB at 30% g_max, +13 dB at 80% g_max), and the Nyquist gain-margin search lands
exactly on f1 (the target mode), which should never happen for a properly-signed loop -
the gain limit should come from a different, non-collocated mode (Gatti 2007).

**Fix:** use K(s) = +g*S/(s+S) (drop the literature's leading minus sign) when working
directly with solid.accZ data. This is what `dvf_main.m` does.

### Stability Check (Nyquist)

```matlab
jw = 1j * 2*pi * freq;
lag_filter = S ./ (jw + S);
H22_vel = H22_complex .* lag_filter ./ jw;   % velocity/Va through lag filter
L_resp = g * H22_vel;                         % loop gain magnitude
% Plot Nyquist: loop must NOT encircle (-1, 0)
```

If the Nyquist plot encircles -1: reduce g or add a phase-lag compensator.
If gain is at stability limit: add ~10% point mass at IMU location (Gatti 2007 trick) to
increase roll-off and extend the stable gain range.

### Closed-Loop (MATLAB)

```matlab
T = feedback(HOLc, K_dvf, 2, 2, -1);
```

Where HOLc is the 2x2 MIMO FRD with inputs {A_base, Va} and outputs {A_tip, A_imu}.
The `-1` flag = negative feedback. K_dvf already has a negative sign so the overall
feedback path is negative x negative = positive feedback convention used in DVF.

### Expected Performance

Based on Falangas (1994) - closest published experiment to this setup:
- Rate feedback (DVF): ~10.5 dB at first symmetric mode
- H-infinity: ~17 dB at anti-symmetric modes

Use Falangas Figure 7 as the qualitative template for your closed-loop Bode plot shape.

---

## 10. Literature Summary

### Primary References (in papers/ folder)

**Falangas, Dworak & Koshigoe (1994) - READ FIRST**  
IEEE Control Systems Magazine 14(4):34-41  
Flat rectangular aluminum plate (0.5x0.6 m, 1 mm thick), 5 PZT patch pairs, 5 accelerometers,
rate feedback + H-infinity control. Figure 7 = baseline for your closed-loop FRF shape.
Rate feedback achieves ~10.5 dB at first mode.

**Gatti, Brennan & Gardonio (2007) - Stability Reference**  
JSV 303:798-813, DOI: 10.1016/j.jsv.2007.02.006  
Aluminum beam + PZT patch actuator + collocated accelerometer. Shows physically collocated
pair is NOT control-collocated (patch = distributed moment, not point force). DVF conditionally
stable. Maximum stable gain quantified. Adding ~10% mass at sensor increases stable gain range.

**Gonzalez Diaz, Paulitsch & Gardonio (2008) - Less Relevant**  
JASA 124(2):898-910  
Uses proof-mass electrodynamic actuators, not PZT patches. DVF topology same but actuator
physics differs. Results (up to 30 dB) are NOT directly applicable to PZT setup.

**Qiu, Zhang, Zhang & Han (2009) - Workflow Reference**  
Aerospace Science and Technology 13(6):306-314  
Fiberglass cantilever plate, very low resonance frequencies. Shows full workflow from COMSOL
to measured H22 to controller. Wrong material/frequency range for direct comparison.

**Aphale, Fleming & Moheimani (2007) - Reference Only, NOT Applicable Here**  
Smart Materials and Structures 16(2):439-446  
IRC controller for collocated piezo-piezo pairs. 22-24 dB per mode. NOT applicable to
accelerometer sensors - the stability proof assumes piezo voltage sensor output.

### Papers NOT in folder (need to download)

**Aoki, Gardonio & Elliott (2006) - Most Directly Applicable**  
Euronoise 2006. Stability analysis for flat panel + patch actuator + point accelerometer.
ResearchGate: https://www.researchgate.net/publication/290059063

### Key Books

| Book | Relevance |
|------|-----------|
| Preumont - Vibration Control of Active Structures, 4th ed. (Springer 2018) | Chapter 7: acceleration feedback phase, DVF stability |
| Moheimani & Fleming - Piezoelectric Transducers for Vibration Control (Springer 2006) | IRC design, accelerometer feedback |

---

## 11. COMSOL Expressions Quick Reference

| Quantity | Expression | Study | Notes |
|----------|-----------|-------|-------|
| Z-acceleration at IMU (dB) | `20*log10(abs(solid.accZ))` | Study 1 (Va=1V) | H22 magnitude |
| Z-acceleration phase | `arg(solid.accZ) * 180/pi` | Study 1 | -90 deg at resonance (COMSOL convention) |
| H11 transmissibility (magnitude) | `20*log10(abs(solid.accZ / 1[m/s^2]))` at IMU corner | Study 2 (base, Domain SF) | dB - NO +1 correction |
| H11 transmissibility (phase) | `arg(solid.accZ / 1[m/s^2]) * 180/pi` at IMU corner | Study 2 (base, Domain SF) | deg |
| H21 (IMU corner / base, magnitude) | `20*log10(abs(solid.accZ / 1[m/s^2]))` at IMU corner | Study 2 | dB |
| H21 (IMU corner / base, complex export) | `solid.accZ / 1[m/s^2]` at IMU corner | Study 2 | dimensionless complex |
| H12 (corner / Va) | `solid.accZ` at IMU corner (x_antinode1+65, y_antinode1, z_top) | Study 1 | m/s^2/V |
| Equivalent displacement | `solid.accZ / (-(2*pi*freq)^2)` | Either | m/V |
| Z-displacement | `solid.w` | Either | m/V |
| Piezo sensor voltage | `V` (NOT es.V) | Study 1 | V/V |
| In-plane strain sum | `solid.eXX + solid.eYY` | Eigenfrequency | for patch placement heatmap |
| Max principal strain | `solid.epe1` | Eigenfrequency | alternative heatmap |
| Phase from displacement | `arg(solid.w) * 180/pi` | Freq domain | use arg() not atan2 |
| ~~solid.wtt~~ | ~~does not exist~~ | - | **[CORRECTED 2026-06-07] use solid.accZ** |

---

## 12. Common COMSOL Errors

| Symptom | Cause | Fix |
|---------|-------|-----|
| f1 ~ 6500 Hz | Fixed Constraint on entire bottom face | Change to Edge constraint on 4 bottom perimeter edge lines |
| All eigenfreqs ~ 0.02 Hz | Springs at corners fill all slots | Use Fixed Constraint on bottom edge lines |
| Bode has no resonance peak | Evaluation point outside plate, or damping too high | Check coordinates from Step 4; verify eta = 0.02 |
| Phase does not cross -90 deg | Multiple modes overlapping, or wrong dataset | Increase frequency resolution; verify Study 2 dataset |
| Strain heatmap is uniform | Wrong dataset or expression | Dataset = Eigenfrequency Mode 1; expression = solid.eXX + solid.eYY |
| H22 phase reads ~12 deg (PPF only) | Ground BC accidentally on Patch 3 | Delete Ground from Patch 3; use Floating Potential only |
| Electric Potential button not visible | Solid Mechanics selected instead of Electrostatics | Click Electrostatics (es) in Model Builder first |
| es.V returns zero | Wrong variable name | Use V (not es.V) |
| atan2 phase returns 0 deg everywhere | COMSOL passes only real part to atan2 | Use arg(V) * 180/pi |
| solid.wtt not found | Does not exist in frequency domain | Use solid.accZ |
| H11 flat/stationary, no resonance with Boundary Spring Foundation + Base Excitation | Boundary Spring Foundation has no base displacement field - Base Excitation cannot drive it | Switch to Domain Spring Foundation (Domains tab, not Boundaries tab) |
| H11 shows values ~10^-5, rising slope, no resonance peak | Prescribed Acceleration uses relative formulation; solid.accZ = relative acceleration ~0 | Do NOT use Prescribed Acceleration for H11. Use Domain Spring Foundation + Base Excitation node |
| H11 flat at 0 dB after adding +1[m/s^2] correction | Prescribed Acceleration approach fundamentally incorrect for this model | Use Domain Spring Foundation + Base Excitation; expression is solid.accZ/1[m/s^2] with NO correction |
| Prescribed Acceleration applied to all domains gives stationary result | All DOFs kinematically prescribed - no free dynamics to solve | Prescribed Acceleration must go on bottom boundary only AND requires relative-frame correction - avoid entirely, use Domain Spring Foundation + Base Excitation instead |
| H11 and H22 have different eigenmodes (inconsistent MIMO) | Different BCs between Study 1 and Study 2 (e.g. Spring Foundation vs Rigid Motion Suppression) | Both studies must use the same BC: Domain Spring Foundation active in both |
| MATLAB: T21/T11 "suppression" is POSITIVE and grows with gain; Nyquist gain-margin lands exactly on f1 | DVF controller sign wrong for solid.accZ convention (literature -g flips to anti-damping) | Use K(s) = +g*S/(s+S), not -g*S/(s+S), with solid.accZ data [CONFIRMED 2026-06-16] |
| H22 peak frequency != mode where actuator was placed for max strain | H22 depends on actuator coupling INTO a mode AND IMU coupling OUT of that mode - actuator antinode for mode A does not guarantee mode A dominates if IMU is near mode A's node | Check IMU corner against the mode shape of the mode you intend to target, not just actuator placement |

---

## 13. What Remains To Do

Priority order:

1. **Verify/tune resonance frequency in TransferFunctionrealplateIMU.mph**  
   Run eigenfrequency study. If f1 is not near desired target, tune density using formula from Step 11.
   Current H22_accel.txt shows resonance at ~156 Hz (not 200 Hz as expected).

2. **Export H12_accel.txt, H21_accel.txt, H11_accel.txt from COMSOL**  
   Format: `freq_Hz <tab> real+imag*i` (same as H22_accel.txt)

3. **Run plot_H22_accel.m**  
   Verify phase is ~-90 deg at f1 (COMSOL convention). If significantly different, check IMU point is on plate surface (z = z_top), not inside a patch domain.

4. **Run dvf_design.m**  
   Check Nyquist plot first. Tune gain `g` for target suppression (~10-15 dB at f1).
   Compare closed-loop shape to Falangas (1994) Figure 7.

5. **Run time_response_dvf.m**  
   Shows settling with DVF on vs off.

6. **Optional: H-infinity controller**  
   Falangas (1994) shows H-inf gives better focused suppression (~17 dB vs ~10 dB for rate feedback).
   Requires fitting ssest then using hinfsyn.

---

## 14. Key Decisions Made (Do Not Revisit)

| Decision | Rationale |
|----------|-----------|
| DVF is the controller, not IRC | IRC stability proof requires piezo voltage sensor, not accelerometer. Confirmed from Aphale (2007). |
| K(s) = -g * S/(s+S), S=5 rad/s | Falangas (1994) approach: avoids DC drift from pure integrator |
| DVF is conditionally stable | Confirmed from Gatti (2007): patch moment != point force. Nyquist check mandatory. |
| solid.accZ uses +w^2 convention | Confirmed from data: phase = 0 deg at 1 Hz (positive real). Physical convention would give 180 deg. |
| Old expected phase of -168 deg was wrong | Based on incorrect assumption that COMSOL uses physical (-w^2) convention |
| Correct expected phase at resonance: -90 deg | Confirmed from H22_accel.txt data (main resonance ~157 Hz, phase crosses -90 deg there) |
| Best reference paper: Falangas (1994) | Only paper with flat plate + PZT patches + accelerometers + rate feedback |
| IRC not applicable to accelerometer sensors | IRC negative imaginary property requires displacement/charge output, not acceleration |
| IMU modelled as geometry Point (0D) in COMSOL | Zero mass/stiffness effect. If mass loading matters, add Point Mass feature separately |
| Domain Spring Foundation (not boundary) for base excitation [CONFIRMED 2026-06-15] | Base Excitation node can only drive the base of a Domain Spring Foundation. Boundary Spring Foundation has no base displacement field in COMSOL 6.4 and silently fails. |
| H11/H21 expression is solid.accZ / 1[m/s^2] with NO +1 correction [CONFIRMED 2026-06-15] | Domain Spring Foundation + Base Excitation uses absolute formulation. solid.accZ is already absolute acceleration. The +1[m/s^2] correction was for the (wrong) Prescribed Acceleration approach. |
| Boundary Spring Foundation, Prescribed Acceleration, and Rigid Motion Suppression all rejected for H11 [CONFIRMED 2026-06-15] | Boundary SF: no base displacement field. Prescribed Acc: relative formulation, inconsistent MIMO. Rigid Motion Suppression: different eigenmodes from Study 1, inconsistent MIMO. |

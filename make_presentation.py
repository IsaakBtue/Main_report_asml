"""
Academic presentation: Active Vibration Control of an ASML Measurement Plate
Layout per slide: left column = bullet points to copy, right column = image
placeholder (gray box) or empty.
"""
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN

W = Inches(13.333)
H = Inches(7.5)

NAVY  = RGBColor(0x1F, 0x4E, 0x79)
BLUE  = RGBColor(0x2E, 0x75, 0xB6)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
DARK  = RGBColor(0x26, 0x26, 0x26)
GRAY  = RGBColor(0x59, 0x59, 0x59)
LGRAY = RGBColor(0xD6, 0xD6, 0xD6)
PGRAY = RGBColor(0xEC, 0xEC, 0xEC)  # placeholder background

MRG   = Inches(0.5)
L_W   = Inches(6.2)   # left column width
R_X   = Inches(7.2)   # right column x start
R_W   = Inches(5.6)   # right column width
C_Y   = Inches(1.15)  # content start y
C_H   = Inches(5.9)   # content height

prs = Presentation()
prs.slide_width  = W
prs.slide_height = H
BLANK = prs.slide_layouts[6]


# ------------------------------------------------------------------
def title_bar(slide, text):
    bar = slide.shapes.add_shape(1, 0, 0, W, Inches(1.0))
    bar.fill.solid(); bar.fill.fore_color.rgb = NAVY
    bar.line.fill.background()
    tb = slide.shapes.add_textbox(MRG, Inches(0.10), W - 2*MRG, Inches(0.82))
    tf = tb.text_frame; tf.word_wrap = True
    p  = tf.paragraphs[0]; r = p.add_run(); r.text = text
    r.font.bold = True; r.font.size = Pt(22); r.font.color.rgb = WHITE


def footer(slide, n, total):
    bar = slide.shapes.add_shape(1, 0, H - Inches(0.28), W, Inches(0.28))
    bar.fill.solid(); bar.fill.fore_color.rgb = LGRAY; bar.line.fill.background()
    tb = slide.shapes.add_textbox(MRG, H - Inches(0.26), Inches(10), Inches(0.24))
    tf = tb.text_frame; p = tf.paragraphs[0]; r = p.add_run()
    r.text = f"Isaak Bouwmeester  |  ASML Internship  |  June 2026  |  {n}/{total}"
    r.font.size = Pt(11); r.font.color.rgb = GRAY


def bullets(slide, items, x=MRG, y=C_Y, w=L_W, h=C_H, size=19):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame; tf.word_wrap = True
    first = True
    for item in items:
        p = tf.paragraphs[0] if first else tf.add_paragraph()
        first = False
        p.level = item.get('level', 0)
        r = p.add_run(); r.text = item['text']
        r.font.size   = Pt(item.get('size', size))
        r.font.bold   = item.get('bold', False)
        r.font.color.rgb = item.get('color', DARK)


def placeholder(slide, label="INSERT FIGURE HERE",
                x=R_X, y=C_Y, w=R_W, h=C_H):
    box = slide.shapes.add_shape(1, x, y, w, h)
    box.fill.solid(); box.fill.fore_color.rgb = PGRAY
    box.line.color.rgb = LGRAY; box.line.width = Pt(1)
    tb = slide.shapes.add_textbox(x + Inches(0.1), y + h/2 - Inches(0.3),
                                  w - Inches(0.2), Inches(0.6))
    tf = tb.text_frame; p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    r = p.add_run(); r.text = label
    r.font.size = Pt(16); r.font.color.rgb = GRAY; r.font.italic = True


def divider(prs, text):
    sl = prs.slides.add_slide(BLANK)
    sl.background.fill.solid(); sl.background.fill.fore_color.rgb = NAVY
    tb = sl.shapes.add_textbox(Inches(1), Inches(2.2), W - Inches(2), Inches(3))
    tf = tb.text_frame; tf.word_wrap = True
    p  = tf.paragraphs[0]; p.alignment = PP_ALIGN.CENTER
    r  = p.add_run(); r.text = text
    r.font.bold = True; r.font.size = Pt(38); r.font.color.rgb = WHITE
    return sl


# ------------------------------------------------------------------
TOTAL = 14
sn = 0

# ---- SLIDE 1: Title ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = NAVY
tb = sl.shapes.add_textbox(Inches(1), Inches(1.4), W - Inches(2), Inches(2.0))
tf = tb.text_frame; tf.word_wrap = True
p  = tf.paragraphs[0]; p.alignment = PP_ALIGN.CENTER
r  = p.add_run()
r.text = "Active Vibration Control of an ASML Measurement Plate"
r.font.bold = True; r.font.size = Pt(34); r.font.color.rgb = WHITE

tb2 = sl.shapes.add_textbox(Inches(1.5), Inches(3.6), W - Inches(3), Inches(1.4))
tf2 = tb2.text_frame; tf2.word_wrap = True
p2  = tf2.paragraphs[0]; p2.alignment = PP_ALIGN.CENTER
r2  = p2.add_run()
r2.text = ("Phase I: Positive Position Feedback with Dual Piezo Patches\n"
           "Phase II: Direct Velocity Feedback with MEMS Accelerometer")
r2.font.size = Pt(22); r2.font.color.rgb = RGBColor(0xBF, 0xD4, 0xED)

tb3 = sl.shapes.add_textbox(Inches(1.5), Inches(5.4), W - Inches(3), Inches(0.5))
tf3 = tb3.text_frame
p3  = tf3.paragraphs[0]; p3.alignment = PP_ALIGN.CENTER
r3  = p3.add_run(); r3.text = "Isaak Bouwmeester  |  ASML Internship  |  June 2026"
r3.font.size = Pt(18); r3.font.color.rgb = RGBColor(0x9D, 0xC3, 0xE6)

# ---- SLIDE 2: Problem ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "Floor vibrations at the plate bending mode degrade wafer positioning accuracy")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'ASML measurement plate: ~1000 x 1000 mm aluminium, ~100 mm thick'},
    {'text': 'First bending mode near 160 Hz amplifies floor vibrations from stage motion'},
    {'text': 'Positioning errors at wafer degrade lithography resolution'},
    {'text': ''},
    {'text': 'Goal: suppress the dominant bending mode with active vibration control'},
    {'text': 'Actuator: PI Ceramic P-876.A12 DuraAct piezo patch (d31 bending mode)'},
    {'text': ''},
    {'text': 'Phase I:  PPF with Patch 2 (actuator) + Patch 3 (piezo voltage sensor)'},
    {'text': 'Phase II: DVF with Patch 2 (actuator) + MEMS accelerometer (IMU)'},
])
placeholder(sl, "INSERT: ASML plate photo or schematic")

# ---- SLIDE 3: Eigenfrequencies ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "The plate has four flexible bending modes between 87 and 226 Hz")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'COMSOL eigenfrequency study (Domain Spring Foundation, kz = 2.7e6 N/m3):'},
    {'text': ''},
    {'text': 'Spring rigid-body modes (x6):  1.66 - 1.68 Hz', 'level': 1},
    {'text': 'Flexible mode 1:  86.51 Hz   (actuator placed at strain antinode)', 'level': 1},
    {'text': 'Flexible mode 2:  127.78 Hz', 'level': 1},
    {'text': 'Flexible mode 3:  160.90 Hz  (DVF target, clean -90 deg phase)', 'level': 1,
     'bold': True},
    {'text': 'Flexible mode 4:  225.56 Hz', 'level': 1},
    {'text': ''},
    {'text': 'Mode 1 (87 Hz) has feedthrough-distorted phase (+50 to +140 deg)'},
    {'text': 'Simple DVF cannot reliably suppress mode 1 from this patch/IMU placement'},
])
placeholder(sl, "INSERT: COMSOL strain heatmap\nshowing patch placement")

# ---- SLIDE 4: Actuator ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "The DuraAct P-876.A12 uses d31 bending; three COMSOL overrides are required")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Three-layer sandwich:'},
    {'text': 'Bottom polymer:  61 x 35 mm, 0.15 mm  (E = 5 GPa)', 'level': 1},
    {'text': 'PIC255 ceramic:  50 x 30 mm, 0.20 mm  (active layer)', 'level': 1},
    {'text': 'Top polymer:     61 x 35 mm, 0.15 mm', 'level': 1},
    {'text': ''},
    {'text': 'Electric field through ceramic thickness (z = poling direction)'},
    {'text': 'No coordinate rotation needed for d31 mode'},
    {'text': ''},
    {'text': 'COMSOL PIC255 defaults are wrong - always override:'},
    {'text': 'd31 = d32 = -260 pm/V  (default: -185 pm/V)', 'level': 1, 'bold': True},
    {'text': 'epsR_T33 = 1355  (default: 1832)', 'level': 1, 'bold': True},
    {'text': 'Ceramic thickness = 0.20 mm', 'level': 1, 'bold': True},
])
placeholder(sl, "INSERT: DuraAct patch photo\nor layer cross-section")

# ---- DIVIDER: Part I ----
divider(prs, "Part I\nPPF with Dual Piezo Patches")
sn += 1

# ---- SLIDE 5: PPF theory ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "PPF is unconditionally stable because the collocated piezo phase is bounded within (-90, +90) deg")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Patch 3 (sensor): open-circuit voltage Vs, Floating Potential BC on both ceramic faces'},
    {'text': ''},
    {'text': 'H22 = Vs/Va:  phase starts at 0 deg, crosses -90 deg at resonance, ends at -180 deg'},
    {'text': 'This phase bound makes PPF unconditionally stable for collocated pairs'},
    {'text': ''},
    {'text': 'PPF controller (Baken 2025 Eq. 9):'},
    {'text': 'K_PPF(s) = (1/H0) * g * wf^2 / (s^2 + 2*zf*wf*s + wf^2)', 'level': 1, 'bold': True},
    {'text': 'wf = wn,  g = 0.3,  zeta_f = 0.3', 'level': 1},
    {'text': ''},
    {'text': 'Phase accumulation at resonance: H22 adds -90 deg, K_PPF adds -90 deg'},
    {'text': 'Total: -180 deg from displacement = force opposing velocity = damping', 'bold': True},
    {'text': ''},
    {'text': 'Closed-loop tip:  T11 = H11 - H12 * [K/(1 - H22*K)] * H21'},
    {'text': 'MATLAB:  T = feedback(HOLc, K_ppf, 2, 2, +1)  (positive feedback)', 'level': 1},
])
placeholder(sl, "INSERT: PPF block diagram\n(see report Fig. 1)")

# ---- SLIDE 6: PPF results ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "PPF predicts 22.6 dB suppression at f1 = 214 Hz, matching Baken 2025")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Parameters:  g = 0.3,  zeta_f = 0.3,  f1 = 214 Hz  (density-tuned plate)'},
    {'text': ''},
    {'text': 'Predicted suppression at f1:'},
    {'text': 'Delta_H22 = -22.6 dB', 'level': 1, 'bold': True},
    {'text': 'Baken 2025 result: -22.8 dB  (sandwich beam, same g and zeta_f)', 'level': 1},
    {'text': ''},
    {'text': 'Luleci 2013 (Al plate 700x400 mm, DuraAct patches): 24, 23, 18 dB for modes 1-3'},
    {'text': ''},
    {'text': 'Discretisation: Tustin, fs = 10 kHz'},
    {'text': 'Kd = c2d(K_ppf, 1e-4, "tustin")', 'level': 1},
    {'text': ''},
    {'text': '[TODO] Replace with closed-loop Bode plot from MATLAB once'},
    {'text': 'H11, H12, H21 are re-exported from COMSOL at the correct point', 'level': 1},
])
placeholder(sl, "INSERT: Bode plot\nH22 open-loop vs closed-loop\n(compare Aphale 2007 Fig. 3-4)")

# ---- DIVIDER: Part II ----
divider(prs, "Part II\nDVF with MEMS Accelerometer")
sn += 1

# ---- SLIDE 7: Phase convention ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "COMSOL solid.accZ uses +w^2 (not -w^2), shifting the phase 180 deg vs a real accelerometer")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Physical acceleration:  a = -w^2 * x   (phase = +180 deg vs displacement)'},
    {'text': 'COMSOL solid.accZ:      a = +w^2 * w   (phase = 0 deg below resonance)'},
    {'text': ''},
    {'text': 'Phase comparison:'},
    {'text': 'Below resonance:  solid.accZ = 0 deg,   physical = +180 deg', 'level': 1},
    {'text': 'At resonance:     solid.accZ = -90 deg, physical = -270 deg (+90 deg)', 'level': 1},
    {'text': 'Above resonance:  solid.accZ = -180 deg, physical = -360 deg (0 deg)', 'level': 1},
    {'text': ''},
    {'text': 'Confirmed from H22_accel.txt: at 1 Hz, H22 is positive real (0 deg)'},
    {'text': 'Main resonance at ~157 Hz, phase crosses -90 deg there'},
    {'text': ''},
    {'text': 'This 180 deg offset affects the DVF controller sign (see next slide)'},
])
placeholder(sl, "INSERT: H22_accel.txt Bode plot\n(compare Gatti 2007 Fig. 8a)")

# ---- SLIDE 8: Controller selection ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "PPF and IRC both fail with an acceleration sensor; DVF is conditionally stable")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'PPF:  requires phase of H22 in (-90, +90) deg'},
    {'text': 'With acceleration sensor, phase at resonance = -90 deg (on boundary)', 'level': 1},
    {'text': 'Not safe - REJECTED', 'level': 1, 'bold': True},
    {'text': ''},
    {'text': 'IRC:  requires Negative Imaginary property: Im[H22] <= 0 for all w'},
    {'text': 'NI property holds only for displacement or charge/voltage sensors', 'level': 1},
    {'text': 'Acceleration output destroys the NI property - REJECTED', 'level': 1, 'bold': True},
    {'text': ''},
    {'text': 'DVF:  Nyquist of g * H22_vel must not encircle -1'},
    {'text': 'H22_vel = solid.accZ / (j*w) is real and positive at resonance', 'level': 1},
    {'text': 'SELECTED - conditionally stable (Nyquist check required)', 'level': 1, 'bold': True},
    {'text': ''},
    {'text': 'Conditional (not unconditional) because patch applies distributed moment,'},
    {'text': 'not a point force - Balas 1979 unconditional proof does not apply', 'level': 1},
])

# ---- SLIDE 9: DVF design ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "DVF uses +g (not -g) because solid.accZ has the opposite sign from the literature convention")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'DVF controller:  K_DVF(s) = +g * S / (s + S)  with S = 5 rad/s', 'bold': True},
    {'text': 'Negative feedback loop (summing junction carries minus sign)'},
    {'text': ''},
    {'text': 'Why +g (Falangas 1994 writes -g):'},
    {'text': 'Falangas: K = -g*S/(s+S) for physical acceleration (a = -w^2*x)', 'level': 1},
    {'text': 'solid.accZ: a = +w^2*x (opposite convention)', 'level': 1},
    {'text': 'Using -g with solid.accZ data flips damping into anti-damping', 'level': 1},
    {'text': ''},
    {'text': 'Symptom of wrong sign: suppression dB is POSITIVE and grows with gain'},
    {'text': ''},
    {'text': 'g_max from Nyquist:  g_max = 1 / max(-Re[H22 * S/(j*w+S)])'},
    {'text': 'Operating gain: g = 0.30 * g_max  (10 dB stability margin)'},
    {'text': ''},
    {'text': 'Closed-loop:  T21 = H21 / (1 + H22 * K_DVF)'},
    {'text': 'Denominator at resonance = 1 + MgL > 1 -> genuine suppression', 'level': 1},
])
placeholder(sl, "INSERT: DVF block diagram\n(see report Fig. 2)")

# ---- SLIDE 10: DVF results ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "DVF predicts 10-15 dB suppression at 161 Hz, consistent with Falangas 1994 benchmark")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Target mode: 160.90 Hz (mode 3, clean -90 deg phase crossing)'},
    {'text': 'g = 30% of g_max,  S = 5 rad/s  (Falangas 1994 lag pole)'},
    {'text': ''},
    {'text': 'Predicted suppression:'},
    {'text': 'Delta_T21 ~ -10 to -15 dB at f1 = 161 Hz', 'level': 1, 'bold': True},
    {'text': 'Falangas 1994 benchmark: -10.5 dB  (flat Al plate + PZT + accelerometers)',
     'level': 1},
    {'text': ''},
    {'text': 'Actuator voltage check: Va_peak = g * K_norm * H21(f1) * a_rms'},
    {'text': 'Both stability limit and 400 V hardware limit checked in dvf_main.m', 'level': 1},
    {'text': ''},
    {'text': '[TODO] Exact suppression value pending correct H11/H12 re-export from COMSOL'},
    {'text': '[TODO] Compare T21 Bode with Falangas 1994 Figure 7', 'level': 1},
])
placeholder(sl, "INSERT: T21 open-loop vs closed-loop\n(compare Falangas 1994 Fig. 7)")

# ---- SLIDE 11: BC decision ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "Domain Spring Foundation is the only BC consistent between Study 1 and Study 2")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Study 1 (H22, H12):  Va = 1 V excitation, no base motion'},
    {'text': 'Study 2 (H11, H21):  base acceleration = 1 m/s2, Va = 0'},
    {'text': ''},
    {'text': 'Fixed Constraint on bottom edges: correct for PPF model (Phase I)'},
    {'text': 'Over-constrains foam mounting; f1 jumps to ~6500 Hz', 'level': 1},
    {'text': 'Cannot be used for Study 2 in the IMU model', 'level': 1},
    {'text': ''},
    {'text': 'Boundary Spring Foundation: REJECTED'},
    {'text': 'Contradicts Base Excitation node, produces flat non-physical H11', 'level': 1},
    {'text': ''},
    {'text': 'Rigid Motion Suppression: REJECTED'},
    {'text': 'Different eigenmodes from spring foundation -> inconsistent MIMO matrix', 'level': 1},
    {'text': ''},
    {'text': 'Domain Spring Foundation: SELECTED'},
    {'text': 'Consistent between Study 1 and 2, driveable by Base Excitation node',
     'level': 1, 'bold': True},
])

# ---- SLIDE 12: Gridplate ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "The ASML gridplate has similar vibration frequencies but open questions remain on patch authority")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Gridplate: large flat reference plate with encoder grating for wafer position'},
    {'text': 'Position stability requirement: ~0.15 nm over 24 hours'},
    {'text': 'Stage motion excites gridplate modes at 100-300 Hz (ASML patent literature)'},
    {'text': ''},
    {'text': 'This model modes (87, 128, 161, 226 Hz) overlap with the gridplate range'},
    {'text': ''},
    {'text': 'Open questions before DVF/PPF can be recommended for the gridplate:'},
    {'text': '[TODO] Gridplate size, thickness, material (Zerodur vs aluminium)', 'level': 1},
    {'text': '[TODO] H22 peak magnitude - does patch authority hold on a stiffer plate?',
     'level': 1},
    {'text': '[TODO] Multiple modes in band - Nyquist margin across all modes', 'level': 1},
    {'text': '[TODO] Spatial coverage - single patch or distributed array?', 'level': 1},
    {'text': '[TODO] Vacuum, outgassing, EMI compatibility with ASML environment',
     'level': 1},
    {'text': ''},
    {'text': 'Preliminary: single patch can suppress first bending mode by 10-22 dB'},
    {'text': 'Feasibility depends on actuator authority and number of patches needed',
     'bold': True},
])
placeholder(sl, "INSERT: ASML gridplate schematic\nor patent figure")

# ---- SLIDE 13: Conclusions ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "Conclusions: DVF with correct sign and Domain Spring Foundation achieves target suppression")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': 'Phase I: PPF with dual DuraAct patches'},
    {'text': 'Unconditionally stable for collocated piezo pair', 'level': 1},
    {'text': '-22.6 dB predicted at 214 Hz (g = 0.3, zf = 0.3)', 'level': 1, 'bold': True},
    {'text': ''},
    {'text': 'Phase II: DVF with MEMS accelerometer'},
    {'text': 'PPF and IRC both inapplicable with acceleration sensor', 'level': 1},
    {'text': 'Use K(s) = +g*S/(s+S), NOT -g: solid.accZ has opposite sign from Falangas',
     'level': 1, 'bold': True},
    {'text': '-10 to -15 dB suppression predicted at 161 Hz (mode 3)', 'level': 1, 'bold': True},
    {'text': ''},
    {'text': 'Critical model choices:'},
    {'text': 'Domain Spring Foundation: only BC valid for both Study 1 and Study 2',
     'level': 1},
    {'text': '161 Hz is the reliable DVF target; 87 Hz has distorted phase', 'level': 1},
    {'text': 'PIC255 d31 and epsR must be overridden from COMSOL defaults', 'level': 1},
    {'text': ''},
    {'text': 'Next step: re-export H11, H12 at IMU corner to complete T11 calculation'},
], size=18)

# ---- SLIDE 14: References ----
sn += 1
sl = prs.slides.add_slide(BLANK)
sl.background.fill.solid(); sl.background.fill.fore_color.rgb = WHITE
title_bar(sl, "References")
footer(sl, sn, TOTAL)
bullets(sl, [
    {'text': '[1] Falangas, Dworak, Koshigoe (1994). Controlling plate vibrations using PZT actuators.'},
    {'text': '     IEEE Control Systems Magazine, 14(4):34-41.', 'level': 1},
    {'text': '[2] Gatti, Brennan, Gardonio (2007). Active damping of a beam with collocated accelerometer.'},
    {'text': '     J. Sound Vib., 303:798-813.', 'level': 1},
    {'text': '[3] Aphale, Fleming, Moheimani (2007). Integral resonant control of smart structures.'},
    {'text': '     Smart Mater. Struct., 16:439-446.', 'level': 1},
    {'text': '[4] Balas (1979). Direct velocity feedback control of large space structures.'},
    {'text': '     J. Guidance Control, 2:252-253.', 'level': 1},
    {'text': '[5] Baken, Gupta, Jansen, HosseinNia (2025). PZT shear actuators for sandwich beams.'},
    {'text': '     arXiv:2506.21713v1.', 'level': 1},
    {'text': '[6] Luleci (2013). AVC of beams and plates using PZT patches. MSc thesis, METU.', },
], size=17, h=Inches(5.5))

# ------------------------------------------------------------------
out = r"C:\Users\isaak\Desktop\Comsol\Internship\LatestFiles\ImuActuator\presentation.pptx"
prs.save(out)
print(f"Saved: {out}  ({len(prs.slides)} slides)")

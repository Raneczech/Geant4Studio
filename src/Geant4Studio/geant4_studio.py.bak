#!/usr/bin/env python3
"""Geant4 Studio with a graphical PYTHIA 8 configuration editor."""

import copy
import json
import math
import os
import re
import shutil
import subprocess
import threading
import tkinter as tk
import xml.etree.ElementTree as ET
from tkinter import ttk, filedialog, messagebox
from pathlib import Path


PROCESS_OPTIONS = [
    ("SoftQCD:all", "Soft QCD — inclusive soft processes",
     "Minimum-bias, elastic and diffractive/soft-QCD processes."),
    ("HardQCD:all", "Hard QCD — 2→2 parton scattering",
     "Hard quark/gluon scattering processes."),
    ("WeakBosonExchange:ff2ff(t:gmZ)", "DIS — virtual photon/Z exchange (γ*/Z)",
     "Neutral-current lepton–hadron deep-inelastic scattering via t-channel γ*/Z exchange."),
    ("WeakSingleBoson:ffbar2gmZ", "γ*/Z production",
     "Fermion-antifermion production of a virtual photon or Z boson."),
    ("WeakSingleBoson:ffbar2W", "W production",
     "Fermion-antifermion production of a W boson."),
]

SHOWER_OPTIONS = [
    ("PartonLevel:ISR", "Initial-state radiation (ISR)",
     "Radiation from incoming partons before the hard interaction."),
    ("PartonLevel:FSR", "Final-state radiation (FSR)",
     "Radiation from outgoing partons and in supported resonance decays."),
    ("PartonLevel:MPI", "Multiple parton interactions (MPI)",
     "Additional parton-parton interactions in the same collision."),
    ("HadronLevel:Hadronize", "Hadronization",
     "Convert coloured partons into colour-neutral hadrons."),
    ("HadronLevel:Decay", "Particle decays",
     "Allow unstable particles to decay according to PYTHIA's decay data."),
]


def default_pythia_config():
    return {
        "config_version": 2,
        "beam_id_a": "2212",
        "beam_id_b": "2212",
        "beam_b_enabled": True,
        # Geant4 Studio modes: 1 = CM energy, 2 = momentum vectors,
        # 3 = separate gun positions aimed at the interaction point.
        "frame_type": "1",
        "e_cm": "14000",
        # Frame 2 uses all vector components. Frame 3 reuses only |p| from
        # each vector; its direction is calculated from the gun position.
        "beam_momentum_a": {"px": "0", "py": "0", "pz": "7000"},
        "beam_momentum_b": {"px": "0", "py": "0", "pz": "-7000"},
        # Source positions (mm). In Frame 3 each nominal beam direction
        # is calculated from its own source toward the common interaction point.
        "beam_gun_position_a": {"x": "0", "y": "0", "z": "-1000"},
        "beam_gun_position_b": {"x": "0", "y": "0", "z": "1000"},
        # PYTHIA interaction point / beam spot. Coordinates and widths are in mm.
        "vertex_enabled": False,
        "vertex_offset": {"x": "0", "y": "0", "z": "0"},
        "vertex_sigma": {"x": "0", "y": "0", "z": "0", "time": "0"},
        "vertex_max_dev": "5",
        "trajectory_colors": {
            "gamma": "yellow",
            "neutron": "green",
            "pi0": "violet",
            "e-": "blue",
            "e+": "red",
            "proton": "cyan",
            "pi+": "magenta",
            "pi-": "magenta",
            "kaon+": "orange",
            "kaon-": "orange",
            "kaon0": "violet",
            "anti_kaon0": "violet",
            "kaon0S": "violet",
            "kaon0L": "violet",
            "mu-": "cyan",
            "mu+": "cyan",
        },
        "processes": {
            "SoftQCD:all": True,
            "HardQCD:all": False,
            "WeakBosonExchange:ff2ff(t:gmZ)": False,
            "WeakSingleBoson:ffbar2gmZ": False,
            "WeakSingleBoson:ffbar2W": False,
        },
        "showers": {
            "PartonLevel:ISR": True,
            "PartonLevel:FSR": True,
            "PartonLevel:MPI": True,
            "HadronLevel:Hadronize": True,
            "HadronLevel:Decay": True,
        },
        "use_seed": False,
        "seed": "12345",
        "show_changed_settings": False,
        "show_changed_particle_data": False,
        "show_event_info": 0,
        "show_process_info": 0,
        "show_event_record": 0,
        "custom_settings": "",
    }




# Curated particle families shown first in the searchable Beam selectors.
# PDG IDs follow the standard PDG numbering convention.
PARTICLE_FAMILY_PRESETS = [
    # Ground-state baryon flavour octet: qqq composition is shown explicitly.
    ("[Baryon octet] Proton p — uud (PDG 2212)", 2212),
    ("[Baryon octet] Neutron n — udd (PDG 2112)", 2112),
    ("[Baryon octet] Lambda Λ⁰ — uds (PDG 3122)", 3122),
    ("[Baryon octet] Sigma Σ⁺ — uus (PDG 3222)", 3222),
    ("[Baryon octet] Sigma Σ⁰ — uds (PDG 3212)", 3212),
    ("[Baryon octet] Sigma Σ⁻ — dds (PDG 3112)", 3112),
    ("[Baryon octet] Xi Ξ⁰ — uss (PDG 3322)", 3322),
    ("[Baryon octet] Xi Ξ⁻ — dss (PDG 3312)", 3312),

    # Corresponding antibaryons, with antiquark content.
    ("[Antibaryon octet] Antiproton p̄ — ūūd̄ (PDG -2212)", -2212),
    ("[Antibaryon octet] Antineutron n̄ — ūd̄d̄ (PDG -2112)", -2112),
    ("[Antibaryon octet] Anti-Lambda Λ̄⁰ — ūd̄s̄ (PDG -3122)", -3122),
    ("[Antibaryon octet] Anti-Sigma Σ̄⁻ — ūūs̄ (PDG -3222)", -3222),
    ("[Antibaryon octet] Anti-Sigma Σ̄⁰ — ūd̄s̄ (PDG -3212)", -3212),
    ("[Antibaryon octet] Anti-Sigma Σ̄⁺ — d̄d̄s̄ (PDG -3112)", -3112),
    ("[Antibaryon octet] Anti-Xi Ξ̄⁰ — ūs̄s̄ (PDG -3322)", -3322),
    ("[Antibaryon octet] Anti-Xi Ξ̄⁺ — d̄s̄s̄ (PDG -3312)", -3312),

    # Three generations of leptons and their antiparticles.
    ("[Lepton I] Electron e⁻ (PDG 11)", 11),
    ("[Lepton I] Electron neutrino νₑ (PDG 12)", 12),
    ("[Antilepton I] Positron e⁺ (PDG -11)", -11),
    ("[Antilepton I] Electron antineutrino ν̄ₑ (PDG -12)", -12),
    ("[Lepton II] Muon μ⁻ (PDG 13)", 13),
    ("[Lepton II] Muon neutrino νμ (PDG 14)", 14),
    ("[Antilepton II] Antimuon μ⁺ (PDG -13)", -13),
    ("[Antilepton II] Muon antineutrino ν̄μ (PDG -14)", -14),
    ("[Lepton III] Tau τ⁻ (PDG 15)", 15),
    ("[Lepton III] Tau neutrino ντ (PDG 16)", 16),
    ("[Antilepton III] Antitau τ⁺ (PDG -15)", -15),
    ("[Antilepton III] Tau antineutrino ν̄τ (PDG -16)", -16),
]


def load_pythia_particle_presets():
    """Return curated family presets plus the searchable PYTHIA XML catalogue."""
    presets = {}

    # Curated entries come first so the octet composition and lepton family
    # labels are visible in the dropdown even when PYTHIA uses short names.
    for label, particle_id in PARTICLE_FAMILY_PRESETS:
        presets[label] = str(particle_id)

    # Familiar particles remain easy to find even if ParticleData.xml is absent.
    presets.update({
        "[Common] Photon gamma (PDG 22)": "22",
        "[Common] Pion pi+ (PDG 211)": "211",
        "[Common] Pion pi- (PDG -211)": "-211",
        "[Common] Pion pi0 (PDG 111)": "111",
    })

    candidates = []
    configured_data = os.environ.get("PYTHIA8DATA")
    if configured_data:
        candidates.append(Path(configured_data).expanduser() / "ParticleData.xml")

    home = Path.home()
    candidates.extend([
        home / "geant4" / "pythia8318" / "share" / "Pythia8" / "xmldoc" / "ParticleData.xml",
        home / "geant4" / "pythia8" / "share" / "Pythia8" / "xmldoc" / "ParticleData.xml",
        home / ".local" / "share" / "Pythia8" / "xmldoc" / "ParticleData.xml",
        Path("/usr/share/Pythia8/xmldoc/ParticleData.xml"),
        Path("/usr/share/pythia8/xmldoc/ParticleData.xml"),
        Path("/usr/local/share/Pythia8/xmldoc/ParticleData.xml"),
    ])

    xml_path = next((path for path in candidates if path.is_file()), None)
    if xml_path is not None:
        try:
            import xml.etree.ElementTree as ET
            root = ET.parse(xml_path).getroot()
            for particle in root.iter("particle"):
                attrs = particle.attrib
                try:
                    particle_id = int(attrs["id"])
                except (KeyError, TypeError, ValueError):
                    continue
                name = attrs.get("name", "").strip()
                if particle_id == 0 or not name:
                    continue

                # Keep XML entries separate from curated aliases. Prefixing
                # avoids replacing the human-friendly family descriptions.
                xml_label = f"[PYTHIA] {name} (PDG {particle_id})"
                presets.setdefault(xml_label, str(particle_id))

                anti_name = attrs.get("antiName", "").strip()
                if particle_id > 0 and anti_name and anti_name.casefold() != "void":
                    anti_label = f"[PYTHIA] {anti_name} (PDG {-particle_id})"
                    presets.setdefault(anti_label, str(-particle_id))
        except Exception:
            # Curated entries are still available if the XML file is missing
            # or malformed. Do not prevent the whole editor from opening.
            pass

    # Explicit aliases for the six commonly used kaon states.
    presets.update({
        'Kaon+ / K+ (321)': '321',
        'Kaon- / K- (-321)': '-321',
        'Kaon0 / K0 (311)': '311',
        'Antikaon0 / K\u03050u0305 (-311)': '-311',
        'Kaon K-short / K_S0 (310)': '310',
        'Kaon K-long / K_L0 (130)': '130',
    })
    return presets


# Geant4 Studio: add valence-quark composition to meson search labels.
# PDG Monte Carlo numbering encodes the two meson flavours in its last digits.
def _gs_meson_quark_composition(particle_id):
    """Return valence-quark content for a meson, or None if not identified."""
    try:
        pid = int(particle_id)
    except (TypeError, ValueError):
        return None

    if pid == 0:
        return None

    # Use COMBINING OVERLINE (U+0305) consistently for antiquarks.
    # Meson valence pairs are written by juxtaposition: s d̅, not s + d̅.
    def anti(quark):
        return quark + "\u0305"

    absolute_id = abs(pid)

    # K-short and K-long are mixtures of K0 and anti-K0.
    if absolute_id in (130, 310):
        return f"(d{anti('s')} ± s{anti('d')})/√2 — směs K⁰ a K̄⁰"

    # Standard PDG meson code: n nr nL nq1 nq2 nq3 nJ.
    digits = f"{absolute_id:07d}"
    if len(digits) != 7:
        return None

    leading = int(digits[0])
    nq1, nq2, nq3 = (int(digits[3]), int(digits[4]), int(digits[5]))

    # Ordinary mesons have nq1=0. n=9 denotes states whose q-qbar
    # assignment is uncertain; don't guess their valence content.
    if nq1 != 0 or nq2 not in range(1, 7) or nq3 not in range(1, 7):
        return None
    if leading == 9:
        return "valenční složení nejisté"
    if leading != 0:
        return None

    quarks = {1: "d", 2: "u", 3: "s", 4: "c", 5: "b", 6: "t"}
    charge3 = {1: -1, 2: 2, 3: -1, 4: 2, 5: -1, 6: 2}
    q2, q3 = quarks[nq2], quarks[nq3]

    # Neutral flavour-diagonal states can be physical mixtures.
    if nq2 == nq3:
        if nq2 == 1:
            return f"(u{anti('u')} − d{anti('d')})/√2 — izospinová směs"
        if nq2 == 2:
            return f"u{anti('u')} / d{anti('d')} / s{anti('s')} — směs lehkých kvarků"
        if nq2 == 3:
            return f"s{anti('s')} (převážně; možné míchání)"
        return f"{q2}{anti(q2)}"

    # The sign of the PDG code distinguishes a meson from its antiparticle.
    charge_q2_q3bar = charge3[nq2] - charge3[nq3]
    charge_q3_q2bar = charge3[nq3] - charge3[nq2]
    wanted_sign = 1 if pid > 0 else -1

    if charge_q2_q3bar * wanted_sign > 0:
        quark, antiquark = q2, q3
    elif charge_q3_q2bar * wanted_sign > 0:
        quark, antiquark = q3, q2
    else:
        # Neutral open-flavour mesons: apply the PDG flavour convention.
        if nq2 == 3 and nq3 in (1, 2):       # K0 / K*0 / excited kaons
            quark, antiquark = (q3, q2) if pid > 0 else (q2, q3)
        elif nq2 == 4 and nq3 in (1, 2, 3):  # D0 / D*0 families
            quark, antiquark = (q2, q3) if pid > 0 else (q3, q2)
        elif nq2 == 5 and nq3 in (1, 2, 3):  # B0 / Bs0 families
            quark, antiquark = (q3, q2) if pid > 0 else (q2, q3)
        else:
            return f"{q2}{anti(q3)} / {q3}{anti(q2)} — orientace neurčena"

    return f"{quark}{anti(antiquark)}"


_gs_load_pythia_particle_presets_raw = load_pythia_particle_presets

def load_pythia_particle_presets():
    """Return the original catalogue with meson compositions in its labels."""
    presets = _gs_load_pythia_particle_presets_raw()
    annotated = {}
    for label, pdg_id in presets.items():
        composition = _gs_meson_quark_composition(pdg_id)
        # Strip an old composition suffix if the patch is being re-applied to
        # a partially updated source. This also keeps the operation idempotent.
        base_label = label.split(" — ", 1)[0]
        if composition:
            shown_label = f"{base_label} — {composition}"
        else:
            shown_label = base_label
        annotated[shown_label] = str(pdg_id)
    return dict(sorted(annotated.items(), key=lambda item: item[0].casefold()))


def cpp_string(value):
    """Return a safely escaped C++ string literal."""
    escaped = (str(value).replace("\\", "\\\\")
                         .replace('"', '\\"')
                         .replace("\n", "\\n")
                         .replace("\r", "\\r"))
    return f'"{escaped}"'


def make_pythia_settings(config):
    """Build PYTHIA command strings from the visual configuration."""
    frame_type = int(config.get("frame_type", "1"))
    # Geant4 Studio Frame 2 and Frame 3 are both implemented using
    # PYTHIA's native frameType=3 (custom beam momentum vectors).
    pythia_frame_type = 1 if frame_type == 1 else 3
    settings = [
        f"Beams:idA = {int(config['beam_id_a'])}",
        f"Beams:idB = {int(config['beam_id_b'])}",
        f"Beams:frameType = {pythia_frame_type}",
    ]

    if frame_type == 1:
        settings.append(f"Beams:eCM = {float(config['e_cm']):.12g}")
    elif frame_type == 2:
        for beam_name, pythia_suffix in (("a", "A"), ("b", "B")):
            vector = config[f"beam_momentum_{beam_name}"]
            for component in ("px", "py", "pz"):
                value = float(vector[component])
                settings.append(f"Beams:{component}{pythia_suffix} = {value:.12g}")
    elif frame_type == 3:
        # Aim each nominal incoming beam from its own source position
        # toward the mean interaction point. The default target is (0,0,0).
        # A configured mean vertex offset becomes the target when enabled.
        if config.get("vertex_enabled"):
            target = tuple(
                float(config["vertex_offset"][axis]) for axis in ("x", "y", "z")
            )
        else:
            target = (0.0, 0.0, 0.0)

        for beam_name, pythia_suffix in (("a", "A"), ("b", "B")):
            source = config[f"beam_gun_position_{beam_name}"]
            delta = tuple(
                target[i] - float(source[axis])
                for i, axis in enumerate(("x", "y", "z"))
            )
            distance = math.sqrt(sum(component * component for component in delta))
            if distance <= 0.0:
                raise ValueError(
                    f"Gun position {beam_name.upper()} must not coincide with the interaction point."
                )
            # Reuse the magnitude of the corresponding Frame 2 vector.
            # Frame 3 replaces only its direction with source -> interaction point.
            momentum_vector = config[f"beam_momentum_{beam_name}"]
            components = tuple(float(momentum_vector[axis]) for axis in ("px", "py", "pz"))
            magnitude = math.sqrt(sum(value * value for value in components))
            if magnitude <= 0.0:
                raise ValueError(
                    f"Frame 3 needs a non-zero momentum vector for beam {beam_name.upper()} in the Frame 2 fields."
                )
            for component, value in zip(("px", "py", "pz"), delta):
                settings.append(
                    f"Beams:{component}{pythia_suffix} = {magnitude * value / distance:.12g}"
                )
    else:
        raise ValueError("Neznámý typ kinematiky svazků.")

    # PYTHIA models one common collision point. Its offset is the mean
    # position; sigmas describe the Gaussian beam-spot / vertex spread.
    settings.append(
        "Beams:allowVertexSpread = " + ("on" if config.get("vertex_enabled") else "off")
    )
    if config.get("vertex_enabled"):
        offset = config["vertex_offset"]
        sigma = config["vertex_sigma"]
        for axis in ("x", "y", "z"):
            settings.append(f"Beams:offsetVertex{axis.upper()} = {float(offset[axis]):.12g}")
            settings.append(f"Beams:sigmaVertex{axis.upper()} = {float(sigma[axis]):.12g}")
        settings.extend([
            f"Beams:sigmaTime = {float(sigma['time']):.12g}",
            f"Beams:maxDevVertex = {float(config['vertex_max_dev']):.12g}",
        ])

    for key, _label, _description in PROCESS_OPTIONS:
        settings.append(f"{key} = {'on' if config['processes'].get(key) else 'off'}")

    # PYTHIA's recommended neutral-current DIS setup (gamma*/Z exchange).
    # The scales are Q^2-based; dipole recoil and pTmax matching are needed
    # for the DIS initial-state shower setup.
    if config["processes"].get("WeakBosonExchange:ff2ff(t:gmZ)", False):
        settings.extend([
            "SigmaProcess:factorScale2 = 6",
            "SigmaProcess:renormScale2 = 6",
            "SpaceShower:dipoleRecoil = on",
            "SpaceShower:pTmaxMatch = 2",
        ])

    for key, _label, _description in SHOWER_OPTIONS:
        settings.append(f"{key} = {'on' if config['showers'].get(key) else 'off'}")

    if config["use_seed"]:
        settings.extend([
            "Random:setSeed = on",
            f"Random:seed = {int(config['seed'])}",
        ])
    else:
        settings.append("Random:setSeed = off")

    settings.extend([
        "Init:showChangedSettings = " + ("on" if config["show_changed_settings"] else "off"),
        "Init:showChangedParticleData = " + ("on" if config["show_changed_particle_data"] else "off"),
        f"Next:numberShowInfo = {int(config['show_event_info'])}",
        f"Next:numberShowProcess = {int(config['show_process_info'])}",
        f"Next:numberShowEvent = {int(config['show_event_record'])}",
    ])

    custom_lines = []
    for line_number, raw_line in enumerate(config.get("custom_settings", "").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("!"):
            continue
        if "=" not in line:
            raise ValueError(
                f"Vlastní nastavení na řádku {line_number} neobsahuje '=':\n{raw_line}"
            )
        custom_lines.append(line)

    # Custom settings are appended last, so they can intentionally override
    # a setting configured by one of the GUI controls.
    settings.extend(custom_lines)
    return settings


def generate_main_cc(config, user_code=""):
    beam_b_enabled = bool(config.get("beam_b_enabled", True))

    settings = make_pythia_settings(config) if beam_b_enabled else []
    settings_cpp = ("," + chr(10) + "            ").join(
        cpp_string(item) for item in settings
    )

    user_code = user_code.rstrip(chr(10))
    user_block = user_code + chr(10) if user_code else ""

    replacements = {
        "__PYTHIA_SETTINGS__": settings_cpp,
        "__USER_CODE__": user_block,
        "__BEAM_B_ENABLED__": "true" if beam_b_enabled else "false",
    }

    if not beam_b_enabled:
        frame_type = int(config.get("frame_type", "1"))

        momentum = config["beam_momentum_a"]
        px, py, pz = (
            float(momentum[axis]) for axis in ("px", "py", "pz")
        )

        position = config["beam_gun_position_a"]
        x, y, z = (
            float(position[axis]) for axis in ("x", "y", "z")
        )

        if frame_type == 3:
            if config.get("vertex_enabled"):
                target = tuple(
                    float(config["vertex_offset"][axis])
                    for axis in ("x", "y", "z")
                )
            else:
                target = (0.0, 0.0, 0.0)

            delta = tuple(
                target[i] - value
                for i, value in enumerate((x, y, z))
            )
            distance = math.sqrt(sum(value * value for value in delta))
            magnitude = math.sqrt(px * px + py * py + pz * pz)

            if distance <= 0 or magnitude <= 0:
                raise ValueError(
                    "Frame 3 vyžaduje nenulovou vzdálenost zdroje A "
                    "od interakčního bodu a nenulovou hybnost A."
                )

            px, py, pz = (
                magnitude * value / distance for value in delta
            )

        replacements.update({
            "__DECAY_PARTICLE_ID__": str(int(config["beam_id_a"])),
            "__DECAY_POSITION_X__": f"{x:.12g}",
            "__DECAY_POSITION_Y__": f"{y:.12g}",
            "__DECAY_POSITION_Z__": f"{z:.12g}",
            "__DECAY_MOMENTUM_X__": f"{px:.12g}",
            "__DECAY_MOMENTUM_Y__": f"{py:.12g}",
            "__DECAY_MOMENTUM_Z__": f"{pz:.12g}",
        })
    else:
        replacements.update({
            "__DECAY_PARTICLE_ID__": "0",
            "__DECAY_POSITION_X__": "0",
            "__DECAY_POSITION_Y__": "0",
            "__DECAY_POSITION_Z__": "0",
            "__DECAY_MOMENTUM_X__": "0",
            "__DECAY_MOMENTUM_Y__": "0",
            "__DECAY_MOMENTUM_Z__": "1",
        })

    template_path = Path(__file__).resolve().parent / "templates" / "main.cc"
    template = template_path.read_text(encoding="utf-8")

    for marker, value in replacements.items():
        if template.count(marker) != 1:
            raise ValueError(
                f"Šablona main.cc: očekáván právě jeden marker {marker}."
            )
        template = template.replace(marker, value)

    return template



class Geant4Studio(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("Geant4 Studio")
        self.geometry("1100x750")
        self.minsize(800, 550)

        # Default folder used by both the New Project and Open Project dialogs.
        self.default_project_dir = Path.home() / "fyzika"

        self.project_dir = None
        self.current_file = None
        self.process = None
        self.pythia_config = default_pythia_config()

        self.create_interface()

    def create_interface(self):
        # --------------------------------------------------------
        # HORNÍ TOOLBAR
        # --------------------------------------------------------
        toolbar = ttk.Frame(self, padding=8)
        toolbar.pack(fill="x")

        ttk.Button(
            toolbar, text="User Manual", command=self.show_manual
        ).pack(side="left", padx=3)

        ttk.Separator(toolbar, orient="vertical").pack(
            side="left", fill="y", padx=8
        )

        ttk.Button(
            toolbar, text="New Project", command=self.new_project
        ).pack(side="left", padx=3)

        ttk.Button(
            toolbar, text="Open Project", command=self.open_project
        ).pack(side="left", padx=3)

        ttk.Button(
            toolbar, text="Save", command=self.save_file
        ).pack(side="left", padx=3)

        ttk.Button(
            toolbar, text="Visual project config", command=self.open_pythia_config
        ).pack(side="left", padx=3)

        ttk.Separator(toolbar, orient="vertical").pack(
            side="left", fill="y", padx=8
        )

        ttk.Button(
            toolbar, text="Build", command=self.build_project
        ).pack(side="left", padx=3)

        ttk.Button(
            toolbar, text="Run", command=self.run_project
        ).pack(side="left", padx=3)

        ttk.Button(
            toolbar, text="Stop", command=self.stop_process
        ).pack(side="left", padx=3)

        # --------------------------------------------------------
        # HLAVNÍ ROZLOŽENÍ
        #
        # Vnější Panedwindow je svislý:
        #   - nahoře: sidebar + editor kódu vedle sebe
        #   - dole:   konzole přes CELÉ okno
        #
        # Táhlo mezi těmito dvěma oblastmi mění výšku konzole.
        # Vnitřní Panedwindow ponechává samostatně měnitelnou
        # šířku sidebaru vůči editoru.
        # --------------------------------------------------------
        self.workspace_panes = ttk.Panedwindow(
            self, orient="vertical"
        )
        self.workspace_panes.pack(
            fill="both", expand=True, padx=8, pady=4
        )

        # Horní oblast: pouze strom projektu a editor.
        top_panes = ttk.Panedwindow(
            self.workspace_panes, orient="horizontal"
        )
        self.workspace_panes.add(top_panes, weight=4)

        # Levý sidebar se seznamem souborů.
        left = ttk.Frame(top_panes, padding=5)
        top_panes.add(left, weight=1)

        ttk.Label(left, text="Project files").pack(anchor="w")

        self.file_tree = ttk.Treeview(left, show="tree")
        self.file_tree.pack(fill="both", expand=True, pady=5)
        self.file_tree.bind("<<TreeviewSelect>>", self.select_file)

        # Pravá horní oblast: editor zdrojového kódu.
        right = ttk.Frame(top_panes, padding=5)
        top_panes.add(right, weight=4)

        self.editor_label = ttk.Label(
            right, text="Editor — no file selected"
        )
        self.editor_label.pack(anchor="w")

        editor_frame = ttk.Frame(right)
        editor_frame.pack(fill="both", expand=True, pady=5)

        self.editor = tk.Text(
            editor_frame,
            wrap="none",
            undo=True,
            font=("Monospace", 10)
        )

        yscroll = ttk.Scrollbar(
            editor_frame, orient="vertical", command=self.editor.yview
        )
        xscroll = ttk.Scrollbar(
            right, orient="horizontal", command=self.editor.xview
        )

        self.editor.configure(
            yscrollcommand=yscroll.set,
            xscrollcommand=xscroll.set
        )

        self.editor.pack(side="left", fill="both", expand=True)
        self.editor.configure(
            selectbackground="#3584e4", selectforeground="white"
        )
        self.enable_text_copy(self.editor)
        yscroll.pack(side="right", fill="y")
        xscroll.pack(fill="x")

        self.editor.bind(
            "<Control-s>", lambda event: self.save_file()
        )

        # Dolní oblast: konzole je přímým potomkem vnějšího
        # Panedwindow, takže zabírá celou šířku okna včetně sidebaru.
        output_pane = ttk.Frame(self.workspace_panes, padding=(5, 3))
        self.workspace_panes.add(output_pane, weight=1)

        ttk.Label(
            output_pane, text="Build / Run output", padding=(2, 3)
        ).pack(anchor="w")

        output_frame = ttk.Frame(output_pane)
        output_frame.pack(fill="both", expand=True)

        self.output = tk.Text(
            output_frame,
            height=8,
            state="disabled",
            wrap="word",
            font=("Monospace", 9)
        )
        output_scroll = ttk.Scrollbar(
            output_frame, orient="vertical", command=self.output.yview
        )
        self.output.configure(yscrollcommand=output_scroll.set)
        self.enable_text_copy(self.output)
        self.output.pack(side="left", fill="both", expand=True)
        output_scroll.pack(side="right", fill="y")
        self.output.configure(
            selectbackground="#3584e4", selectforeground="white"
        )

        # Stavový řádek zůstává pod oběma oblastmi a není součástí
        # posuvného rozdělení.
        self.status = ttk.Label(
            self, text="Ready", anchor="w", padding=5
        )
        self.status.pack(fill="x")

    def log(self, text):
        self.output.configure(state="normal")
        self.output.insert("end", text)
        self.output.see("end")
        self.output.configure(state="disabled")

    def load_project_pythia_config(self):
        """Load this project's saved PYTHIA GUI configuration, if present."""
        self.pythia_config = default_pythia_config()
        if not self.project_dir:
            return

        config_path = self.project_dir / "pythia_config.json"
        if not config_path.is_file():
            return

        try:
            saved = json.loads(config_path.read_text(encoding="utf-8"))
            # Configurations written before schema version 2 used Frame 3 for
            # momentum vectors and Frame 4 for gun positions. An even older
            # version used Frame 2 for separate beam energies.
            try:
                saved_version = int(saved.get("config_version", 1))
            except (TypeError, ValueError):
                saved_version = 1

            defaults = default_pythia_config()
            for key in defaults:
                if key == "config_version":
                    continue
                if key in ("processes", "showers", "beam_momentum_a", "beam_momentum_b",
                           "beam_gun_position_a", "beam_gun_position_b",
                           "vertex_offset", "vertex_sigma", "trajectory_colors"):
                    if isinstance(saved.get(key), dict):
                        defaults[key].update(saved[key])
                elif key in saved:
                    defaults[key] = saved[key]

            if saved_version < 2:
                old_frame = str(saved.get("frame_type", "1"))
                if old_frame == "2":
                    # Legacy Frame 2 used two independent head-on beam energies.
                    # Convert E to |p| approximately (valid for highly relativistic beams).
                    try:
                        energy_a = float(saved.get("beam_energy_a", "7000"))
                        energy_b = float(saved.get("beam_energy_b", "7000"))
                        defaults["beam_momentum_a"] = {
                            "px": "0", "py": "0", "pz": f"{energy_a:.12g}"
                        }
                        defaults["beam_momentum_b"] = {
                            "px": "0", "py": "0", "pz": f"{-energy_b:.12g}"
                        }
                        defaults["frame_type"] = "2"
                    except (TypeError, ValueError):
                        defaults["frame_type"] = "1"
                elif old_frame == "3":
                    # Previous Frame 3 = custom momentum vectors; now Frame 2.
                    defaults["frame_type"] = "2"
                elif old_frame == "4":
                    # Previous Frame 4 = gun positions; now Frame 3.
                    defaults["frame_type"] = "3"

            defaults["config_version"] = 2
            self.pythia_config = defaults
        except (OSError, json.JSONDecodeError, TypeError) as error:
            messagebox.showwarning(
                "Visual project configuration",
                f"Projektový soubor pythia_config.json se nepodařilo načíst.\n"
                f"Použiji výchozí nastavení.\n\n{error}",
                parent=self
            )

    def open_pythia_config(self):
        if not self.project_dir:
            messagebox.showwarning(
                "No project",
                "Nejprve otevři nebo vytvoř projekt.",
                parent=self
            )
            return

        target = self.project_dir / "src" / "main.cc"
        if not target.is_file():
            messagebox.showerror(
                "Missing main.cc",
                f"V projektu jsem nenašel:\n{target}",
                parent=self
            )
            return

        cfg = copy.deepcopy(self.pythia_config)
        window = tk.Toplevel(self)
        window.title("Geant4 Studio — Visual project configuration")
        window.geometry("790x650")
        window.minsize(650, 540)
        window.transient(self)

        header = ttk.Frame(window, padding=(12, 10, 12, 4))
        header.pack(fill="x")
        ttk.Label(
            header,
            text=f"Project: {self.project_dir.name}",
            font=("Sans", 10, "bold")
        ).pack(anchor="w")
        ttk.Label(
            header,
            text="Nastavení se po Save zapíše do src/main.cc a znovu vytvoří generátor PYTHIA.",
            wraplength=740
        ).pack(anchor="w", pady=(3, 0))

        # The tab bar and the Save/Cancel footer remain fixed. Each tab's
        # contents live in its own canvas, so long forms can be scrolled
        # without moving the dialog's action buttons.
        notebook = ttk.Notebook(window)
        notebook.pack(fill="both", expand=True, padx=12, pady=8)
        tab_canvases = {}
        wheel_tag = f"PYTHIAConfigScroll{id(window)}"

        def add_scrollable_tab(title):
            page = ttk.Frame(notebook)
            notebook.add(page, text=title)
            page.grid_rowconfigure(0, weight=1)
            page.grid_columnconfigure(0, weight=1)

            canvas = tk.Canvas(
                page, highlightthickness=0, borderwidth=0,
                yscrollincrement=24
            )
            scrollbar = ttk.Scrollbar(
                page, orient="vertical", command=canvas.yview
            )
            canvas.configure(yscrollcommand=scrollbar.set)
            canvas.grid(row=0, column=0, sticky="nsew")
            scrollbar.grid(row=0, column=1, sticky="ns")

            content = ttk.Frame(canvas, padding=16)
            window_item = canvas.create_window(
                (0, 0), window=content, anchor="nw"
            )
            content.bind(
                "<Configure>",
                lambda _event, c=canvas: c.configure(
                    scrollregion=c.bbox("all")
                )
            )
            canvas.bind(
                "<Configure>",
                lambda event, c=canvas, item=window_item: c.itemconfigure(
                    item, width=event.width
                )
            )
            tab_canvases[str(page)] = canvas
            return page, content

        def scroll_active_tab(event):
            selected_page = notebook.select()
            canvas = tab_canvases.get(selected_page)
            if canvas is None:
                return
            if getattr(event, "num", None) == 4:
                canvas.yview_scroll(-3, "units")
            elif getattr(event, "num", None) == 5:
                canvas.yview_scroll(3, "units")
            else:
                delta = getattr(event, "delta", 0)
                if delta:
                    units = -1 if delta > 0 else 1
                    canvas.yview_scroll(units * max(1, abs(delta) // 120), "units")
            return "break"

        # Use a private bind tag only on widgets inside this dialog's tabs.
        # This enables mouse-wheel scrolling over entries, labels and checkboxes,
        # not just when the pointer happens to be directly over the canvas.
        window.bind_class(wheel_tag, "<MouseWheel>", scroll_active_tab)
        window.bind_class(wheel_tag, "<Button-4>", scroll_active_tab)
        window.bind_class(wheel_tag, "<Button-5>", scroll_active_tab)

        def install_wheel_tag(widget):
            tags = list(widget.bindtags())
            if wheel_tag not in tags:
                tags.insert(0, wheel_tag)
                widget.bindtags(tuple(tags))
            for child in widget.winfo_children():
                install_wheel_tag(child)

        # --- Beams tab -------------------------------------------------
        beams_page, beams_tab = add_scrollable_tab("Beams")

        ttk.Label(
            beams_tab,
            text="Incoming particles and beam kinematics",
            font=("Sans", 11, "bold")
        ).grid(row=0, column=0, columnspan=4, sticky="w", pady=(0, 10))

        beam_a_var = tk.StringVar(value=cfg["beam_id_a"])
        beam_b_var = tk.StringVar(value=cfg["beam_id_b"])
        ecm_var = tk.StringVar(value=cfg["e_cm"])
        frame_type_var = tk.StringVar(value=str(cfg.get("frame_type", "1")))
        beam_b_enabled_var = tk.BooleanVar(
            value=cfg.get("beam_b_enabled", True)
        )

        particle_presets = load_pythia_particle_presets()
        particle_option_labels = list(particle_presets)

        def add_particle_selector(row, label, particle_var):
            ttk.Label(beams_tab, text=label).grid(
                row=row, column=0, sticky="w", padx=(0, 8), pady=5
            )
            ttk.Entry(beams_tab, textvariable=particle_var, width=13).grid(
                row=row, column=1, sticky="w", pady=5
            )

            current_id = str(particle_var.get()).strip()
            preset_label = next(
                (name for name, pdg in particle_presets.items() if pdg == current_id),
                "Search name, PDG ID or quark composition…"
            )
            preset_var = tk.StringVar(value=preset_label)
            preset = ttk.Combobox(
                beams_tab,
                textvariable=preset_var,
                values=particle_option_labels,
                state="normal",
                width=47
            )
            preset.grid(
                row=row, column=2, columnspan=2,
                sticky="ew", padx=(8, 0), pady=5
            )

            def filter_particle_options(_event=None):
                query = preset_var.get().strip().casefold()
                matches = (
                    particle_option_labels if not query else
                    [option for option in particle_option_labels
                     if query in option.casefold()]
                )
                preset.configure(values=matches)

            def choose_particle(_event=None):
                selected = preset_var.get().strip()
                if selected in particle_presets:
                    particle_var.set(particle_presets[selected])
                    return "break"

                # Also accept an integer PDG ID entered directly.
                try:
                    typed_id = int(selected)
                except ValueError:
                    return "break"
                if typed_id != 0:
                    particle_var.set(str(typed_id))
                return "break"

            def on_search_key(event):
                if event.keysym in ("Return", "KP_Enter"):
                    return choose_particle()
                if event.keysym in ("Escape", "Up", "Down", "Left", "Right", "Tab"):
                    return None
                filter_particle_options()
                return None

            preset.bind("<KeyRelease>", on_search_key)
            preset.bind("<<ComboboxSelected>>", choose_particle)
            preset.bind("<FocusIn>", lambda _event: preset.configure(values=particle_option_labels))

        add_particle_selector(1, "Beam A — PDG ID:", beam_a_var)
        add_particle_selector(2, "Beam B — PDG ID:", beam_b_var)
        ttk.Checkbutton(
            beams_tab,
            text="Use Beam B",
            variable=beam_b_enabled_var
        ).grid(row=2, column=4, sticky="w", padx=(8, 0), pady=5)

        ttk.Separator(beams_tab).grid(
            row=3, column=0, columnspan=4, sticky="ew", pady=10
        )
        ttk.Label(beams_tab, text="Kinematics mode:").grid(
            row=4, column=0, sticky="w", pady=5
        )
        frame_choices = {
            "1": "CM energy — head-on beams",
            "2": "Independent 3-momentum vectors",
            "3": "Separate gun positions — aim at interaction point",
        }
        frame_display_var = tk.StringVar(value=frame_choices.get(frame_type_var.get(), frame_choices["1"]))
        frame_combo = ttk.Combobox(
            beams_tab, textvariable=frame_display_var,
            values=list(frame_choices.values()), state="readonly", width=38
        )
        frame_combo.grid(row=4, column=1, columnspan=3, sticky="w", pady=5)

        def sync_frame_type(_event=None):
            reverse = {value: key for key, value in frame_choices.items()}
            frame_type_var.set(reverse.get(frame_display_var.get(), "1"))

        frame_combo.bind("<<ComboboxSelected>>", sync_frame_type)

        ttk.Label(
            beams_tab,
            text=(
                "Frame 1: PYTHIA derives two opposite beam momenta from eCM. "
                "Frame 2: enter px, py, pz independently for both beams. "
                "Frame 3: enter the two source positions; directions are "
                "calculated toward the mean interaction point. Frame 3 takes "
                "each beam's momentum magnitude |p| from the corresponding "
                "Frame 2 vector; only its direction is replaced. Positions "
                "are in mm and momentum components in GeV/c."
            ),
            wraplength=700, justify="left"
        ).grid(row=5, column=0, columnspan=4, sticky="w", pady=(4, 10))

        frame1 = ttk.LabelFrame(beams_tab, text="Frame 1 — centre-of-mass energy", padding=8)
        frame1.grid(row=6, column=0, columnspan=4, sticky="ew", pady=4)
        ttk.Label(frame1, text="eCM (GeV):").pack(side="left")
        ttk.Entry(frame1, textvariable=ecm_var, width=16).pack(side="left", padx=8)

        momentum_a = {axis: tk.StringVar(value=cfg.get("beam_momentum_a", {}).get(axis, "0")) for axis in ("px", "py", "pz")}
        momentum_b = {axis: tk.StringVar(value=cfg.get("beam_momentum_b", {}).get(axis, "0")) for axis in ("px", "py", "pz")}
        frame2 = ttk.LabelFrame(
            beams_tab,
            text="Frame 2 — independent beam momentum vectors (GeV/c)",
            padding=8
        )
        frame2.grid(row=7, column=0, columnspan=4, sticky="ew", pady=4)
        ttk.Label(frame2, text="Component").grid(row=0, column=0, sticky="w", padx=4)
        for col, axis in enumerate(("px", "py", "pz"), 1):
            ttk.Label(frame2, text=axis).grid(row=0, column=col, padx=6)
        ttk.Label(frame2, text="Beam A").grid(row=1, column=0, sticky="w", padx=4, pady=3)
        ttk.Label(frame2, text="Beam B").grid(row=2, column=0, sticky="w", padx=4, pady=3)
        for col, axis in enumerate(("px", "py", "pz"), 1):
            ttk.Entry(frame2, textvariable=momentum_a[axis], width=13).grid(row=1, column=col, padx=5, pady=3)
            ttk.Entry(frame2, textvariable=momentum_b[axis], width=13).grid(row=2, column=col, padx=5, pady=3)

        gun_position_a = {
            axis: tk.StringVar(value=cfg.get("beam_gun_position_a", {}).get(axis, default))
            for axis, default in (("x", "0"), ("y", "0"), ("z", "-1000"))
        }
        gun_position_b = {
            axis: tk.StringVar(value=cfg.get("beam_gun_position_b", {}).get(axis, default))
            for axis, default in (("x", "0"), ("y", "0"), ("z", "1000"))
        }
        frame3 = ttk.LabelFrame(
            beams_tab,
            text="Frame 3 — independent gun positions aimed at the interaction point",
            padding=8
        )
        frame3.grid(row=8, column=0, columnspan=4, sticky="ew", pady=4)
        ttk.Label(frame3, text="Source position (mm)").grid(
            row=0, column=0, sticky="w", padx=4
        )
        for col, axis in enumerate(("x", "y", "z"), 1):
            ttk.Label(frame3, text=axis.upper()).grid(row=0, column=col, padx=5)
        ttk.Label(frame3, text="Gun A").grid(row=1, column=0, sticky="w", padx=4, pady=3)
        ttk.Label(frame3, text="Gun B").grid(row=2, column=0, sticky="w", padx=4, pady=3)
        for col, axis in enumerate(("x", "y", "z"), 1):
            ttk.Entry(frame3, textvariable=gun_position_a[axis], width=12).grid(
                row=1, column=col, padx=4, pady=3
            )
            ttk.Entry(frame3, textvariable=gun_position_b[axis], width=12).grid(
                row=2, column=col, padx=4, pady=3
            )
        ttk.Label(
            frame3,
            text=(
                "Each beam points from its own source position toward the mean "
                "interaction point: (0, 0, 0) by default, or the mean vertex "
                "offset from the Position tab when enabled. The momentum "
                "magnitude |p| is calculated automatically from the matching "
                "Frame 2 vector (px, py, pz); its direction is ignored in Frame 3. "
                "This configures PYTHIA's incoming momenta, not incoming tracks "
                "transported through Geant4. The angle between the beams and "
                "their momentum magnitudes determine the collision energy."
            ),
            wraplength=680, justify="left"
        ).grid(row=3, column=0, columnspan=4, sticky="w", padx=4, pady=(8, 2))

        ttk.Label(
            beams_tab,
            text=(
                "The PDG ID selects the incoming beam particle species. "
                "PYTHIA uses the chosen beam IDs together with the selected "
                "kinematics mode to construct the collision. Frame 3 calculates "
                "each beam direction independently from its source position."
            ),
            wraplength=700, justify="left"
        ).grid(row=9, column=0, columnspan=4, sticky="w", pady=(10, 0))

        family_frame = ttk.LabelFrame(
            beams_tab, text="Particle family quick reference", padding=8
        )
        family_frame.grid(row=10, column=0, columnspan=4, sticky="ew", pady=(10, 4))
        ttk.Label(
            family_frame,
            text=(
                "Baryon octet (quark content): p = uud; n = udd; Λ⁰ = uds; "
                "Σ⁺ = uus; Σ⁰ = uds; Σ⁻ = dds; Ξ⁰ = uss; Ξ⁻ = dss. "
                "The searchable presets also include the corresponding antibaryons."
            ),
            wraplength=690, justify="left"
        ).pack(anchor="w")
        ttk.Label(
            family_frame,
            text=(
                "Leptons are six particles in three generations, not an octet: "
                "(e⁻, νₑ), (μ⁻, νμ), (τ⁻, ντ). The presets also include all six "
                "antileptons. Search by name, symbol or signed PDG ID."
            ),
            wraplength=690, justify="left"
        ).pack(anchor="w", pady=(5, 0))


        # --- Interaction vertex / beam spot tab -----------------------
        vertex_page, vertex_tab = add_scrollable_tab("Position")

        ttk.Label(
            vertex_tab,
            text="Collision point and beam spot",
            font=("Sans", 11, "bold")
        ).pack(anchor="w", pady=(0, 8))
        vertex_enabled_var = tk.BooleanVar(value=cfg.get("vertex_enabled", False))
        ttk.Checkbutton(
            vertex_tab,
            text="Enable interaction-point position / Gaussian beam-spot spread",
            variable=vertex_enabled_var
        ).pack(anchor="w", pady=(0, 8))
        ttk.Label(
            vertex_tab,
            text=(
                "These values configure the COMMON collision vertex in PYTHIA, "
                "not two separate beam start/end points. The offset is the mean "
                "interaction position. Sigma values are Gaussian standard "
                "deviations. PYTHIA's production coordinates are transferred "
                "to the Geant4 primary vertices. All distances are in mm; "
                "the time spread is in mm/c."
            ),
            wraplength=700, justify="left"
        ).pack(anchor="w", pady=(0, 12))

        vertex_offset = {
            axis: tk.StringVar(value=cfg.get("vertex_offset", {}).get(axis, "0"))
            for axis in ("x", "y", "z")
        }
        vertex_sigma = {
            axis: tk.StringVar(value=cfg.get("vertex_sigma", {}).get(axis, "0"))
            for axis in ("x", "y", "z", "time")
        }
        vertex_max_dev_var = tk.StringVar(value=cfg.get("vertex_max_dev", "5"))

        vertex_frame = ttk.LabelFrame(vertex_tab, text="Mean interaction position (mm)", padding=10)
        vertex_frame.pack(fill="x", pady=5)
        for col, axis in enumerate(("x", "y", "z")):
            ttk.Label(vertex_frame, text=axis.upper()).grid(row=0, column=col, padx=8)
            ttk.Entry(vertex_frame, textvariable=vertex_offset[axis], width=15).grid(row=1, column=col, padx=8, pady=4)

        spread_frame = ttk.LabelFrame(vertex_tab, text="Gaussian spread σ", padding=10)
        spread_frame.pack(fill="x", pady=8)
        for col, axis in enumerate(("x", "y", "z", "time")):
            unit = "mm/c" if axis == "time" else "mm"
            ttk.Label(spread_frame, text=f"σ {axis.upper()} ({unit})").grid(row=0, column=col, padx=6)
            ttk.Entry(spread_frame, textvariable=vertex_sigma[axis], width=13).grid(row=1, column=col, padx=6, pady=4)

        ttk.Label(vertex_tab, text="Maximum Gaussian deviation (number of σ):").pack(anchor="w", pady=(8, 2))
        ttk.Entry(vertex_tab, textvariable=vertex_max_dev_var, width=12).pack(anchor="w")
        ttk.Label(
            vertex_tab,
            text="When disabled, PYTHIA places the nominal interaction vertex at (0, 0, 0).",
            wraplength=700
        ).pack(anchor="w", pady=(12, 0))

        # --- Processes tab ---------------------------------------------
        processes_page, processes_tab = add_scrollable_tab("Processes")
        ttk.Label(
            processes_tab,
            text="Enable the hard/soft processes you want PYTHIA to generate.",
            wraplength=700
        ).pack(anchor="w", pady=(0, 10))

        process_vars = {}
        for key, label, description in PROCESS_OPTIONS:
            row = ttk.Frame(processes_tab)
            row.pack(fill="x", anchor="w", pady=5)
            var = tk.BooleanVar(value=cfg["processes"].get(key, False))
            process_vars[key] = var
            ttk.Checkbutton(row, text=label, variable=var).pack(anchor="w")
            ttk.Label(
                row, text=f"{key} — {description}", wraplength=680
            ).pack(anchor="w", padx=(24, 0))

        ttk.Label(
            processes_tab,
            text=(
                "Zapni alespoň jeden proces, který odpovídá zvoleným svazkům. "
                "Pro lepton–hadron DIS můžeš nechat SoftQCD, HardQCD i oba "
                "WeakSingleBoson procesy vypnuté a zapnout pouze "
                "WeakBosonExchange:ff2ff(t:gmZ). Doporučené DIS škálování "
                "a nastavení spršky se přidají automaticky."
            ),
            wraplength=700
        ).pack(anchor="w", pady=(12, 0))

        # --- Showers and hadronization tab -----------------------------
        showers_page, showers_tab = add_scrollable_tab("Showers")
        ttk.Label(
            showers_tab,
            text="Parton-level evolution and hadron-level processing",
            font=("Sans", 11, "bold")
        ).pack(anchor="w", pady=(0, 10))

        shower_vars = {}
        for key, label, description in SHOWER_OPTIONS:
            row = ttk.Frame(showers_tab)
            row.pack(fill="x", anchor="w", pady=5)
            var = tk.BooleanVar(value=cfg["showers"].get(key, True))
            shower_vars[key] = var
            ttk.Checkbutton(row, text=label, variable=var).pack(anchor="w")
            ttk.Label(
                row, text=f"{key} — {description}", wraplength=680
            ).pack(anchor="w", padx=(24, 0))

        # --- Advanced tab ----------------------------------------------

        # --- Trajectory colors tab ------------------------------------------
        trajectory_colors_page, trajectory_colors_tab = add_scrollable_tab(
            "Trajectory colors"
        )

        ttk.Label(
            trajectory_colors_tab,
            text="Barvy trajektorií podle názvu částice",
            font=("Sans", 11, "bold")
        ).pack(anchor="w", pady=(0, 6))

        ttk.Label(
            trajectory_colors_tab,
            text=(
                "Zadej název barvy Geant4 (např. red, cyan, violet) "
                "nebo vlastní RGBA hodnoty (např. 0.2 0.5 1 1). "
                "Prázdná hodnota znamená, že se pro částici nevygeneruje "
                "vlastní pravidlo."
            ),
            wraplength=700
        ).pack(anchor="w", pady=(0, 10))

        colors_frame = ttk.LabelFrame(
            trajectory_colors_tab, text="Particle colors", padding=10
        )
        colors_frame.pack(fill="x", pady=4)

        ttk.Label(colors_frame, text="Geant4 particle name").grid(
            row=0, column=0, sticky="w", padx=5, pady=4
        )
        ttk.Label(colors_frame, text="Color / RGBA").grid(
            row=0, column=1, sticky="w", padx=5, pady=4
        )

        trajectory_color_vars = {}
        trajectory_color_row = [1]

        color_choices = (
            "red", "green", "blue", "cyan", "magenta", "yellow",
            "white", "black", "gray", "grey", "brown", "orange",
            "violet", "purple"
        )

        def add_trajectory_color_row(particle, color):
            row = trajectory_color_row[0]
            trajectory_color_row[0] += 1

            ttk.Label(colors_frame, text=particle).grid(
                row=row, column=0, sticky="w", padx=5, pady=3
            )

            variable = tk.StringVar(value=str(color))
            trajectory_color_vars[particle] = variable

            ttk.Combobox(
                colors_frame,
                textvariable=variable,
                values=color_choices,
                state="normal",
                width=25
            ).grid(row=row, column=1, sticky="w", padx=5, pady=3)

        for particle, color in cfg.get("trajectory_colors", {}).items():
            add_trajectory_color_row(particle, color)

        def add_trajectory_color_particle():
            from tkinter import simpledialog

            particle = simpledialog.askstring(
                "Add particle",
                "Geant4 particle name:",
                parent=window
            )

            if not particle:
                return

            particle = particle.strip()

            if particle in trajectory_color_vars:
                messagebox.showinfo(
                    "Particle already exists",
                    f"Částice {particle} už v seznamu je.",
                    parent=window
                )
                return

            add_trajectory_color_row(particle, "gray")

        ttk.Button(
            trajectory_colors_tab,
            text="Add particle",
            command=add_trajectory_color_particle
        ).pack(anchor="w", pady=8)

        ttk.Label(
            trajectory_colors_tab,
            text=(
                "RGBA: červená, zelená, modrá, alfa. "
                "Každá hodnota musí být v rozsahu 0 až 1."
            ),
            wraplength=700
        ).pack(anchor="w", pady=(4, 0))

        advanced_page, advanced_tab = add_scrollable_tab("Advanced")

        seed_var = tk.BooleanVar(value=cfg["use_seed"])
        seed_value_var = tk.StringVar(value=cfg["seed"])
        seed_row = ttk.Frame(advanced_tab)
        seed_row.pack(fill="x", anchor="w", pady=(0, 10))
        ttk.Checkbutton(
            seed_row,
            text="Use a fixed random seed (reproducible random sequence)",
            variable=seed_var
        ).pack(side="left")
        seed_entry = ttk.Entry(seed_row, textvariable=seed_value_var, width=12)
        seed_entry.pack(side="left", padx=8)

        def update_seed_state(*_args):
            seed_entry.configure(state="normal" if seed_var.get() else "disabled")

        seed_var.trace_add("write", update_seed_state)
        update_seed_state()

        init_settings_var = tk.BooleanVar(value=cfg["show_changed_settings"])
        init_particles_var = tk.BooleanVar(value=cfg["show_changed_particle_data"])
        ttk.Checkbutton(
            advanced_tab,
            text="Print changed PYTHIA settings during initialization",
            variable=init_settings_var
        ).pack(anchor="w", pady=3)
        ttk.Checkbutton(
            advanced_tab,
            text="Print changed particle data during initialization",
            variable=init_particles_var
        ).pack(anchor="w", pady=3)

        diag_frame = ttk.LabelFrame(
            advanced_tab, text="Number of diagnostic records to print", padding=8
        )
        diag_frame.pack(fill="x", pady=10)
        info_var = tk.StringVar(value=str(cfg["show_event_info"]))
        process_info_var = tk.StringVar(value=str(cfg["show_process_info"]))
        event_record_var = tk.StringVar(value=str(cfg["show_event_record"]))
        for row_index, (label, variable) in enumerate([
            ("Event information", info_var),
            ("Process information", process_info_var),
            ("Full event record", event_record_var),
        ]):
            ttk.Label(diag_frame, text=label).grid(
                row=row_index, column=0, sticky="w", padx=5, pady=3
            )
            ttk.Spinbox(
                diag_frame, from_=0, to=100, textvariable=variable, width=8
            ).grid(row=row_index, column=1, sticky="w", padx=8, pady=3)

        ttk.Label(
            advanced_tab,
            text="Custom PYTHIA settings (one setting per line; comments may start with # or !):",
            wraplength=700
        ).pack(anchor="w", pady=(8, 4))
        custom_text = tk.Text(
            advanced_tab, height=7, wrap="none", font=("Monospace", 9), undo=True
        )
        custom_text.pack(fill="both", expand=True)
        custom_text.insert("1.0", cfg["custom_settings"])
        self.enable_text_copy(custom_text)
        ttk.Label(
            advanced_tab,
            text="Custom settings are applied last and can override settings above. PYTHIA validates them when the project runs.",
            wraplength=700
        ).pack(anchor="w", pady=(4, 0))

        footer = ttk.Frame(window, padding=(12, 4, 12, 12))
        footer.pack(fill="x")

        def collect_config():
            return {
                "config_version": 2,
                "beam_id_a": beam_a_var.get().strip(),
                "beam_id_b": beam_b_var.get().strip(),
                "beam_b_enabled": beam_b_enabled_var.get(),
                "frame_type": frame_type_var.get(),
                "e_cm": ecm_var.get().strip(),
                "beam_momentum_a": {axis: var.get().strip() for axis, var in momentum_a.items()},
                "beam_momentum_b": {axis: var.get().strip() for axis, var in momentum_b.items()},
                "beam_gun_position_a": {axis: var.get().strip() for axis, var in gun_position_a.items()},
                "beam_gun_position_b": {axis: var.get().strip() for axis, var in gun_position_b.items()},
                "vertex_enabled": vertex_enabled_var.get(),
                "vertex_offset": {axis: var.get().strip() for axis, var in vertex_offset.items()},
                "vertex_sigma": {axis: var.get().strip() for axis, var in vertex_sigma.items()},
                "vertex_max_dev": vertex_max_dev_var.get().strip(),
                "trajectory_colors": {
                    particle: var.get().strip()
                    for particle, var in trajectory_color_vars.items()
                },
                "processes": {key: var.get() for key, var in process_vars.items()},
                "showers": {key: var.get() for key, var in shower_vars.items()},
                "use_seed": seed_var.get(),
                "seed": seed_value_var.get().strip(),
                "show_changed_settings": init_settings_var.get(),
                "show_changed_particle_data": init_particles_var.get(),
                "show_event_info": info_var.get().strip(),
                "show_process_info": process_info_var.get().strip(),
                "show_event_record": event_record_var.get().strip(),
                "custom_settings": custom_text.get("1.0", "end-1c"),
            }

        def apply_configuration():
            new_config = collect_config()
            try:
                self.validate_pythia_config(new_config)
                self.make_trajectory_color_commands(
                    new_config.get("trajectory_colors", {})
                )
            except ValueError as error:
                messagebox.showerror("Invalid project configuration", str(error), parent=window)
                return

            if not messagebox.askyesno(
                "Regenerate src/main.cc?",
                "Tímto se přegeneruje src/main.cc v aktuálním projektu.\n\n"
                "Kód mimo USER CODE BEGIN / USER CODE END bude nahrazen.\n"
                "Obsah mezi těmito značkami zůstane zachován.\n"
                "Před přepsáním se vytvoří záloha main.cc.bak.\n"
                "Nastavení se uloží také do pythia_config.json.\n\n"
                "Pokračovat?",
                parent=window
            ):
                return

            try:
                backup = self.apply_pythia_config(new_config)
            except (OSError, ValueError, RuntimeError) as error:
                messagebox.showerror("Cannot update main.cc", str(error), parent=window)
                return

            self.pythia_config = copy.deepcopy(new_config)
            self.status.configure(text=f"Project configuration applied: {self.project_dir / 'src' / 'main.cc'}")
            self.log(
                "Konfigurace experimentu zapsána do src/main.cc.\n"
                f"Záloha: {backup}\n"
            )
            messagebox.showinfo(
                "Project configuration saved",
                "Konfigurace byla zapsána do src/main.cc.\n\n"
                "Nyní projekt znovu sestav tlačítkem Build.",
                parent=window
            )
            window.destroy()

        # Add the wheel-scroll tag after all controls have been created.
        for tab_page in (beams_page, vertex_page, processes_page, showers_page, trajectory_colors_page, advanced_page):
            install_wheel_tag(tab_page)

        ttk.Button(
            footer, text="Save",
            command=apply_configuration
        ).pack(side="right", padx=(6, 0))
        ttk.Button(
            footer, text="Cancel", command=window.destroy
        ).pack(side="right")

        window.grab_set()
        window.focus_set()

    @staticmethod
    def validate_pythia_config(config):
        beam_b_enabled = bool(config.get("beam_b_enabled", True))

        def particle_id(field):
            try:
                value = int(config[field])
            except (TypeError, ValueError):
                raise ValueError(f"{field}: zadej celé PDG ID částice.")
            if value == 0:
                raise ValueError(f"{field}: PDG ID 0 není platná částice.")
            return value

        particle_id("beam_id_a")
        if beam_b_enabled:
            particle_id("beam_id_b")

        try:
            frame_type = int(config.get("frame_type", "1"))
        except (TypeError, ValueError):
            raise ValueError("Vyber platný režim kinematiky svazků.")

        if frame_type not in (1, 2, 3):
            raise ValueError("Podporované režimy kinematiky jsou 1, 2 a 3.")

        def finite_number(value, label):
            try:
                number = float(value)
            except (TypeError, ValueError):
                raise ValueError(f"{label} musí být číslo.")
            if not math.isfinite(number):
                raise ValueError(f"{label} musí být konečné číslo.")
            return number

        if not beam_b_enabled:
            # Decay mode: Beam A is a real Geant4 primary particle.
            # eCM and all Beam B / PYTHIA settings are irrelevant.
            momentum = config["beam_momentum_a"]
            components = [
                finite_number(
                    momentum[axis], f"Svazek A — {axis}"
                )
                for axis in ("px", "py", "pz")
            ]

            if sum(value * value for value in components) <= 0:
                raise ValueError(
                    "Hybnost částice Beam A nesmí být nulová."
                )

            position = config["beam_gun_position_a"]
            source = tuple(
                finite_number(
                    position[axis], f"Poloha zdroje A — {axis.upper()}"
                )
                for axis in ("x", "y", "z")
            )

            if frame_type == 3:
                if config.get("vertex_enabled"):
                    target = tuple(
                        finite_number(
                            config["vertex_offset"][axis],
                            f"Offset vrcholu {axis.upper()}"
                        )
                        for axis in ("x", "y", "z")
                    )
                else:
                    target = (0.0, 0.0, 0.0)

                distance_squared = sum(
                    (target[i] - source[i]) ** 2 for i in range(3)
                )
                if distance_squared <= 0:
                    raise ValueError(
                        "Poloha zdroje A nemůže být stejná "
                        "jako interakční bod."
                    )

            return

        # Collision mode: preserve the existing PYTHIA validation.
        if frame_type == 1:
            e_cm = finite_number(config["e_cm"], "Energie eCM")
            if e_cm <= 0:
                raise ValueError("Energie eCM musí být kladná.")

        elif frame_type == 2:
            for beam_name in ("a", "b"):
                components = config[f"beam_momentum_{beam_name}"]
                values = [
                    finite_number(
                        components[axis],
                        f"Svazek {beam_name.upper()} — {axis}"
                    )
                    for axis in ("px", "py", "pz")
                ]
                if sum(value * value for value in values) <= 0:
                    raise ValueError(
                        f"Vektor hybnosti svazku {beam_name.upper()} "
                        "nesmí být nulový."
                    )

        elif frame_type == 3:
            target = (0.0, 0.0, 0.0)
            if config.get("vertex_enabled"):
                target = tuple(
                    finite_number(
                        config["vertex_offset"][axis],
                        f"Offset vrcholu {axis.upper()}"
                    )
                    for axis in ("x", "y", "z")
                )

            for beam_name in ("a", "b"):
                position = config[f"beam_gun_position_{beam_name}"]
                source = tuple(
                    finite_number(
                        position[axis],
                        f"Poloha zdroje {beam_name.upper()} — {axis.upper()}"
                    )
                    for axis in ("x", "y", "z")
                )

                distance_squared = sum(
                    (target[i] - source[i]) ** 2 for i in range(3)
                )
                if distance_squared <= 0:
                    raise ValueError(
                        f"Poloha zdroje {beam_name.upper()} "
                        "nemůže být stejná jako interakční bod."
                    )

                momentum = config[f"beam_momentum_{beam_name}"]
                components = [
                    finite_number(
                        momentum[axis],
                        f"Frame 2 — svazek {beam_name.upper()} — {axis}"
                    )
                    for axis in ("px", "py", "pz")
                ]
                if sum(value * value for value in components) <= 0:
                    raise ValueError(
                        f"Frame 3 potřebuje nenulový vektor hybnosti "
                        f"svazku {beam_name.upper()}."
                    )

        if config.get("vertex_enabled"):
            for axis in ("x", "y", "z"):
                finite_number(
                    config["vertex_offset"][axis],
                    f"Offset vrcholu {axis.upper()}"
                )
            for axis in ("x", "y", "z", "time"):
                sigma = finite_number(
                    config["vertex_sigma"][axis],
                    f"Sigma {axis.upper()}"
                )
                if sigma < 0:
                    raise ValueError(
                        f"Sigma {axis.upper()} nesmí být záporná."
                    )
            max_dev = finite_number(
                config["vertex_max_dev"],
                "Maximální odchylka vrcholu"
            )
            if max_dev <= 0:
                raise ValueError(
                    "Maximální odchylka vrcholu musí být kladná."
                )

        if not any(config["processes"].values()):
            raise ValueError(
                "Zapni alespoň jeden PYTHIA proces, například "
                "DIS — virtual photon/Z exchange."
            )

        if config["use_seed"]:
            try:
                seed = int(config["seed"])
            except (TypeError, ValueError):
                raise ValueError(
                    "Náhodné semínko musí být celé číslo."
                )
            if not 1 <= seed <= 900000000:
                raise ValueError(
                    "Náhodné semínko musí být v rozsahu "
                    "1 až 900 000 000."
                )

        for field in (
            "show_event_info",
            "show_process_info",
            "show_event_record"
        ):
            try:
                count = int(config[field])
            except (TypeError, ValueError):
                raise ValueError(
                    "Počty diagnostických výpisů musí být celá čísla."
                )
            if not 0 <= count <= 100:
                raise ValueError(
                    "Počet diagnostických výpisů musí být "
                    "v rozsahu 0 až 100."
                )

        make_pythia_settings(config)

    @staticmethod
    def make_trajectory_color_commands(colors):
        """Validate particle names and create Geant4 trajectory color commands."""
        if not isinstance(colors, dict):
            raise ValueError("Konfigurace barev musí být slovník.")

        commands = [
            "/vis/modeling/trajectories/create/drawByParticleID"
        ]

        for particle, color in colors.items():
            particle = str(particle).strip()
            color = str(color).strip()

            if not color:
                continue

            if not particle or not all(
                char.isalnum() or char in "_+-" for char in particle
            ):
                raise ValueError(
                    f"Neplatný název Geant4 částice: {particle!r}"
                )

            values = color.replace(",", " ").split()

            if len(values) == 1:
                color_name = values[0]
                if not all(
                    char.isalnum() or char in "_-" for char in color_name
                ):
                    raise ValueError(
                        f"Neplatný název barvy pro {particle}: {color!r}"
                    )

                commands.append(
                    f"/vis/modeling/trajectories/drawByParticleID-0/"
                    f"set {particle} {color_name}"
                )

            elif len(values) == 4:
                try:
                    rgba = [float(value) for value in values]
                except ValueError:
                    raise ValueError(
                        f"RGBA pro {particle} musí obsahovat čtyři čísla."
                    )

                if any(not 0.0 <= value <= 1.0 for value in rgba):
                    raise ValueError(
                        f"RGBA pro {particle} musí být v rozsahu 0 až 1."
                    )

                commands.append(
                    f"/vis/modeling/trajectories/drawByParticleID-0/"
                    f"setRGBA {particle} {' '.join(values)}"
                )

            else:
                raise ValueError(
                    f"Barva pro {particle} musí být název barvy "
                    f"nebo čtyři RGBA hodnoty."
                )

        return commands

    def update_trajectory_vis_macro(self, colors):
        """Update only the managed trajectory-color block in macros/vis.mac."""
        macro = self.project_dir / "macros" / "vis.mac"

        if not macro.is_file():
            raise FileNotFoundError(
                f"Vizualizační makro neexistuje: {macro}"
            )

        text = macro.read_text(encoding="utf-8")

        begin_marker = "# GEANT4STUDIO TRAJECTORY COLORS BEGIN"
        end_marker = "# GEANT4STUDIO TRAJECTORY COLORS END"

        commands = self.make_trajectory_color_commands(colors)

        block = "\n".join([
            begin_marker,
            "# Barvy trajektorií podle názvu částice",
            *commands,
            end_marker
        ])

        begin = text.find(begin_marker)
        end = text.find(end_marker)

        if (begin >= 0) != (end >= 0):
            raise ValueError(
                "V macros/vis.mac je neúplný blok nastavení barev."
            )

        if begin >= 0:
            if end < begin:
                raise ValueError(
                    "Značky bloku barev v macros/vis.mac jsou v chybném pořadí."
                )
            end += len(end_marker)
            updated = text[:begin] + block + text[end:]

        else:
            # Migration path for projects created before this feature.
            legacy_start = text.find("# Barvy trajektorií podle ID")
            legacy_end = text.find(
                "# Zobraz trajektorie ze všech událostí v jednom pohledu",
                legacy_start if legacy_start >= 0 else 0
            )

            if legacy_start >= 0 and legacy_end >= 0:
                updated = (
                    text[:legacy_start]
                    + block + "\n\n"
                    + text[legacy_end:]
                )
            elif legacy_end >= 0:
                updated = text[:legacy_end] + block + "\n\n" + text[legacy_end:]
            else:
                updated = text.rstrip() + "\n\n" + block + "\n"

        temp = macro.with_name("vis.mac.tmp")
        try:
            temp.write_text(updated, encoding="utf-8")
            os.replace(temp, macro)
        finally:
            if temp.exists():
                temp.unlink()

    def apply_pythia_config(self, config):
        if not self.project_dir:
            raise RuntimeError("Není otevřen žádný projekt.")

        target = self.project_dir / "src" / "main.cc"
        if not target.is_file():
            raise FileNotFoundError(f"Soubor neexistuje: {target}")

        original = target.read_text(encoding="utf-8")
        # If main.cc is open in the editor, preserve the latest text there,
        # including any USER CODE edits that have not yet been saved.
        if self.current_file and self.current_file.resolve() == target.resolve():
            original = self.editor.get("1.0", "end-1c")

        begin_marker = "// USER CODE BEGIN"
        end_marker = "// USER CODE END"
        begin_index = original.find(begin_marker)
        end_index = original.find(end_marker, begin_index + len(begin_marker))
        if begin_index < 0 or end_index < 0:
            raise ValueError(
                "V současném src/main.cc chybí značky USER CODE BEGIN / USER CODE END. "
                "Soubor nebyl změněn, aby nedošlo ke ztrátě ručního kódu."
            )

        user_code_start = original.find("\n", begin_index)
        if user_code_start < 0 or user_code_start > end_index:
            raise ValueError("Značka USER CODE BEGIN nemá správný formát.")
        user_code = original[user_code_start + 1:end_index]
        if user_code.startswith("\n"):
            user_code = user_code[1:]
        user_code = user_code.rstrip("\n")

        new_content = generate_main_cc(config, user_code)
        self.update_trajectory_vis_macro(
            config.get("trajectory_colors", {})
        )

        # Keep the first backup intact; make numbered backups on later runs.
        backup = target.with_name("main.cc.bak")
        shutil.copy2(target, backup)

        temp = target.with_name("main.cc.tmp")
        try:
            temp.write_text(new_content, encoding="utf-8")
            os.replace(temp, target)
        finally:
            if temp.exists():
                temp.unlink()

        # Persist the GUI selections per project, so reopening the project
        # restores the same visual configuration instead of resetting defaults.
        config_path = self.project_dir / "pythia_config.json"
        config_temp = config_path.with_name("pythia_config.json.tmp")
        try:
            config_temp.write_text(
                json.dumps(config, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8"
            )
            os.replace(config_temp, config_path)
        finally:
            if config_temp.exists():
                config_temp.unlink()

        if self.current_file and self.current_file.resolve() == target.resolve():
            self.editor.delete("1.0", "end")
            self.editor.insert("1.0", new_content)
            self.editor.edit_reset()
            self.editor_label.configure(text=f"Editor — {target.name}")

        return backup

    def new_project(self):
        from tkinter import simpledialog

        name = simpledialog.askstring(
            "New Project", "Název projektu:", parent=self
        )
        if not name:
            return

        name = name.strip()
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", name):
            messagebox.showerror(
                "Neplatný název",
                "Použij písmena, čísla, pomlčky a podtržítka. "
                "Název musí začínat písmenem."
            )
            return

        parent = filedialog.askdirectory(
            title="Kam uložit projekt?",
            initialdir=str(self.default_project_dir)
        )
        if not parent:
            return

        root = Path(parent) / name
        if root.exists():
            messagebox.showerror("Projekt existuje", f"Složka již existuje:\n{root}")
            return

        template_dir = Path(__file__).resolve().parent / "templates"
        files = {
            "CMakeLists.txt": (template_dir / "CMakeLists.txt").read_text(encoding="utf-8").replace("PROJECT_NAME", name),
            "src/main.cc": generate_main_cc(default_pythia_config()),
            "macros/vis.mac": (template_dir / "vis.mac").read_text(encoding="utf-8"),
            "macros/run.mac": "# Sem vlož příkazy simulace.\n/run/beamOn 10\n",
            "scripts/build.sh": (template_dir / "build.sh").read_text(encoding="utf-8"),
            "scripts/run.sh": (template_dir / "run.sh").read_text(encoding="utf-8").replace("PROJECT_NAME", name),
            "README.md": f"""# {name}

Minimální projekt Geant4 vytvořený v Geant4 Studio.

## Sestavení
`./scripts/build.sh`

## Spuštění s vizualizací
`./scripts/run.sh`

## Spuštění makra
`./scripts/run.sh macros/run.mac`
""",
        }

        try:
            for directory in ("src", "macros", "scripts"):
                (root / directory).mkdir(parents=True, exist_ok=True)
            for relative, content in files.items():
                (root / relative).write_text(content, encoding="utf-8")
            (root / ".gitignore").write_text(
                "build/\ncmake-build-*/\n*.log\n", encoding="utf-8"
            )
            for script in (root / "scripts").glob("*.sh"):
                script.chmod(0o755)
        except OSError as error:
            messagebox.showerror("Chyba vytváření projektu", str(error))
            return

        self.project_dir = root
        self.pythia_config = default_pythia_config()
        self.refresh_tree()
        self.current_file = None
        self.editor.delete("1.0", "end")
        self.editor_label.configure(text="Editor — vyber soubor")
        self.status.configure(text=f"Projekt vytvořen: {root}")
        self.log(f"Projekt vytvořen: {root}\n")

    def open_project(self):
        folder = filedialog.askdirectory(
            title="Choose project folder",
            initialdir=str(self.default_project_dir)
        )
        if not folder:
            return
        self.project_dir = Path(folder)
        self.load_project_pythia_config()
        self.refresh_tree()
        self.current_file = None
        self.editor.delete("1.0", "end")
        self.editor_label.configure(text="Editor — vyber soubor")
        self.status.configure(text=f"Project: {self.project_dir}")

    def refresh_tree(self):
        self.file_tree.delete(*self.file_tree.get_children())
        if not self.project_dir:
            return
        root = self.file_tree.insert(
            "", "end", text=self.project_dir.name,
            values=(str(self.project_dir),), open=True
        )
        self.add_tree_items(root, self.project_dir)

    def add_tree_items(self, parent, folder):
        try:
            items = sorted(
                folder.iterdir(), key=lambda p: (p.is_file(), p.name.lower())
            )
        except OSError:
            return
        for path in items:
            if path.name in {".git", "build", "__pycache__"}:
                continue
            if path.is_dir():
                node = self.file_tree.insert(
                    parent, "end", text=path.name,
                    values=(str(path),), open=False
                )
                self.add_tree_items(node, path)
            elif path.is_file():
                self.file_tree.insert(
                    parent, "end", text=path.name, values=(str(path),)
                )

    def select_file(self, event=None):
        selection = self.file_tree.selection()
        if not selection:
            return
        values = self.file_tree.item(selection[0], "values")
        if not values:
            return
        path = Path(values[0])
        if not path.is_file():
            return
        try:
            content = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            messagebox.showerror("Cannot open file", str(error))
            return
        self.current_file = path
        self.editor.delete("1.0", "end")
        self.editor.insert("1.0", content)
        self.editor.edit_reset()
        self.editor_label.configure(text=f"Editor — {path.name}")
        self.status.configure(text=str(path))

    def save_file(self):
        if not self.current_file:
            messagebox.showinfo("Save", "Nejprve otevři nějaký soubor.")
            return
        try:
            self.current_file.write_text(
                self.editor.get("1.0", "end-1c"), encoding="utf-8"
            )
            self.status.configure(text=f"Saved: {self.current_file}")
        except OSError as error:
            messagebox.showerror("Save failed", str(error))

    def start_command(self, command):
        if not self.project_dir:
            messagebox.showwarning(
                "Žádný projekt", "Nejprve otevři nebo vytvoř projekt."
            )
            return
        if self.process and self.process.poll() is None:
            messagebox.showwarning(
                "Proces běží", "Nejprve zastav aktuální proces."
            )
            return
        if self.current_file:
            self.save_file()

        self.output.configure(state="normal")
        self.output.delete("1.0", "end")
        self.output.configure(state="disabled")
        self.log("$ " + " ".join(command) + "\n\n")
        self.status.configure(text="Probíhá operace...")

        def worker():
            try:
                self.process = subprocess.Popen(
                    command,
                    cwd=str(self.project_dir),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    start_new_session=True
                )
                for line in self.process.stdout:
                    self.after(0, self.log, line)
                code = self.process.wait()
                self.after(
                    0, self.status.configure,
                    {"text": f"Dokončeno (kód {code})"}
                )
                self.after(
                    0, self.log,
                    f"\nProces skončil s návratovým kódem {code}.\n"
                )
            except Exception as error:
                self.after(0, self.log, f"\nChyba: {error}\n")
                self.after(0, self.status.configure, {"text": "Operace selhala"})
            finally:
                self.process = None

        threading.Thread(target=worker, daemon=True).start()

    def build_project(self):
        if not self.project_dir:
            messagebox.showwarning(
                "Žádný projekt", "Nejprve otevři nebo vytvoř projekt."
            )
            return
        script = self.project_dir / "scripts" / "build.sh"
        if not script.exists():
            messagebox.showerror("Chybí skript", f"Nenašel jsem:\n{script}")
            return
        self.start_command(["bash", str(script)])

    def run_project(self):
        if not self.project_dir:
            messagebox.showwarning(
                "Žádný projekt", "Nejprve otevři nebo vytvoř projekt."
            )
            return
        executable = self.project_dir / "build" / self.project_dir.name
        if not executable.exists():
            messagebox.showinfo("Projekt není sestaven", "Nejprve klikni na Build.")
            return
        script = self.project_dir / "scripts" / "run.sh"
        if not script.exists():
            messagebox.showerror("Chybí skript", f"Nenašel jsem:\n{script}")
            return
        self.start_command(["bash", str(script)])

    def stop_process(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            self.log("\nPožadavek na zastavení procesu.\n")
            self.status.configure(text="Zastavuji...")
        else:
            self.status.configure(text="Žádný proces neběží")

    def enable_text_copy(self, widget):
        widget.bind(
            "<Control-c>",
            lambda event: (widget.event_generate("<<Copy>>"), "break")[1]
        )
        widget.bind(
            "<Control-C>",
            lambda event: (widget.event_generate("<<Copy>>"), "break")[1]
        )

    def show_manual(self):
        window = tk.Toplevel(self)
        window.title("Geant4 Studio — User Manual")
        window.geometry("760x600")
        window.minsize(550, 400)

        text_frame = ttk.Frame(window, padding=10)
        text_frame.pack(fill="both", expand=True)
        scrollbar = ttk.Scrollbar(text_frame)
        scrollbar.pack(side="right", fill="y")

        manual = tk.Text(
            text_frame, wrap="word", font=("Sans", 11), padx=12, pady=10,
            selectbackground="#3584e4", selectforeground="white",
            yscrollcommand=scrollbar.set
        )
        manual.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=manual.yview)

        manual_path = (
            Path(__file__).resolve().parent / "templates" / "user_manual.txt"
        )
        try:
            content = manual_path.read_text(encoding="utf-8")
        except OSError as error:
            content = (
                "Could not load the user manual.\n\n"
                f"File: {manual_path}\nError: {error}"
            )
        manual.insert("1.0", content)
        manual.config(state="disabled")
        self.enable_text_copy(manual)


if __name__ == "__main__":
    app = Geant4Studio()
    app.mainloop()

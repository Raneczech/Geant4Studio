Geant4 Studio - sequential frame numbering update

Frame 1: CM energy (eCM)
Frame 2: independent beam 3-momentum vectors (px, py, pz)
Frame 3: independent gun positions aimed toward the mean interaction point;
         momentum magnitudes are taken from the Frame 2 vectors.

Both Frame 2 and Frame 3 map to PYTHIA's native Beams:frameType = 3.
Frame 1 maps to PYTHIA's native Beams:frameType = 1.

The default project folder remains set in __init__:
    self.default_project_dir = Path.home() / "fyzika"

Install by extracting this archive into ~/Geant4Studio, overwriting
geant4_studio.py, then restart Geant4 Studio.

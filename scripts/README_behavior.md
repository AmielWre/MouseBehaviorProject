

# 3-Chamber Behavior — Behavior Scripts

This folder contains the **behavioral analysis pipeline** for 3-chamber social experiments.  
It transforms **raw XY position data** into:

- Frame-level **boolean ROI occupancy**
- **Trial-level epoch statistics**
- **Preference score (PS)** matrices
- **Aggregated per-mouse and per-group visualizations**

---

## 🧠 High-Level Overview

### Main Entry Points

- **`behaviorMain.m`** – The main orchestrator.  
  Iterates over all processed experiments, calls the core analysis, checkpoint-saves results, and produces the final `allPsMatrices.mat`.

- **`psAnalysis.m`** – Post-hoc analysis and visualization script.  
  Loads `allPsMatrices.mat`, aggregates results across sessions/mice, and produces the summary heatmaps.

### Core Components

- **`oneBehaveAnalysis.m`** – The per-experiment engine.  
  For each `(seqTime, boundary)` pair:
  1. Builds a `BehaviorAnalysis` object.
  2. Runs position-based ROI detection and continuity filtering.
  3. Computes epoch statistics (`stStatistics`, `emStatistics`) via `stEmStatData`.
  4. Calculates preference scores.
  5. Saves all outputs (bool matrices, MAT files, CSVs, plots).

- **`BehaviorAnalysis.m`** – Core class for spatial occupancy analysis.  
  Creates four ROI matrices (`stranger`, `empty`, `stranger_out`, `empty_out`), each of shape `2×3×N`:  
  - Row 1 → raw occupancy  
  - Row 2 → continuity-filtered occupancy

- **`stEmStatData.m`** – Computes per-trial statistics for *stranger* and *empty* ROIs using `Statistics.epochsStats`.

### Utility Classes

- **`ExperimentBehave.m`** – Wraps a single experiment’s metadata and XY data.  
  Parses filenames, loads `.mat` files, and stores all fields (group, color, date, ROI struct, etc.).

- **`SaveFolders.m`** – Centralized, safe saving utility for MAT, PNG, FIG, and CSV outputs.

- **`Statistics.m`** – Static helper class for general calculations (epochs, durations, percentages).

---

## 🔄 Function Call Hierarchy

```text
behaviorMain
 └─ oneBehaveAnalysis(exp, seqTimes, boundaries)
      ├─ BehaviorAnalysis(exp, boundary, seq).run()
      │    └─ results: stranger / empty / stranger_out / empty_out (2×3×N)
      ├─ stEmStatData(analysis, exp)
      │    └─ Statistics.epochsStats()
      ├─ SaveFolders.saveCsvResults()
      ├─ SaveFolders.saveFile()
      └─ (accumulate psMatrix, save plots)

psAnalysis
 └─ loads allPsMatrices.mat → aggregates per mouse → plots & averages
```

## ⚙️ Key Parameters

| Parameter | Meaning |
|------------|----------|
| **`seqTimes` (s)** | Minimum dwell time in seconds to count a valid stay (e.g., `0 : 0.5 : 5`). |
| **`boundaries` (cm)** | Expansion of ROI in cm (converted to px via `px2cm`). |
| **Frame rate assumption** | Each trial is 2 min = 120 s → used to convert seconds to frames. |

---

## 🧩 Data Flow and Outputs

### Input Files

Located under `data/processed/<group>/`  
- `XY_behave_<group>_<color>_<date>_<details>_3chamber.mat`  
  (contains `XY_behave`, `stim_trials`)

Located under `data/processed/chamber_rois_positions/`  
- `<group>_<color>_<date>.mat`  
  (contains ROI rectangles + `px2cm` scaling)

---

### Processing Steps

1. For each experiment: (group, color, date)
   - Load `XY_behave` and ROI positions.
   - Construct `ExperimentBehave` object.
   - For each `(seqTime, boundary)`:
     - Run `BehaviorAnalysis.run()`.
     - Save boolean matrices.
     - Compute statistics and PS values.
     - Save plots and MAT/CSV summaries.
2. Accumulate all PS matrices.
3. Save progress incrementally to checkpoint.
4. At the end, save final `allPsMatrices.mat`.

---

## 💾 What Is Saved and Where

| Output Type | Path | Example File |
|--------------|------|---------------|
| **Boolean matrices** | `data/processed/bool_matrices/seq<seq>/b<boundary>/` | `bool_10th_blue_20240512_stranger.mat` |
| **Trial statistics** | `results/3chamber/boundary&sequence/matfiles/<group>_<color>_<date>/` | `seq2.5_b1.0.mat` |
| **CSV rollup** | `results/3chamber/boundary&sequence/csv_data/` | `10th_blue.csv` |
| **Per-experiment plots** | `results/3chamber/boundary&sequence/<group>/<color>/` | `20240512_preference_score.png` |
| **Aggregated checkpoints** | `results/3chamber/boundary&sequence/` | `allPsMatrices_checkpoint.mat` |
| **Final PS matrices** | `results/3chamber/boundary&sequence/` | `allPsMatrices.mat` |
| **Aggregated heatmaps** | `results/3chamber/boundary&sequence/summary_ps/` | `<group>_<color>_all_days.png` |

---

## ▶️ How to Run

### Run all experiments

```matlab
behaviorMain
```
This scans `data/processed/` for all experiments,  
resumes from checkpoints if found, and processes each session.

---

### Run a single experiment (debug mode)

```matlab
cageStruct = load("chamber_rois_positions/10th_blue_20240512.mat");
exp = ExperimentBehave("XY_behave_10th_blue_20240512_st_R_em_L_3chamber.mat", cageStruct);
psMatrix = oneBehaveAnalysis(exp, 0:0.5:5, 0:0.5:5);

```

This command loads allPsMatrices.mat and produces
summary plots per mouse and across all experiments in
results/3chamber/boundary&sequence/summary_ps/.

## Checkpoint System (READ THIS)

### What It Is

Each time the core analysis pipeline (`behaviorMain.m`) is run, it saves progress incrementally in a file located at `results/3chamber/boundary&sequence/allPsMatrices_checkpoint.mat`.

On subsequent runs, the script automatically checks this file and skips experiments that already exist in the stored dataset.

### Why It Matters

* **Prevents data loss** — protects your progress if MATLAB crashes or the script is interrupted.
* **Saves time** — re-runs only process new or previously failed sessions, dramatically reducing computation time.
* **Persistent** — the checkpoint is safe to keep between runs or days.

### How to Use It

**Normal use:**
Simply run `behaviorMain`; it will automatically resume from the last saved checkpoint.

**Force a full re-run (after logic or code changes):**

1.  Delete `results/3chamber/boundary&sequence/allPsMatrices_checkpoint.mat`.
2.  (Optional) Delete the final dataset file: `results/3chamber/boundary&sequence/allPsMatrices.mat`.
3.  Run `behaviorMain` again. All data will be reprocessed from scratch.

**Selective re-run (single mouse or session):**

1.  Delete that mouse entry manually from the `allPsMatrices` variable inside MATLAB's workspace (or after loading the `.mat` file).
2.  Alternatively, comment out the `if isfield(allPsMatrices, validKey) skip check` in `behaviorMain.m`.

### Files Involved

| Type | Filename | Description |
| :--- | :--- | :--- |
| Rolling checkpoint | `allPsMatrices_checkpoint.mat` | Incrementally updated after each experiment completes. |
| Final dataset | `allPsMatrices.mat` | Full collection of preference score matrices after the final run completes. |

---

## Output Data Shapes and Key Variables

| Variable | Shape | Description |
| :--- | :--- | :--- |
| `BehaviorAnalysis.results` | 2×3×N | Four ROI tensors across three trials and $N$ frames; row 1 = raw occupancy, row 2 = **continuity-filtered** occupancy. |
| `stStatistics, emStatistics` | struct array | One element per trial; includes epoch metrics: `count`, `starts`, `ends`, `durations`, `avgDuration`, `totalDuration`. |
| `psMatrix` | (#seq × #boundaries) | Preference score grid for a single experiment across all (sequence time, boundary allowance) combinations. |

---

## Minimal Code Examples

### Get a boolean vector for one trial

```matlab
mat = analysis.getMatrix("stranger_out");  % Returns 2x3xN tensor
vec = squeeze(mat(2, 1, :));               % Extract Trial 1, continuity-applied (Row 2)
Compute statistics for that trial
Matlab

s = Statistics.epochsStats(vec);
disp(s.avgDuration);
Plot a saved boolean matrix
Matlab

load('data/processed/bool_matrices/seq2.5/b0.5/bool_10th_blue_20240512_stranger.mat');
plot(stranger(1, :));
xlabel('Frame'); ylabel('In ROI');
```

---

## Notes and Pitfalls
* **Continuity filter**: Always use row 2 (continuity-applied) for behavioral metrics.
* **NaN handling**: Long NaN runs (> minNanSeq) → -1; short runs → linear interpolation.
* **Checkpoints:** Keep allPsMatrices_checkpoint.mat for recovery; delete it only when recomputing from scratch.
* **Boundary expansion**: Confirm px2cm in ROI files matches your camera setup.
* **Trial assumptions**: Default is 3 trials × 2 min; adjust in BehaviorAnalysis.run() if needed.

---

## Folder Structure

```
year c project/
├── data/
│   └── processed/
│       ├── 8th/
│       │   ├── XY_behave_8th_blue_20231121_st_R_em_L_3chamber.mat
│       │   ├── XY_behave_8th_blue_20231128_em_R_st_L_3chamber.mat
│       │   ├── XY_behave_8th_green_20231203_st_R_em_L_3chamber.mat
│       │   └── ...
│       ├── 10th/
│       ├── 11th/
│       ├── 12th/
│       ├── 13th/
│       ├── bool_matrices/
│       │   └── seq<seq>/b<boundary>/
│       │       ├── bool_<group>_<color>_<date>_stranger.mat
│       │       └── bool_<group>_<color>_<date>_empty.mat
│       ├── chamber_rois_positions/
│       │   ├── 8th_red_20231121.mat
│       │   ├── 10th_blue_20240403.mat
│       │   ├── 10th_blue_20240502.mat
│       │   └── ...
│       └── פרוט עכברים ומשימות חדש.xlsx
│
├── results/
│   └── 3chamber/
│       └── boundary&sequence/
│           ├── 8th/
│           │   ├── blue/
│           │   │   ├── <date>_<seq>second_sequence.png
│           │   │   ├── <date>_preference_score.png
│           │   │   ├── all_days.png / .fig
│           │   │   ├── average.png / .fig
│           │   │   └── ...
│           ├── 10th/
│           ├── 11th/
│           ├── 12th/
│           ├── 13th/
│           ├── csv_data/
│           │   ├── 8th_blue.csv
│           │   ├── 10th_blue.csv
│           │   └── ...
│           ├── matfiles/
│           │   └── seq<seq>_b<boundary>.mat
│           ├── mouse track and cage/
│           ├── summary_ps/
│           │   ├── all_days/<group>_<color>_all_days.(png|fig)
│           │   └── per_mouse/average/<group>_<color>.(png|fig)
│           ├── allPsMatrices_checkpoint_<date>.mat
│           ├── allPsMatrices.mat
│           ├── allPsAverageNormalized.mat
│           └── summary_ps.mat
│
└── scripts/
    └── behavior/
        ├── behaviorMain.m
        ├── oneBehaveAnalysis.m
        ├── BehaviorAnalysis.m
        ├── ExperimentBehave.m
        ├── stEmStatData.m
        ├── SaveFolders.m
        ├── Statistics.m
        └── psAnalysis.m
```

## 🗂️ **Folder Roles Summary**

| Folder | Description |
|--------|--------------|
| `data/processed` | Raw experiment data and ROI definitions. |
| `bool_matrices` | Frame-wise boolean occupancy matrices. |
| `results/3chamber/boundary&sequence` | All outputs (MAT, PNG, CSV), **checkpoints**, and summaries. |
| `scripts/behavior` | Core MATLAB analysis scripts. |


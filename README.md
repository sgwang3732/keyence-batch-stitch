# KEYENCE Batch Stitch

An unofficial Fiji/ImageJ macro for recursively batch-stitching KEYENCE TIFF acquisitions, with automatic channel detection and a reference-channel dialog for each acquisition.

## Features

- Searches a selected folder and all subfolders for BCF files.
- Detects numeric channel labels such as CH1, CH2, CH3, CH4, CH5, and CH10 from TIFF filenames.
- Asks you to choose the reference channel separately for each acquisition, listing only detected channels.
- Preselects CH4 when available; otherwise preselects the first channel in alphabetical filename order (not numeric order).
- Estimates positions using the reference channel, then reuses them for all other detected channels.
- Saves one stitched TIFF per channel beside the corresponding BCF.
- Always overwrites existing stitched outputs.
- Removes temporary copies after successful processing; original files remain unchanged.
- Records progress and skipped acquisitions in a timestamped log.

## Requirements

- Fiji with `Grid/Collection stitching` available.
- Write/delete permission in the acquisition folders.
- Enough disk space for temporary tile copies, staged mosaics, and final outputs.

No Python or KEYENCE Analyzer installation is required by the macro itself.

## Installation and use

1. Download `KEYENCE_Recursive_Batch_Stitch.ijm`.
2. Open Fiji and choose **Plugins > Macros > Run...**.
3. Select the macro file.
4. Select the parent folder containing your acquisitions.
5. For each acquisition, select the reference channel in the dialog and click OK.
6. Wait for processing and inspect the stitched outputs.

Alternatively, open the file in Fiji's Script Editor, select **IJ1 Macro**, and click **Run**.

The batch pauses for reference-channel selection for each acquisition; it is not fully unattended.

## Input filenames

Store each BCF beside its associated TIFF tiles:

```text
parent/
├── sample_A.bcf
├── sample_A_00001_CH2.tif
├── sample_A_00001_CH3.tif
├── sample_A_00001_CH4.tif
├── sample_A_00002_CH2.tif
├── sample_A_00002_CH3.tif
├── sample_A_00002_CH4.tif
└── experiment_B/
    ├── sample_B.bcf
    ├── sample_B_00001_CH1.tif
    ├── sample_B_00001_CH5.tif
    ├── sample_B_00002_CH1.tif
    └── sample_B_00002_CH5.tif
```

Required pattern:

```text
<BCF prefix>_<numeric tile ID>_CH<number>.tif
```

- `.tif` and `.tiff` are accepted, including uppercase extensions.
- Channel tokens are case-insensitive; acquisition prefixes must match exactly.
- Tile IDs are matched as strings: `00001` and `1` are different IDs.
- All detected channels must have identical tile IDs.
- At least two reference-channel tiles are required.
- Overlay TIFFs are ignored.
- Duplicate tile/channel entries are rejected.
- Acquisitions without BCF files are not processed.
- TIFF tiles must be directly beside their BCF, not spread across subfolders.
- A single detected channel is supported if it has at least two tiles.

## Outputs

```text
stitched_sample_A_CH2.tif
stitched_sample_A_CH3.tif
stitched_sample_A_CH4.tif
```

Outputs are saved beside the BCF. The selected parent folder receives `stitch_batch_log_<timestamp>.txt`.

**Existing stitched outputs are overwritten without confirmation. Back up anything you want to keep.**

## How stitching works

The BCF filename identifies the acquisition prefix only. **The macro does not parse BCF contents or read microscope stage coordinates.**

Fiji's Grid/Collection Stitching plugin estimates tile positions from image overlap using the chosen reference channel. Those positions are reused for every other channel without independent registration. Linear blending is used for fusion.

Choose a reference channel with clear, distinctive structures in the overlap regions. Inspect all results before analysis. Weak signal, repeated structures, or insufficient overlap can lead to incorrect placement. Shared positions do not correct chromatic aberration or acquisition drift.

## Temporary files and error handling

Temporary tile copies and staged mosaics are stored in a unique `_stitch_work_...` folder. All channel mosaics are staged and checked for nonzero size before final files are replaced. Copied final outputs are checked against the staged file sizes.

After successful publication of all channels, the temporary folder is deleted. If an error stops processing before cleanup, working files are retained for troubleshooting. Old working folders are excluded from scans but are not automatically deleted.

Missing channel pairs, unequal tile sets, duplicate entries, and insufficient tile counts are logged and skipped. Stitching and output-write errors stop the batch.

Output replacement is not transactional: an interruption during replacement may leave some channels updated and others unchanged. File-size checks do not validate image contents.

## Limitations and validation status

- Channel detection uses filenames, not TIFF metadata.
- The macro does not convert RGB exports into quantitative single-channel grayscale images. A file named CH2 can still contain RGB data.
- Image-only stitching does not guarantee recovery of the acquisition grid.
- Earlier CH2/CH4 versions were successfully run by the developer's user on Windows. This automatic-channel, per-acquisition-reference revision still requires validation on representative data.
- Windows separators are normalized; other operating systems have not been validated in this development session.

## Troubleshooting

### No channels or too few tiles
Check that the BCF prefix matches its TIFF prefixes and that filenames follow the required pattern.

### Missing tiles or unequal tile sets
Each detected channel needs the same tile IDs. Restore missing files or correct filenames.

### Incorrect arrangement
Try a reference channel with better overlap structure. If image-only registration is unreliable, use a known-grid or metadata-based workflow instead.

### Cannot overwrite or delete
Check file permissions, open applications, and cloud-sync locks. Inspect the log and retained working folder before rerunning.

## Acknowledgments

Registration and fusion are performed by Fiji's Grid/Collection Stitching plugin; this project automates that workflow rather than introducing a new stitching algorithm.

- Fiji: https://fiji.sc/
- Stitching documentation: https://imagej.net/plugins/image-stitching
- Preibisch S, Saalfeld S, Tomancak P. Globally optimal stitching of tiled 3D microscopic image acquisitions. Bioinformatics (2009). DOI: 10.1093/bioinformatics/btp184

Developed iteratively with AI assistance and user feedback. This is an unofficial project, not affiliated with or endorsed by KEYENCE. No KEYENCE software or experimental data is included.

## License

MIT License. See `LICENSE`. External dependencies retain their own licenses.

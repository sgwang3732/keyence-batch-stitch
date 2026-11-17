# KEYENCE Batch Stitch

An unofficial Fiji/ImageJ macro for recursively batch-stitching KEYENCE TIFF acquisitions into separate CH2 and CH4 images.

## Features

- Searches a selected folder and its subfolders for `.bcf` files.
- Uses each BCF filename to identify its matching TIFF acquisition.
- Estimates tile positions using a selected reference channel: CH4 (default) or CH2.
- Applies the same tile positions to the other channel without independently re-registering it.
- Saves separate stitched TIFFs beside each BCF file.
- Overwrites existing stitched outputs automatically.
- Removes temporary tile copies and working folders after successful processing.
- Leaves original TIFF and BCF files unchanged.
- Writes a timestamped batch log in the selected parent folder.

## Important limitations and warnings

**This macro does not parse BCF contents or read microscope stage coordinates.** BCF filenames identify acquisition prefixes only. Fiji estimates tile positions from overlapping image content using its “Unknown position” stitching mode.

**Existing `stitched_` output files are overwritten without confirmation.** Back up outputs you want to keep.

Image-only registration can fail or produce incorrect layouts when overlap contains little signal, repetitive patterns, or insufficient shared structure. Inspect stitched images before analysis. Shared coordinates preserve the estimated layout between channels; they do not correct optical chromatic aberration or acquisition drift.

The macro preserves the input image representation through the stitching workflow; it does not explicitly convert RGB exports into quantitative single-channel intensity data. A filename such as `CH2` does not guarantee that the TIFF is stored as a single grayscale channel.

## Requirements

- Fiji with the `Grid/Collection stitching` command available.
- Permission to create, overwrite, and delete files in the acquisition folders.
- Sufficient disk space for temporary copies of both channels, staged outputs, and final outputs.
- Original TIFF tiles with the exact naming structure described below.

No Python installation or KEYENCE Analyzer installation is required by the macro itself.

## Installation

1. Download `KEYENCE_Recursive_Batch_Stitch.ijm` from this repository.
2. Open Fiji.
3. Run the file using `Plugins > Macros > Run...`.

Alternatively, open the file in Fiji's Script Editor, select **IJ1 Macro** as the language, and click **Run**.

## Expected input

Each BCF file and its TIFF tiles must be directly inside the same folder:

```text
parent/
├── sample_A.bcf
├── sample_A_00001_CH2.tif
├── sample_A_00001_CH4.tif
├── sample_A_00001_Overlay.tif
├── sample_A_00002_CH2.tif
├── sample_A_00002_CH4.tif
└── experiment_B/
    ├── sample_B.bcf
    ├── sample_B_00001_CH2.tif
    ├── sample_B_00001_CH4.tif
    ├── sample_B_00002_CH2.tif
    └── sample_B_00002_CH4.tif
```

Matching TIFF filenames must use:

```text
<BCF filename without .bcf>_<numeric tile ID>_CH2.tif
<BCF filename without .bcf>_<numeric tile ID>_CH4.tif
```

- The tile ID must contain digits only.
- TIFF matching currently expects the exact suffixes `_CH2.tif` and `_CH4.tif`.
- Overlay TIFFs are ignored.
- Acquisitions without a BCF file are not processed.
- At least two matching reference-channel tiles are required.
- Every tile must have a matching file in the other channel.
- TIFF tiles are not searched across different folders for an individual BCF.
- Existing folders beginning with `_stitch_work_` are excluded from recursive scanning.

## Usage

1. Run the macro.
2. Select the parent folder containing the acquisitions.
3. Select the reference channel with clear structures in overlapping regions.
4. Wait for batch processing to finish.
5. Inspect the output images and batch log.

Windows path separators are normalized by the macro. The reported successful runs during development used Windows and CH4 as the reference channel; other environments and datasets need validation.

## Outputs

Each acquisition produces:

```text
stitched_<acquisition prefix>_CH2.tif
stitched_<acquisition prefix>_CH4.tif
```

Both files are saved beside the corresponding BCF file. A log named `stitch_batch_log_<timestamp>.txt` is saved in the selected parent folder.

## Processing and cleanup

1. Validate the CH2/CH4 tile pairs.
2. Copy matching tiles into a uniquely named `_stitch_work_...` directory.
3. Estimate and optimize tile positions using the reference channel.
4. Save a temporary reference-channel mosaic.
5. Reuse its registered tile configuration for the other channel.
6. Save a temporary second-channel mosaic.
7. Check that both temporary output files exist and are nonempty.
8. Replace existing final output files and check copied file sizes.
9. Delete the acquisition's temporary directory.

Temporary files are retained if processing stops before cleanup. Old working folders from earlier runs are not automatically deleted.

Output replacement is not transactional: an interruption during replacement may leave only one final channel updated. Staged results remain in the working directory until cleanup. File-existence and size checks are not a substitute for visual inspection or image-integrity validation.

## Troubleshooting

### Fewer than two reference tiles

Check that the BCF prefix exactly matches the TIFF prefix, the suffix is `_CH2.tif` or `_CH4.tif`, and the BCF and TIFF files are in the same folder.

### Missing channel partner

Restore the missing tile or correct its filename. Incomplete acquisitions are logged and skipped.

### Incorrect tile arrangement

Inspect the reference-channel signal and overlap. Try the other reference channel. If image-only alignment remains unreliable, use a metadata-based or known-grid stitching workflow instead.

### Cannot overwrite or remove files

Check write permissions and whether another application is holding the file open. Cloud synchronization may also interfere with file operations. Inspect the retained working folder and log before rerunning.

### Batch stops after a stitching error

The macro stops on stitching or output-publication errors rather than silently continuing with potentially incorrect results. Missing tile pairs are skipped. See the Fiji Log and retained working directory for details.

## Acknowledgments

The image-registration and fusion engine is Fiji's Grid/Collection Stitching plugin. This repository supplies workflow automation rather than a new stitching algorithm.

- Fiji: https://fiji.sc/
- ImageJ stitching documentation: https://imagej.net/plugins/image-stitching
- Preibisch S, Saalfeld S, Tomancak P. Globally optimal stitching of tiled 3D microscopic image acquisitions. Bioinformatics (2009). DOI: 10.1093/bioinformatics/btp184

Developed iteratively with AI assistance and user testing. This is an unofficial project, not affiliated with or endorsed by KEYENCE. No KEYENCE software or microscope data is distributed with this repository.

## License

The macro and repository documentation are provided under the MIT License. External dependencies remain subject to their respective licenses. See `LICENSE`.

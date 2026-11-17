// KEYENCE_Recursive_Batch_Stitch.ijm
// Detect numeric channels; ask for reference per acquisition.
// Recursive scanning, overwrite outputs, cleanup temporary copies.
// BCF filenames identify acquisitions; BCF contents are not parsed.
var acquisitionPaths, stamp, logPath;
root=getDirectory("Select parent folder");
root=replace(root,"\\","/");
stamp=d2s(getTime(),0);
logPath=root+"stitch_batch_log_"+stamp+".txt";
File.saveString("Automatic channels; reference per acquisition; overwrite enabled\n",logPath);
acquisitionPaths="";
scan(root);
if(acquisitionPaths=="") exit("No BCF files found.");
items=split(acquisitionPaths,"\n");
done=0; skipped=0;
for(a=0;a<items.length;a++) {
    acquisitionPath=replace(items[a],"\\","/");
    separator=lastIndexOf(acquisitionPath,"/");
    acquisitionFolder=substring(acquisitionPath,0,separator+1);
    acquisitionBase=substring(acquisitionPath,separator+1,lengthOf(acquisitionPath)-4);
    logMessage("Processing: "+acquisitionPath);
    showStatus("Processing "+(a+1)+"/"+items.length+": "+acquisitionBase);
    success=stitch(acquisitionFolder,acquisitionBase,a);
    if(success) done++; else skipped++;
    showProgress(a+1,items.length);
}
summary="Completed: "+done+"\nSkipped: "+skipped;
logMessage(summary);
showMessage("Finished",summary+"\nLog: "+logPath);

function scan(folder) {
    entries=getFileList(folder);
    Array.sort(entries);
    for(s=0;s<entries.length;s++) {
        entryPath=folder+entries[s];
        if(File.isDirectory(entryPath)) {
            if(!startsWith(entries[s],"_stitch_work_")) scan(entryPath);
        } else if(endsWith(toLowerCase(entries[s]),".bcf"))
            acquisitionPaths=acquisitionPaths+entryPath+"\n";
    }
}
function channelOf(name,base) {
    if(!startsWith(name,base+"_")) return "";
    tail=substring(name,lengthOf(base)+1);
    valid=matches(tail,"[0-9]+_[cC][hH][0-9]+\\.[tT][iI][fF]([fF])?");
    if(!valid) return "";
    underscore=indexOf(tail,"_");
    dot=lastIndexOf(tail,".");
    channelToken=substring(tail,underscore+1,dot);
    channelToken=toUpperCase(channelToken);
    return channelToken;
}
function tileID(name,base) {
    tail=substring(name,lengthOf(base)+1);
    underscore=indexOf(tail,"_");
    identifier=substring(tail,0,underscore);
    return identifier;
}
function findTile(files,base,id,channel) {
    for(f=0;f<files.length;f++) {
        detectedChannel=channelOf(files[f],base);
        if(detectedChannel==channel) {
            detectedID=tileID(files[f],base);
            if(detectedID==id) return files[f];
        }
    }
    return "";
}
function stitch(folder,base,acquisitionIndex) {
    files=getFileList(folder);
    Array.sort(files);
    tokens="|"; channelLines="";
    for(i=0;i<files.length;i++) {
        detectedChannel=channelOf(files[i],base);
        if(detectedChannel!="") {
            tokenPosition=indexOf(tokens,"|"+detectedChannel+"|");
            if(tokenPosition<0) {
                tokens=tokens+detectedChannel+"|";
                channelLines=channelLines+detectedChannel+"\n";
            }
        }
    }
    if(channelLines=="") {
        logMessage("SKIPPED "+folder+base+": no channel TIFFs detected."); return 0;
    }
    channels=split(channelLines,"\n");
    Array.sort(channels);
    defaultReference=channels[0];
    for(c=0;c<channels.length;c++)
        if(channels[c]=="CH4") defaultReference="CH4";
    Dialog.create("Reference channel");
    Dialog.addMessage("Acquisition: "+base+"\nFolder: "+folder);
    Dialog.addChoice("Reference channel:",channels,defaultReference);
    Dialog.show();
    reference=Dialog.getChoice();
    referenceNames=""; tileCount=0;
    for(i=0;i<files.length;i++) {
        detectedChannel=channelOf(files[i],base);
        if(detectedChannel==reference) {
            id=tileID(files[i],base);
            referenceNames=referenceNames+files[i]+"\n";
            tileCount++;
            for(c=0;c<channels.length;c++) {
                matchedTile=findTile(files,base,id,channels[c]);
                if(matchedTile=="") {
                    logMessage("SKIPPED "+folder+base+": missing "+channels[c]+" tile "+id);
                    return 0;
                }
            }
        }
    }
    if(tileCount<2) {
        logMessage("SKIPPED "+folder+base+": fewer than two reference tiles."); return 0;
    }
    for(c=0;c<channels.length;c++) {
        channelCount=0;
        currentChannel=channels[c];
        for(i=0;i<files.length;i++) {
            detectedChannel=channelOf(files[i],base);
            if(detectedChannel==currentChannel) {
                channelCount++;
                id=tileID(files[i],base);
                matchedTile=findTile(files,base,id,reference);
                if(matchedTile=="") {
                    logMessage("SKIPPED "+folder+base+": unequal tile sets."); return 0;
                }
                for(j=i+1;j<files.length;j++) {
                    comparisonChannel=channelOf(files[j],base);
                    if(comparisonChannel==currentChannel) {
                        comparisonID=tileID(files[j],base);
                        if(comparisonID==id) {
                            logMessage("SKIPPED "+folder+base+": duplicate tile/channel files."); return 0;
                        }
                    }
                }
            }
        }
        if(channelCount!=tileCount) {
            logMessage("SKIPPED "+folder+base+": unequal channel tile counts."); return 0;
        }
    }
    referenceFiles=split(referenceNames,"\n");
    workFolder=folder+"_stitch_work_"+stamp+"_"+acquisitionIndex+"/";
    if(File.exists(workFolder)) stopWithLog("Working directory exists: "+workFolder);
    File.makeDirectory(workFolder);
    for(c=0;c<channels.length;c++) {
        currentChannel=channels[c];
        channelFolder=workFolder+currentChannel+"/";
        File.makeDirectory(channelFolder);
        for(t=0;t<referenceFiles.length;t++) {
            id=tileID(referenceFiles[t],base);
            originalName=findTile(files,base,id,currentChannel);
            temporaryPath=channelFolder+"tile_"+id+"_"+currentChannel+".tif";
            File.copy(folder+originalName,temporaryPath);
            if(!File.exists(temporaryPath)) stopWithLog("Copy failed; files retained: "+workFolder);
        }
    }
    logMessage("Channels: "+tokens+"; reference: "+reference+"; tiles: "+tileCount);
    commonOptions=" fusion_method=[Linear Blending] regression_threshold=0.30"+
        " max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50"+
        " subpixel_accuracy computation_parameters=[Save memory (but be slower)]"+
        " image_output=[Fuse and display]";
    referenceFolder=workFolder+reference+"/";
    imagesBefore=nImages;
    run("Grid/Collection stitching","type=[Unknown position] order=[All files in directory]"+
        " directory=["+referenceFolder+"] output_textfile_name=TileConfiguration.txt"+commonOptions);
    registeredPath=referenceFolder+"TileConfiguration.registered.txt";
    if(!File.exists(registeredPath)) stopWithLog("No reference configuration; files retained: "+workFolder);
    if(nImages<=imagesBefore) stopWithLog("No reference mosaic; files retained: "+workFolder);
    saveAs("Tiff",workFolder+"result_"+reference+".tif"); close();
    originalConfiguration=File.openAsString(registeredPath);
    for(c=0;c<channels.length;c++) {
        currentChannel=channels[c];
        if(currentChannel!=reference) {
            channelFolder=workFolder+currentChannel+"/";
            sharedConfiguration=replace(originalConfiguration,"_"+reference+".tif","_"+currentChannel+".tif");
            File.saveString(sharedConfiguration,channelFolder+"TileConfiguration.shared.txt");
            logMessage("Stitching "+currentChannel+" using "+reference+" positions.");
            imagesBefore=nImages;
            // No compute_overlap: reuse positions without re-registering.
            run("Grid/Collection stitching","type=[Positions from file] order=[Defined by TileConfiguration]"+
                " directory=["+channelFolder+"] layout_file=TileConfiguration.shared.txt"+commonOptions);
            if(nImages<=imagesBefore) stopWithLog("No mosaic for "+currentChannel+"; files retained: "+workFolder);
            saveAs("Tiff",workFolder+"result_"+currentChannel+".tif"); close();
        }
    }
    for(c=0;c<channels.length;c++) {
        stagedPath=workFolder+"result_"+channels[c]+".tif";
        if(!File.exists(stagedPath)) stopWithLog("Missing staged output: "+stagedPath);
        if(File.length(stagedPath)<=0) stopWithLog("Empty staged output: "+stagedPath);
    }
    for(c=0;c<channels.length;c++) {
        currentChannel=channels[c];
        stagedPath=workFolder+"result_"+currentChannel+".tif";
        finalPath=folder+"stitched_"+base+"_"+currentChannel+".tif";
        publish(stagedPath,finalPath);
    }
    cleanup(workFolder);
    if(File.exists(workFolder)) logMessage("WARNING: cleanup incomplete: "+workFolder);
    logMessage("DONE "+folder+base);
    return 1;
}
function publish(source,target) {
    if(File.exists(target)) {
        removed=File.delete(target);
        if(File.exists(target)) stopWithLog("Cannot overwrite: "+target+"\nNew result retained: "+source);
    }
    File.copy(source,target);
    if(!File.exists(target)) stopWithLog("Output copy failed; staged result retained: "+source);
    if(File.length(source)!=File.length(target)) stopWithLog("Output size mismatch; staged result retained: "+source);
}
function cleanup(folder) {
    entries=getFileList(folder);
    for(d=0;d<entries.length;d++) {
        entryPath=folder+entries[d];
        if(File.isDirectory(entryPath)) cleanup(entryPath);
        else removed=File.delete(entryPath);
    }
    removed=File.delete(folder);
}
function logMessage(text) {
    print(text);
    File.append(text+"\n",logPath);
}
function stopWithLog(text) {
    logMessage("ERROR: "+text);
    exit(text);
}

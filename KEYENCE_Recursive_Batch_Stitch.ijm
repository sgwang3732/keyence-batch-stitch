// Recursively stitch CH2/CH4; always overwrite stitched outputs.
var paths, reference, other, stamp, logPath;
root=getDirectory("Select parent folder");
root=replace(root,"\\","/");
Dialog.create("KEYENCE batch stitching - OVERWRITE");
Dialog.addChoice("Reference channel:",newArray("CH4","CH2"),"CH4");
Dialog.show();
reference=Dialog.getChoice();
if(reference=="CH4") other="CH2"; else other="CH4";
stamp=d2s(getTime(),0);
logPath=root+"stitch_batch_log_"+stamp+".txt";
File.saveString("Overwrite enabled\n",logPath);
paths="";
scan(root);
if(paths=="") exit("No BCF files found.");
items=split(paths,"\n");
done=0; skipped=0;
for(a=0;a<items.length;a++) {
    p=replace(items[a],"\\","/");
    cut=lastIndexOf(p,"/");
    folder=substring(p,0,cut+1);
    base=substring(p,cut+1,lengthOf(p)-4);
    logMessage("Processing: "+p);
    if(stitch(folder,base,a)) done++; else skipped++;
    showProgress(a+1,items.length);
}
summary="Completed: "+done+"\nSkipped: "+skipped;
logMessage(summary);
showMessage("Finished",summary);

function scan(folder) {
    list=getFileList(folder);
    Array.sort(list);
    for(s=0;s<list.length;s++) {
        p=folder+list[s];
        if(File.isDirectory(p)) {
            if(!startsWith(list[s],"_stitch_work_")) scan(p);
        } else if(endsWith(toLowerCase(list[s]),".bcf")) paths=paths+p+"\n";
    }
}
function tile(name,base,suffix) {
    if(!startsWith(name,base+"_") || !endsWith(name,suffix)) return 0;
    first=lengthOf(base)+1;
    last=lengthOf(name)-lengthOf(suffix);
    if(last<=first) return 0;
    number=substring(name,first,last);
    for(t=0;t<lengthOf(number);t++)
        if(indexOf("0123456789",substring(number,t,t+1))<0) return 0;
    return 1;
}
function stitch(folder,base,index) {
    list=getFileList(folder);
    Array.sort(list);
    rs="_"+reference+".tif";
    os="_"+other+".tif";
    count=0;
    for(i=0;i<list.length;i++) {
        n=list[i];
        if(tile(n,base,rs)) {
            mate=substring(n,0,lengthOf(n)-lengthOf(rs))+os;
            if(!File.exists(folder+mate)) {
                logMessage("SKIPPED: missing "+folder+mate); return 0;
            }
            count++;
        }
        if(tile(n,base,os)) {
            mate=substring(n,0,lengthOf(n)-lengthOf(os))+rs;
            if(!File.exists(folder+mate)) {
                logMessage("SKIPPED: missing "+folder+mate); return 0;
            }
        }
    }
    if(count<2) {
        logMessage("SKIPPED "+base+": fewer than two reference tiles."); return 0;
    }
    work=folder+"_stitch_work_"+stamp+"_"+index+"/";
    rd=work+"tiles_"+reference+"/";
    od=work+"tiles_"+other+"/";
    if(File.exists(work)) exit("Working folder already exists: "+work);
    File.makeDirectory(work); File.makeDirectory(rd); File.makeDirectory(od);
    for(i=0;i<list.length;i++) {
        n=list[i];
        if(tile(n,base,rs)) {
            mate=substring(n,0,lengthOf(n)-lengthOf(rs))+os;
            File.copy(folder+n,rd+n);
            File.copy(folder+mate,od+mate);
            if(!File.exists(rd+n) || !File.exists(od+mate))
                exit("Copy failed; temporary files retained: "+work);
        }
    }
    common=" fusion_method=[Linear Blending] regression_threshold=0.30"+
        " max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50"+
        " subpixel_accuracy computation_parameters=[Save memory (but be slower)]"+
        " image_output=[Fuse and display]";
    before=nImages;
    run("Grid/Collection stitching","type=[Unknown position] order=[All files in directory]"+
        " directory=["+rd+"] output_textfile_name=TileConfiguration.txt"+common);
    registered=rd+"TileConfiguration.registered.txt";
    if(!File.exists(registered) || nImages<=before)
        exit("Reference stitching failed; temporary files retained: "+work);
    // Stage both results before replacing any existing final output.
    stagedRef=work+"result_"+reference+".tif";
    stagedOther=work+"result_"+other+".tif";
    saveAs("Tiff",stagedRef); close();
    config=File.openAsString(registered);
    config=replace(config,rs,os);
    File.saveString(config,od+"TileConfiguration.shared.txt");
    before=nImages;
    run("Grid/Collection stitching","type=[Positions from file] order=[Defined by TileConfiguration]"+
        " directory=["+od+"] layout_file=TileConfiguration.shared.txt"+common);
    if(nImages<=before) exit("Second-channel stitching failed; files retained: "+work);
    saveAs("Tiff",stagedOther); close();
    if(!File.exists(stagedRef) || !File.exists(stagedOther)) exit("Staged output missing: "+work);
    if(File.length(stagedRef)<=0 || File.length(stagedOther)<=0) exit("Staged output empty: "+work);
    finalRef=folder+"stitched_"+base+"_"+reference+".tif";
    finalOther=folder+"stitched_"+base+"_"+other+".tif";
    publish(stagedRef,finalRef);
    publish(stagedOther,finalOther);
    cleanup(work);
    if(File.exists(work)) logMessage("WARNING: cleanup incomplete: "+work);
    logMessage("DONE "+folder+base);
    return 1;
}
function publish(source,target) {
    if(File.exists(target)) {
        removed=File.delete(target);
        if(File.exists(target)) exit("Cannot overwrite: "+target+"\nNew result retained: "+source);
    }
    File.copy(source,target);
    if(!File.exists(target)) exit("Output copy failed. New result retained: "+source);
    if(File.length(source)!=File.length(target)) exit("Output size mismatch. New result retained: "+source);
}
function cleanup(folder) {
    list=getFileList(folder);
    for(d=0;d<list.length;d++) {
        p=folder+list[d];
        if(File.isDirectory(p)) cleanup(p);
        else removed=File.delete(p);
    }
    removed=File.delete(folder);
}
function logMessage(text) {
    print(text);
    File.append(text+"\n",logPath);
}

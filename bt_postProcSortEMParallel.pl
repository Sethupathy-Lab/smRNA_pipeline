#!/usr/bin/perl -w

###############################################################################
#
# 
#
# Usage:
# perl -w bt_postProcSortEMParallel.pl LibBed hitName SPEC
#
#     LibBed  -  output from shrimp_proc.pl maybe
#     hitName -  bed file of bowtie aligned reads
#     SPEC  -  species of study
#
###############################################################################

use Fcntl qw(:flock SEEK_END SEEK_SET);

$GENOME = $ARGV[2];                                        # assess which table to use
if ($GENOME eq 'hsa') {
   open (MIR, "resources/hsa_table.txt") or die;
}
elsif ($GENOME eq 'mmu') {
   open (MIR, "resources/mmu_table.txt") or die;
}
else {
   open (MIR, "resources/rno_table.txt") or die;
}
#open (MIR, "resources/hsa_table.txt");
%mirList=();
%mirStrand=();
while($mir=<MIR>) {                                        # for miR in table
   chomp($mir);
   my ($mName,$mchr,$mSt,$mEd,$mStr,$mSeq,$mHp) = split(/\t/,$mir);
   $ind = index($mHp, $mSeq);                              # get index of mSeq in mHp
   $loc = $mSt + $ind;                                     # adjust location of start
   $loc = $mEd - $ind if ($mStr eq "-");                   # adjust location of start if minus strand
   $mchr = uc($mchr);                                      # make chromosome uppercase
   $mirList{$mchr}{$loc} = $mName;                         # put name in chromosome location dict
   $mirStrand{$mchr}{$loc}= $mStr;                         # put strand infor in chromosome location dict
}
$LibBed=$ARGV[0];                                          # file is named as "NAME_merge.bed";
# Process bowtie hits from bed file
$hitName =$ARGV[1];                                        # file is named as "NAME_allGS.bed";
# $ReadSize=$ARGV[2];
$baseDirName=`dirname $hitName`;                           # set directory name                                                                                                                        
chomp($baseDirName);
$count =0;
open(BT,$hitName) or die "cant open $hitName";             # open hitName argument
$loc = 0;
%hits = ();
%counts = ();
%tags = ();
$count =0;
while($ln=<BT>) {                                          # for line in bowtie hits
   chomp($ln);
   $count++;                                               # add 1 to count
   my ($chrB,$locB,$endB,$readTag1,$gs,$strB) = split(/\t/,$ln);     # split line into variables
   my ($readTag,$seq,$qual) = split (" ",$readTag1);       # separate readTag1 into different variables
   $rs = $endB-$locB;                                      # get the read size
#if ($rs == $ReadSize) {
      if (!exists($tags{$readTag})) {                      # if readTag not in tags
	 $tags{$readTag} = 0 ;                             # set readTag to zero in dict
      }
      $tags{$readTag} +=($gs);                             # add gs to readTag value
#}
}
$numTags = scalar (keys(%tags));                           # get length to tags dict
print "numTags: $numTags\t,$count\n";                      # print length
seek(BT, 0, SEEK_SET);                                     # part of flock, don't know purpose
$count =0;                                                 # reset count to zero
while($ln=<BT>) {                                          # for each line in file 
   chomp($ln);
   my ($chrB1,$locB,$endB,$readTag1,$gs,$strB) = split(/\t/,$ln);    # split and assign variables
   my ($readTag,$seq,$qual) = split (" ",$readTag1);       # split readTag1 into variables
   $rs = $endB-$locB;                                      # get read length
#if ($rs == $ReadSize) {
      $denom = 1;                                          # denom = 1
      $denom = $tags{$readTag} if ($tags{$readTag}>0);     # or denom = value of tags[readTag] if > 0
      $posInfo=join("-",$locB,$endB);                      # join locB and endB
      $chrB = "$chrB1:$strB";                              # join chrB1 and strB
      $count += $gs/$denom;                                # add gs/denom to count
      if (!exists($counts{$chrB}{$posInfo})) {             # if posInfo not in counts dict
	 $hits{$chrB}{$posInfo} = join(":",$chrB1,$locB,$endB,$strB) ;      # split into variables
	 $counts{$chrB}{$posInfo} = $gs/$denom;            # set posInfo value to gs/denom
#print "$gs / $denom = $counts{$chrB}{$posInfo}\n";
      }
      else {                                               # if posInfo in counts dict
#	 print "$counts{$chrB}{$posInfo} += ";
	 $counts{$chrB}{$posInfo}+=$gs/$denom;             # add gs/denom to counts[posInfo]
#print "$chrB: $posInfo: $readTag\t$gs / $denom += $counts{$chrB}{$posInfo}\n";
#print " $gs / $denom += $counts{$chrB}{$posInfo}\n";
      }
#}
}
print "Total Count= $count\n";                             # print total count
close(BT);

$count=0;                                                  # reassign count to zero
$tname =`mktemp`;                                          # make temporary file
chomp($tname);
# $tname = `basename $t1name`;
#chomp($tname);
foreach $chr (keys (%hits)) {                              # for each chromosom in hits dict
   @outArray=();
   open (TMP,">$tname");                                   # open temporary file
   foreach $location (keys (%{$hits{$chr}})) {             # for each location in hits[chromosome]
      my ($chN,$locB,$endB,$strB) = split(/:/,$hits{$chr}{$location});    # split into variables
      print TMP "$chN\t$locB\t$endB\t$location\t1\t$strB\n";
   }
   close(TMP);
   my @readWin= `windowBed -a $tname -b $LibBed -sm -w 0`; # submit to windowBed, window equivalent?
#   $numKeys = scalar(keys(%{$hits{$chr}}));
#   $numWins = scalar(@readWin);
#print "numKeys = $numKeys\t numWins=$numWins\n";
   foreach $info (@readWin) {                              # for each info in windowBed output
	 chomp($info);                                     
#print "INFO: $info\n";
	 my @parts = split(/\t/,$info);                    # split info into list
	 my $location = $parts[3];                         # set location to parts 3
	 my ($chN,$locB,$endB,$strB) = split(/:/,$hits{$chr}{$location});
	 $readSize = $endB-$locB +1;                       # find read size (why plus 1 here)
	 my $Hchr = uc($parts[6]);                         # make Hchr uppercase
	 my $HSt = $parts[7];                              # start coord
	 my $HEd = $parts[8];                              # end coord
	 my $HStr = $parts[11];                            # string
	 my $winName = "$Hchr:$HSt-$HEd($HStr)";           # set window name

	 $mir='NA';
	 my $pos = $locB;                                  # set position
	 $pos = $locB + $readSize if ($strB eq "-");       # set position if minus string
	 my $chN=uc($chN);                                 # uppercase chromo name
	 foreach $p (keys (%{$mirList{$chN}})) {           # for p in mirList[chromosome]
	    if ($mirStrand{$chN}{$p} eq $strB) {           # if mirStrand[chromosome][p] = strB
	       $d = abs($p - $pos);                        # d = absolute value of p - position
	       if ($d<9){                                  # if d < 9
		  $mir = $mirList{$chN}{$p};               # mir = mirList[chromosome][p]
		  last;                                    # break
	       }
	    }
	 }
	 if ($strB eq "-") {                              # if minus string
	    $mystart = $HEd - $locB - $readSize +1;       # start position
	    $myEnd = $mystart+$readSize -1 ;              # end position
#print ">>> $HEd, - $locB - $readSize +1 = $mystart, $myEnd\n";
	 }
	 else {                                           # else if plus string
	    $mystart = $locB - $HSt ;                     # start position
	    $myEnd = $mystart+$readSize -1 ;              # end position
	 }
# $dirName = "test/"; #gResults
	 $countz = $counts{$chr}{$location};              # set countz to chromosome location
	 $count += $countz;                               # add countz to count

	 $outLine=join("\t",$chN,$mystart,$myEnd,$winName,$countz,$strB);   # assemble output line
	 push (@outArray,$outLine);                       # make list of output lines

   } # location
   print "count so far = $count\n";                       # check count so far

   $dirName = $baseDirName . '/g1Results/';               # set output directory name
   `mkdir -p $dirName`;                                   # make output directory g1Results (if not already)
   my($chN,$strand) = split(/:/,$chr);                    # split chromosome name from strand
   $CHR = uc($chN);                                       # make chromosome name uppercase
# $fname = $dirName .  $CHR . "_" . $ReadSize . ".results";
   $fname = $dirName .  $CHR . ".results";                # create output file name
#print " $fname\t $mystart $myEnd  \n";
   open (OUT, ">>$fname") or die "cant open $fname";      # open output file name
#   unless (flock(OUT, LOCK_EX | LOCK_NB)) {
#      $| = 1;
#      print "Waiting for lock...";
#      flock(OUT, LOCK_EX)  or die "can't lock filename: $!";                                                                     
#      print "got it.\n"
#   }
#   seek(OUT, 0, SEEK_END);
   foreach $line (@outArray) {                           # write lines in out array to output file (named above)
      print OUT "$line\n";
   }
   close(OUT);
# $name=$baseDirName . '/g1Results/' . $ReadSize . '.txt';
#`touch $name`;

} #chr
`rm $tname`;                                             # remove temporary file
